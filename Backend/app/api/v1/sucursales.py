"""
Router de Sucursales — solo lógica HTTP.
Toda la lógica de base de datos vive en app/crud/crud_sucursales.py

Seguridad:
  GET    /sucursales/                  → autenticado (filtra por empresa automáticamente)
  GET    /sucursales/empresa/{id}      → autenticado + verify_empresa_access
  GET    /sucursales/{id}              → autenticado + acceso a esa sucursal
  POST   /sucursales/                  → admin_empresa o super_admin
  PATCH  /sucursales/{id}              → admin_empresa (su empresa) o super_admin
  DELETE /sucursales/{id}              → admin_empresa (su empresa) o super_admin  [soft]
  DELETE /sucursales/{id}/hard         → solo super_admin
"""

from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, status
from loguru import logger
from supabase import Client

from ...core.exceptions.http_exceptions import (
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
    verify_sucursal_access,
)
from ...crud.crud_sucursales import (
    create_sucursal,
    get_sucursal,
    get_sucursales,
    hard_delete_sucursal,
    soft_delete_sucursal,
    sucursal_codigo_exists,
    sucursal_exists_by_id,
    update_sucursal,
)
from ...database import get_supabase
from ...schemas.sucursal import (
    SucursalCreate,
    SucursalCreateInternal,
    SucursalRead,
    SucursalUpdate,
    SucursalUpdateInternal,
)

router = APIRouter(prefix="/sucursales", tags=["Sucursales"])


# ─── GET /sucursales/ ─────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[SucursalRead],
    summary="Listar sucursales",
    description="Empleado/admin ven solo las sucursales de su empresa. super_admin ve todas.",
)
def read_sucursales(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 10,
    order_by: str = "created_at",
    order_desc: bool = True,
    estado: str | None = None,
    tipo: str | None = None,
    ciudad: str | None = None,
) -> dict:
    # super_admin no tiene empresa_id — pasa None para listar todas
    empresa_id = None
    if current_user["rol_global"] != "super_admin":
        empresa_id = UUID(str(current_user["empresa_id"]))

    return get_sucursales(
        db=db, empresa_id=empresa_id, page=page,
        items_per_page=items_per_page, order_by=order_by,
        order_desc=order_desc, estado=estado, tipo=tipo, ciudad=ciudad,
    )


# ─── GET /sucursales/empresa/{id} ─────────────────────────────────────────────

@router.get(
    "/empresa/{empresa_id}",
    response_model=PaginatedResponse[SucursalRead],
    summary="Listar sucursales por empresa",
    description="Filtra sucursales de una empresa específica. Requiere acceso a esa empresa.",
)
def read_sucursales_by_empresa(
    empresa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 10,
    estado: str | None = None,
    tipo: str | None = None,
) -> dict:
    verify_empresa_access(current_user, empresa_id)  # 🔒 verifica acceso a esa empresa
    return get_sucursales(
        db=db, empresa_id=empresa_id, page=page,
        items_per_page=items_per_page, estado=estado, tipo=tipo,
    )


# ─── GET /sucursales/{id} ─────────────────────────────────────────────────────

@router.get(
    "/{sucursal_id}",
    response_model=SucursalRead,
    summary="Obtener sucursal",
)
def read_sucursal(
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")

    # Empleado: debe tener asignación activa en esa sucursal
    # Admin/super_admin: basta con pertenecer a la empresa
    if current_user["rol_global"] == "empleado":
        verify_sucursal_access(db, current_user, sucursal_id)  # 🔒 por asignación
    else:
        verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))  # 🔒 por empresa

    return sucursal


# ─── POST /sucursales/ ────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=SucursalRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear sucursal",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)  # 🚦 escritura moderada
def write_sucursal(
    request: Request,
    sucursal: SucursalCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    verify_empresa_access(current_user, sucursal.empresa_id)  # 🔒 solo su empresa

    if sucursal_codigo_exists(db, sucursal.empresa_id, sucursal.codigo):
        raise DuplicateValueException(f"El código '{sucursal.codigo}' ya existe en esta empresa")

    internal = SucursalCreateInternal(
        **sucursal.model_dump(),
        created_by=UUID(str(current_user["id"])),
    )
    nueva = create_sucursal(db, internal)

    logger.info(
        "Sucursal creada | id={id} | nombre={nombre} | empresa={empresa} | por={admin}",
        id=nueva.get("id"),
        nombre=nueva.get("nombre"),
        empresa=str(sucursal.empresa_id),
        admin=current_user.get("email"),
    )
    return nueva


# ─── PATCH /sucursales/{id} ───────────────────────────────────────────────────

@router.patch(
    "/{sucursal_id}",
    response_model=SucursalRead,
    summary="Actualizar sucursal",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)  # 🚦 escritura moderada
def patch_sucursal(
    request: Request,
    sucursal_id: UUID,
    values: SucursalUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")

    verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))  # 🔒 su empresa

    internal = SucursalUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
        updated_by=UUID(str(current_user["id"])),
    )
    updated = update_sucursal(db, sucursal_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar la sucursal")

    logger.info(
        "Sucursal actualizada | id={id} | por={admin}",
        id=str(sucursal_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /sucursales/{id} ── soft delete ───────────────────────────────────

@router.delete(
    "/{sucursal_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar sucursal (soft delete)",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)  # 🚦 operación crítica
def delete_sucursal(
    request: Request,
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")

    verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))  # 🔒 su empresa
    soft_delete_sucursal(db, sucursal_id, UUID(str(current_user["id"])))

    logger.warning(
        "Sucursal desactivada [soft] | id={id} | nombre={nombre} | por={admin}",
        id=str(sucursal_id),
        nombre=sucursal.get("nombre"),
        admin=current_user.get("email"),
    )
    return {
        "message": f"Sucursal '{sucursal['nombre']}' desactivada. "
                   "Las asignaciones de empleados también fueron desactivadas."
    }


# ─── DELETE /sucursales/{id}/hard ── solo super_admin ────────────────────────

@router.delete(
    "/{sucursal_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar sucursal permanentemente",
    description="Borra físicamente el registro y sus asignaciones. **Solo super_admin. Irreversible.**",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)  # 🚦 operación irreversible
def hard_delete_sucursal_endpoint(
    request: Request,
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")

    hard_delete_sucursal(db, sucursal_id)

    logger.warning(
        "Sucursal ELIMINADA [hard] | id={id} | nombre={nombre} | por={admin}",
        id=str(sucursal_id),
        nombre=sucursal.get("nombre"),
        admin=current_user.get("email"),
    )
    return {"message": "Sucursal eliminada permanentemente junto con sus asignaciones"}