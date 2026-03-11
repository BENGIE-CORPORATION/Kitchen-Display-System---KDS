"""
Router de Categorías — solo lógica HTTP.
Toda la lógica de base de datos vive en app/crud/crud_categorias.py

Seguridad:
  GET    /categorias/                  → autenticado (filtra por empresa automáticamente)
  GET    /categorias/{id}              → autenticado + misma empresa
  GET    /categorias/{id}/subcategorias → autenticado + misma empresa
  POST   /categorias/                  → admin_empresa o super_admin
  PATCH  /categorias/{id}              → admin_empresa o super_admin
  DELETE /categorias/{id}              → admin_empresa o super_admin  [soft — desactiva subcategorías]
  DELETE /categorias/{id}/hard         → solo super_admin
"""

from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, status
from loguru import logger
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    ForbiddenException,
    NotFoundException,
)
from ...core.limiter import get_user_id_from_token, limiter
from ...core.pagination import PaginatedResponse
from ...core.security import (
    get_current_admin,
    get_current_superadmin,
    get_current_user,
    verify_empresa_access,
)
from ...crud.crud_categorias import (
    categoria_codigo_exists,
    categoria_exists,
    create_categoria,
    get_categoria,
    get_categorias,
    get_subcategorias,
    hard_delete_categoria,
    soft_delete_categoria,
    soft_delete_subcategorias,
    update_categoria,
)
from ...database import get_supabase
from ...schemas.categoria import (
    CategoriaCreate,
    CategoriaCreateInternal,
    CategoriaRead,
    CategoriaUpdate,
    CategoriaUpdateInternal,
)

router = APIRouter(prefix="/categorias", tags=["Categorías"])


# ─── GET /categorias/ ─────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[CategoriaRead],
    summary="Listar categorías",
    description="Empleado/admin ven solo su empresa. super_admin debe usar el filtro empresa_id.",
)
def read_categorias(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "orden",
    order_desc: bool = False,
    tipo: str | None = None,
    estado: str | None = None,
    categoria_padre_id: UUID | None = None,
    solo_raices: bool = False,
    empresa_id: UUID | None = None,   # solo super_admin puede especificar otra empresa
) -> dict:
    if current_user["rol_global"] == "super_admin":
        if not empresa_id:
            raise BadRequestException("super_admin debe especificar empresa_id como query param")
        target_empresa_id = empresa_id
    else:
        target_empresa_id = UUID(str(current_user["empresa_id"]))

    return get_categorias(
        db=db,
        empresa_id=target_empresa_id,
        page=page,
        items_per_page=items_per_page,
        order_by=order_by,
        order_desc=order_desc,
        tipo=tipo,
        estado=estado,
        categoria_padre_id=categoria_padre_id,
        solo_raices=solo_raices,
    )


# ─── GET /categorias/{id} ─────────────────────────────────────────────────────

