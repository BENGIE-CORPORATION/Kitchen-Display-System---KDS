"""
Router de Proveedores — solo lógica HTTP.

Seguridad:
  GET    /proveedores/        → admin_empresa o super_admin
  GET    /proveedores/{id}    → admin_empresa o super_admin
  POST   /proveedores/        → admin_empresa o super_admin
  PATCH  /proveedores/{id}    → admin_empresa o super_admin
  DELETE /proveedores/{id}    → admin_empresa o super_admin  [soft]
  DELETE /proveedores/{id}/hard → solo super_admin
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
from ...crud.crud_proveedores import (
    create_proveedor,
    get_proveedor,
    get_proveedores,
    hard_delete_proveedor,
    proveedor_codigo_exists,
    proveedor_identificacion_exists,
    soft_delete_proveedor,
    update_proveedor,
)
from ...database import get_supabase
from ...schemas.proveedor import (
    ProveedorCreate,
    ProveedorCreateInternal,
    ProveedorRead,
    ProveedorUpdate,
    ProveedorUpdateInternal,
)

router = APIRouter(prefix="/proveedores", tags=["Proveedores"])


# ─── GET /proveedores/ ────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[ProveedorRead],
    summary="Listar proveedores",
    description="admin_empresa ve solo su empresa. super_admin debe especificar empresa_id.",
)
def read_proveedores(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "created_at",
    order_desc: bool = True,
    tipo_proveedor: str | None = None,
    condicion_pago: str | None = None,
    estado: str | None = None,
    search: str | None = None,
    empresa_id: UUID | None = None,
) -> dict:
    if current_user["rol_global"] == "super_admin":
        if not empresa_id:
            raise BadRequestException("super_admin debe especificar empresa_id como query param")
        target = empresa_id
    else:
        target = UUID(str(current_user["empresa_id"]))

    return get_proveedores(
        db=db, empresa_id=target, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc, tipo_proveedor=tipo_proveedor,
        condicion_pago=condicion_pago, estado=estado, search=search,
    )


# ─── GET /proveedores/{id} ────────────────────────────────────────────────────

@router.get("/{proveedor_id}", response_model=ProveedorRead, summary="Obtener proveedor")
def read_proveedor(
    proveedor_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    proveedor = get_proveedor(db, proveedor_id)
    if not proveedor:
        raise NotFoundException("Proveedor no encontrado")
    verify_empresa_access(current_user, UUID(str(proveedor["empresa_id"])))
    return proveedor


# ─── POST /proveedores/ ───────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=ProveedorRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear proveedor",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def write_proveedor(
    request: Request,
    data: ProveedorCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    verify_empresa_access(current_user, data.empresa_id)

    if proveedor_identificacion_exists(db, data.empresa_id, data.identificacion):
        raise DuplicateValueException(
            f"La identificación '{data.identificacion}' ya está registrada en esta empresa"
        )
    if data.codigo and proveedor_codigo_exists(db, data.empresa_id, data.codigo):
        raise DuplicateValueException(
            f"El código '{data.codigo}' ya está registrado en esta empresa"
        )

    internal = ProveedorCreateInternal(
        **data.model_dump(),
        created_by=UUID(str(current_user["id"])),
    )
    nuevo = create_proveedor(db, internal)

    logger.info(
        "Proveedor creado | id={id} | nombre={nombre} | empresa={empresa} | por={admin}",
        id=nuevo.get("id"),
        nombre=nuevo.get("nombre_legal"),
        empresa=str(data.empresa_id),
        admin=current_user.get("email"),
    )
    return nuevo


# ─── PATCH /proveedores/{id} ──────────────────────────────────────────────────

@router.patch("/{proveedor_id}", response_model=ProveedorRead, summary="Actualizar proveedor")
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def patch_proveedor(
    request: Request,
    proveedor_id: UUID,
    values: ProveedorUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    proveedor = get_proveedor(db, proveedor_id)
    if not proveedor:
        raise NotFoundException("Proveedor no encontrado")
    verify_empresa_access(current_user, UUID(str(proveedor["empresa_id"])))

    empresa_id = UUID(str(proveedor["empresa_id"]))

    if values.codigo and values.codigo.upper() != proveedor.get("codigo"):
        if proveedor_codigo_exists(db, empresa_id, values.codigo, exclude_id=proveedor_id):
            raise DuplicateValueException(f"El código '{values.codigo}' ya existe en esta empresa")

    internal = ProveedorUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
        updated_by=UUID(str(current_user["id"])),
    )
    updated = update_proveedor(db, proveedor_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar el proveedor")

    logger.info(
        "Proveedor actualizado | id={id} | por={admin}",
        id=str(proveedor_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /proveedores/{id} ── soft delete ──────────────────────────────────

@router.delete(
    "/{proveedor_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar proveedor (soft delete)",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def delete_proveedor(
    request: Request,
    proveedor_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    proveedor = get_proveedor(db, proveedor_id)
    if not proveedor:
        raise NotFoundException("Proveedor no encontrado")
    verify_empresa_access(current_user, UUID(str(proveedor["empresa_id"])))

    soft_delete_proveedor(db, proveedor_id, UUID(str(current_user["id"])))

    logger.warning(
        "Proveedor desactivado [soft] | id={id} | nombre={nombre} | por={admin}",
        id=str(proveedor_id),
        nombre=proveedor.get("nombre_legal"),
        admin=current_user.get("email"),
    )
    return {"message": f"Proveedor '{proveedor['nombre_legal']}' desactivado correctamente"}


# ─── DELETE /proveedores/{id}/hard ────────────────────────────────────────────

@router.delete(
    "/{proveedor_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar proveedor permanentemente",
    description="**Solo super_admin. Irreversible.** Fallará si tiene órdenes de compra asociadas.",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_proveedor_endpoint(
    request: Request,
    proveedor_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    proveedor = get_proveedor(db, proveedor_id)
    if not proveedor:
        raise NotFoundException("Proveedor no encontrado")

    hard_delete_proveedor(db, proveedor_id)

    logger.warning(
        "Proveedor ELIMINADO [hard] | id={id} | nombre={nombre} | por={admin}",
        id=str(proveedor_id),
        nombre=proveedor.get("nombre_legal"),
        admin=current_user.get("email"),
    )
    return {"message": f"Proveedor '{proveedor['nombre_legal']}' eliminado permanentemente"}