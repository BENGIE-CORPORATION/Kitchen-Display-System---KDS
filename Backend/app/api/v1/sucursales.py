"""
Router de Sucursales.

Seguridad por endpoint:
  GET    /sucursales/              → autenticado (filtra por empresa automáticamente)
  GET    /sucursales/{id}          → autenticado + acceso a esa sucursal
  POST   /sucursales/              → admin_empresa o super_admin
  PATCH  /sucursales/{id}          → admin_empresa (su empresa) o super_admin
  DELETE /sucursales/{id}          → admin_empresa (su empresa) o super_admin
  DELETE /sucursales/{id}/hard     → solo super_admin
"""

from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    ForbiddenException,
    NotFoundException,
)
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


@router.get(
    "/",
    response_model=PaginatedResponse[SucursalRead],
    summary="Listar sucursales de la empresa",
)
def read_sucursales(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 10,
    order_by: str = "created_at",
    order_desc: bool = True,
    estado: str | None = None,
    tipo: str | None = None,
    ciudad: str | None = None,
) -> dict:
    # Determinar qué empresa listar
    if current_user["rol_global"] == "super_admin":
        raise BadRequestException(
            "super_admin debe filtrar por empresa. Usa /empresas/{id}/sucursales"
        )
    empresa_id = UUID(str(current_user["empresa_id"]))
    return get_sucursales(
        db=db, empresa_id=empresa_id, page=page,
        items_per_page=items_per_page, order_by=order_by,
        order_desc=order_desc, estado=estado, tipo=tipo, ciudad=ciudad,
    )


@router.get(
    "/empresa/{empresa_id}",
    response_model=PaginatedResponse[SucursalRead],
    summary="Listar sucursales por empresa (super_admin)",
)
def read_sucursales_by_empresa(
    empresa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 10,
    estado: str | None = None,
    tipo: str | None = None,
) -> dict:
    verify_empresa_access(current_user, empresa_id)
    return get_sucursales(
        db=db, empresa_id=empresa_id, page=page,
        items_per_page=items_per_page, estado=estado, tipo=tipo,
    )


@router.get("/{sucursal_id}", response_model=SucursalRead, summary="Obtener sucursal")
def read_sucursal(
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")
    # Verificar acceso: admin por empresa, empleado por asignación
    if current_user["rol_global"] == "empleado":
        verify_sucursal_access(db, current_user, sucursal_id)
    else:
        verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))
    return sucursal


@router.post(
    "/",
    response_model=SucursalRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear sucursal",
)
def write_sucursal(
    sucursal: SucursalCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    verify_empresa_access(current_user, sucursal.empresa_id)

    if sucursal_codigo_exists(db, sucursal.empresa_id, sucursal.codigo):
        raise DuplicateValueException(
            f"El código '{sucursal.codigo}' ya existe en esta empresa"
        )

    internal = SucursalCreateInternal(
        **sucursal.model_dump(),
        created_by=UUID(str(current_user["id"])),
    )
    return create_sucursal(db, internal)


@router.patch("/{sucursal_id}", response_model=SucursalRead, summary="Actualizar sucursal")
def patch_sucursal(
    sucursal_id: UUID,
    values: SucursalUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")
    verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))

    internal = SucursalUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
        updated_by=UUID(str(current_user["id"])),
    )
    updated = update_sucursal(db, sucursal_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar la sucursal")
    return updated


@router.delete("/{sucursal_id}", status_code=status.HTTP_200_OK, summary="Desactivar sucursal")
def delete_sucursal(
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")
    verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))

    soft_delete_sucursal(db, sucursal_id, UUID(str(current_user["id"])))
    return {
        "message": f"Sucursal '{sucursal['nombre']}' desactivada. "
                   "Las asignaciones de empleados también fueron desactivadas."
    }


@router.delete(
    "/{sucursal_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar sucursal permanentemente (super_admin)",
)
def hard_delete_sucursal_endpoint(
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],
) -> dict:
    if not sucursal_exists_by_id(db, sucursal_id):
        raise NotFoundException("Sucursal no encontrada")
    hard_delete_sucursal(db, sucursal_id)
    return {"message": "Sucursal eliminada permanentemente junto con sus asignaciones"}