@router.get("/{categoria_id}", response_model=CategoriaRead, summary="Obtener categoría")
def read_categoria(
    categoria_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    categoria = get_categoria(db, categoria_id)
    if not categoria:
        raise NotFoundException("Categoría no encontrada")

    verify_empresa_access(current_user, UUID(str(categoria["empresa_id"])))  # 🔒 su empresa
    return categoria


# ─── GET /categorias/{id}/subcategorias ──────────────────────────────────────

@router.get(
    "/{categoria_id}/subcategorias",
    response_model=list[CategoriaRead],
    summary="Listar subcategorías de una categoría",
)
def read_subcategorias(
    categoria_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> list:
    categoria = get_categoria(db, categoria_id)
    if not categoria:
        raise NotFoundException("Categoría no encontrada")

    verify_empresa_access(current_user, UUID(str(categoria["empresa_id"])))  # 🔒 su empresa
    return get_subcategorias(db, categoria_id)


# ─── POST /categorias/ ────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=CategoriaRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear categoría",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)  # 🚦 catalogo puede ser grande
def write_categoria(
    request: Request,
    data: CategoriaCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    verify_empresa_access(current_user, data.empresa_id)  # 🔒 su empresa

    if data.codigo and categoria_codigo_exists(db, data.empresa_id, data.codigo):
        raise DuplicateValueException(f"El código '{data.codigo}' ya existe en esta empresa")

    # Validar que la categoría padre existe y pertenece a la misma empresa
    if data.categoria_padre_id:
        padre = get_categoria(db, data.categoria_padre_id)
        if not padre:
            raise NotFoundException("Categoría padre no encontrada")
        if str(padre["empresa_id"]) != str(data.empresa_id):
            raise BadRequestException("La categoría padre debe pertenecer a la misma empresa")

    internal = CategoriaCreateInternal(
        **data.model_dump(),
        created_by=UUID(str(current_user["id"])),
    )
    nueva = create_categoria(db, internal)

    logger.info(
        "Categoría creada | id={id} | nombre={nombre} | empresa={empresa} | por={admin}",
        id=nueva.get("id"),
        nombre=nueva.get("nombre"),
        empresa=str(data.empresa_id),
        admin=current_user.get("email"),
    )
    return nueva


# ─── PATCH /categorias/{id} ───────────────────────────────────────────────────

@router.patch(
    "/{categoria_id}",
    response_model=CategoriaRead,
    summary="Actualizar categoría",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)  # 🚦
def patch_categoria(
    request: Request,
    categoria_id: UUID,
    values: CategoriaUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    categoria = get_categoria(db, categoria_id)
    if not categoria:
        raise NotFoundException("Categoría no encontrada")

    verify_empresa_access(current_user, UUID(str(categoria["empresa_id"])))  # 🔒 su empresa

    # Verificar unicidad de código si se está cambiando
    if values.codigo and values.codigo.upper() != categoria.get("codigo"):
        empresa_id = UUID(str(categoria["empresa_id"]))
        if categoria_codigo_exists(db, empresa_id, values.codigo, exclude_id=categoria_id):
            raise DuplicateValueException(f"El código '{values.codigo}' ya existe en esta empresa")

    # Validar que la nueva categoría padre no cree un ciclo
    if values.categoria_padre_id:
        if values.categoria_padre_id == categoria_id:
            raise BadRequestException("Una categoría no puede ser su propio padre")
        padre = get_categoria(db, values.categoria_padre_id)
        if not padre:
            raise NotFoundException("Categoría padre no encontrada")
        if str(padre["empresa_id"]) != str(categoria["empresa_id"]):
            raise BadRequestException("La categoría padre debe pertenecer a la misma empresa")

    internal = CategoriaUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
        updated_by=UUID(str(current_user["id"])),
    )
    updated = update_categoria(db, categoria_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar la categoría")

    logger.info(
        "Categoría actualizada | id={id} | por={admin}",
        id=str(categoria_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /categorias/{id} ── soft delete ───────────────────────────────────

@router.delete(
    "/{categoria_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar categoría (soft delete)",
    description="Desactiva la categoría y todas sus subcategorías directas.",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)  # 🚦
def delete_categoria(
    request: Request,
    categoria_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    categoria = get_categoria(db, categoria_id)
    if not categoria:
        raise NotFoundException("Categoría no encontrada")

    verify_empresa_access(current_user, UUID(str(categoria["empresa_id"])))  # 🔒 su empresa

    updated_by = UUID(str(current_user["id"]))
    subcategorias_afectadas = soft_delete_subcategorias(db, categoria_id, updated_by)
    soft_delete_categoria(db, categoria_id, updated_by)

    logger.warning(
        "Categoría desactivada [soft] | id={id} | nombre={nombre} | subcategorias={sub} | por={admin}",
        id=str(categoria_id),
        nombre=categoria.get("nombre"),
        sub=subcategorias_afectadas,
        admin=current_user.get("email"),
    )
    return {
        "message": f"Categoría '{categoria['nombre']}' desactivada.",
        "subcategorias_desactivadas": subcategorias_afectadas,
    }


# ─── DELETE /categorias/{id}/hard ── solo super_admin ────────────────────────

@router.delete(
    "/{categoria_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar categoría permanentemente",
    description="Borra físicamente la categoría. Las subcategorías quedan huérfanas. **Solo super_admin.**",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)  # 🚦
def hard_delete_categoria_endpoint(
    request: Request,
    categoria_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    categoria = get_categoria(db, categoria_id)
    if not categoria:
        raise NotFoundException("Categoría no encontrada")

    subcategorias = get_subcategorias(db, categoria_id)
    hard_delete_categoria(db, categoria_id)

    logger.warning(
        "Categoría ELIMINADA [hard] | id={id} | nombre={nombre} | subcategorias_huerfanas={sub} | por={admin}",
        id=str(categoria_id),
        nombre=categoria.get("nombre"),
        sub=len(subcategorias),
        admin=current_user.get("email"),
    )

    msg = f"Categoría '{categoria['nombre']}' eliminada permanentemente."
    if subcategorias:
        msg += f" {len(subcategorias)} subcategoría(s) quedaron huérfanas — revisar manualmente."

    return {"message": msg, "subcategorias_huerfanas": len(subcategorias)}