"""
Router de Empresas — solo lógica HTTP.
Toda la lógica de base de datos vive en app/crud/crud_empresa.py

Seguridad:
  GET    /empresas/        → autenticado (empleado/admin ven solo su empresa, super_admin ve todas)
  GET    /empresas/{id}    → autenticado + pertenece a esa empresa
  POST   /empresas/        → solo super_admin
  PATCH  /empresas/{id}    → admin_empresa (su empresa) o super_admin
  DELETE /empresas/{id}    → admin_empresa (su empresa) o super_admin  [soft]
  DELETE /empresas/{id}/hard → solo super_admin
"""

from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, status
from loguru import logger
from supabase import Client

from ...core.exceptions.http_exceptions import DuplicateValueException, NotFoundException
from ...core.limiter import get_user_id_from_token, limiter
from ...core.pagination import PaginatedResponse
from ...core.security import (
    get_current_admin,
    get_current_superadmin,
    get_current_user,
    verify_empresa_access,
)
from ...crud.crud_empresa import (
    create_empresa,
    empresa_exists,
    get_empresa,
    get_empresas,
    hard_delete_empresa,
    soft_delete_empresa,
    update_empresa,
)
from ...database import get_supabase
from ...schemas.empresa import (
    EmpresaCreate,
    EmpresaCreateInternal,
    EmpresaRead,
    EmpresaUpdate,
    EmpresaUpdateInternal,
)

router = APIRouter(prefix="/empresas", tags=["Empresas"])


# ─── POST /empresas ── solo super_admin ───────────────────────────────────────

@router.post(
    "/",
    response_model=EmpresaRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear empresa",
    description="Registra una nueva empresa en el sistema. **Solo super_admin.**",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)  # 🚦 creación de empresas es poco frecuente
def write_empresa(
    request: Request,
    empresa: EmpresaCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    if empresa_exists(db, identificacion=empresa.identificacion):
        raise DuplicateValueException("La identificación fiscal ya está registrada")
    if empresa_exists(db, email=empresa.email):
        raise DuplicateValueException("El email ya está registrado")

    internal = EmpresaCreateInternal(**empresa.model_dump())
    nueva = create_empresa(db, internal)

    logger.info(
        "Empresa creada | id={id} | nombre={nombre} | por={admin}",
        id=nueva.get("id"),
        nombre=nueva.get("nombre_comercial"),
        admin=current_user.get("email"),
    )
    return nueva


# ─── GET /empresas ── cualquier usuario autenticado ───────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[EmpresaRead],
    summary="Listar empresas",
    description="Lista paginada de empresas. Empleado/admin ven solo su empresa; super_admin ve todas.",
)
def read_empresas(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 10,
    order_by: str = "created_at",
    order_desc: bool = True,
    estado: str | None = None,
    tipo_negocio: str | None = None,
    pais: str | None = None,
) -> dict:
    # Empleados y admins solo ven SU empresa — super_admin ve todas
    empresa_id_filtro = None
    if current_user.get("rol_global") != "super_admin":
        empresa_id_filtro = current_user.get("empresa_id")

    return get_empresas(
        db=db,
        page=page,
        items_per_page=items_per_page,
        order_by=order_by,
        order_desc=order_desc,
        estado=estado,
        tipo_negocio=tipo_negocio,
        pais=pais,
        empresa_id=empresa_id_filtro,
    )


# ─── GET /empresas/{id} ── autenticado + acceso a esa empresa ─────────────────

@router.get(
    "/{empresa_id}",
    response_model=EmpresaRead,
    summary="Obtener empresa",
    description="Retorna el detalle de una empresa. Solo puedes ver tu propia empresa.",
)
def read_empresa(
    empresa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    empresa = get_empresa(db, empresa_id)
    if not empresa:
        raise NotFoundException("Empresa no encontrada")

    verify_empresa_access(current_user, empresa_id)  # 🔒 verifica que sea su empresa
    return empresa


# ─── PATCH /empresas/{id} ── admin de esa empresa o super_admin ───────────────

@router.patch(
    "/{empresa_id}",
    response_model=EmpresaRead,
    summary="Actualizar empresa",
    description="Actualiza parcialmente una empresa. Requiere ser admin de esa empresa.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)  # 🚦 escrituras moderadas
def patch_empresa(
    request: Request,
    empresa_id: UUID,
    values: EmpresaUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    empresa = get_empresa(db, empresa_id)
    if not empresa:
        raise NotFoundException("Empresa no encontrada")

    verify_empresa_access(current_user, empresa_id)  # 🔒 verifica que sea su empresa

    if values.email and values.email != empresa.get("email"):
        if empresa_exists(db, email=str(values.email)):
            raise DuplicateValueException("El email ya está registrado en otra empresa")

    internal = EmpresaUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
    )
    updated = update_empresa(db, empresa_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar la empresa")

    logger.info(
        "Empresa actualizada | id={id} | por={admin}",
        id=str(empresa_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /empresas/{id} ── soft delete ─────────────────────────────────────

@router.delete(
    "/{empresa_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar empresa (soft delete)",
    description="Marca la empresa como inactiva. Requiere ser admin de esa empresa.",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)  # 🚦 operación crítica
def delete_empresa(
    request: Request,
    empresa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    empresa = get_empresa(db, empresa_id)
    if not empresa:
        raise NotFoundException("Empresa no encontrada")

    verify_empresa_access(current_user, empresa_id)  # 🔒 verifica que sea su empresa
    soft_delete_empresa(db, empresa_id)

    logger.warning(
        "Empresa desactivada [soft] | id={id} | nombre={nombre} | por={admin}",
        id=str(empresa_id),
        nombre=empresa.get("nombre_comercial"),
        admin=current_user.get("email"),
    )
    return {"message": f"Empresa '{empresa['nombre_comercial']}' desactivada correctamente"}


# ─── DELETE /empresas/{id}/hard ── solo super_admin ──────────────────────────

@router.delete(
    "/{empresa_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar empresa permanentemente",
    description="Borra físicamente el registro. **Solo super_admin. Irreversible.**",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)  # 🚦 operación irreversible — límite estricto
def hard_delete_empresa_endpoint(
    request: Request,
    empresa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    empresa = get_empresa(db, empresa_id)
    if not empresa:
        raise NotFoundException("Empresa no encontrada")

    hard_delete_empresa(db, empresa_id)

    logger.warning(
        "Empresa ELIMINADA [hard] | id={id} | nombre={nombre} | por={admin}",
        id=str(empresa_id),
        nombre=empresa.get("nombre_comercial"),
        admin=current_user.get("email"),
    )
    return {"message": "Empresa eliminada permanentemente"}