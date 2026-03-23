"""
Router de Usuarios × Sucursales.

Seguridad por endpoint:
  GET  /usuarios-sucursales/sucursal/{id}    → admin_empresa o super_admin
  GET  /usuarios-sucursales/usuario/{id}     → el propio usuario, admin o super_admin
  POST /usuarios-sucursales/                 → admin_empresa o super_admin
  PATCH /usuarios-sucursales/{id}            → admin_empresa o super_admin
  DELETE /usuarios-sucursales/{id}           → admin_empresa o super_admin
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
    get_current_user,
    verify_empresa_access,
)
from ...crud.crud_usuarios_sucursales import (
    asignacion_activa_exists,
    create_asignacion,
    desactivar_asignacion,
    get_asignacion,
    get_asignacion_by_usuario_sucursal,
    get_sucursales_de_usuario,
    get_usuarios_de_sucursal,
    hard_delete_asignacion,
    update_asignacion,
)
from ...crud.crud_perfiles_usuario import get_perfil_by_id
from ...crud.crud_sucursales import get_sucursal
from ...database import get_supabase
from ...schemas.usuario_sucursal import (
    UsuarioSucursalCreate,
    UsuarioSucursalCreateInternal,
    UsuarioSucursalRead,
    UsuarioSucursalUpdate,
    UsuarioSucursalUpdateInternal,
)

router = APIRouter(prefix="/usuarios-sucursales", tags=["Usuarios × Sucursales"])


# ─── GET usuarios de una sucursal ────────────────────────────────────────────

@router.get(
    "/sucursal/{sucursal_id}",
    response_model=PaginatedResponse[UsuarioSucursalRead],
    summary="Listar usuarios de una sucursal",
)
def read_usuarios_de_sucursal(
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    estado: str | None = "activo",
    rol_sucursal: str | None = None,
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")
    verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))

    return get_usuarios_de_sucursal(
        db=db, sucursal_id=sucursal_id, page=page,
        items_per_page=items_per_page, estado=estado, rol_sucursal=rol_sucursal,
    )


# ─── GET sucursales de un usuario ────────────────────────────────────────────

@router.get(
    "/usuario/{usuario_id}",
    response_model=list[UsuarioSucursalRead],
    summary="Listar sucursales de un usuario",
)
def read_sucursales_de_usuario(
    usuario_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],
) -> list:
    # El propio usuario puede ver sus sucursales, admin y super_admin también
    if (
        current_user["rol_global"] == "empleado"
        and str(current_user["id"]) != str(usuario_id)
    ):
        raise ForbiddenException("Solo puedes ver tus propias asignaciones")

    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Usuario no encontrado")

    if current_user["rol_global"] != "empleado":
        verify_empresa_access(current_user, UUID(str(perfil["empresa_id"])))

    return get_sucursales_de_usuario(db, usuario_id)


# ─── POST crear asignación ───────────────────────────────────────────────────

@router.post(
    "/",
    response_model=UsuarioSucursalRead,
    status_code=status.HTTP_201_CREATED,
    summary="Asignar usuario a sucursal",
)
def create_usuario_sucursal(
    data: UsuarioSucursalCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    # Verificar que el usuario existe
    perfil = get_perfil_by_id(db, data.usuario_id)
    if not perfil:
        raise NotFoundException("Usuario no encontrado")

    # Verificar que la sucursal existe
    sucursal = get_sucursal(db, data.sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")

    # Verificar que usuario y sucursal son de la misma empresa
    if str(perfil["empresa_id"]) != str(sucursal["empresa_id"]):
        raise BadRequestException(
            "El usuario y la sucursal deben pertenecer a la misma empresa"
        )

    # Verificar acceso del admin a esa empresa
    verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))

    # Verificar que no existe ya la asignación activa
    if asignacion_activa_exists(db, data.usuario_id, data.sucursal_id):
        raise DuplicateValueException(
            "El usuario ya tiene una asignación activa en esta sucursal"
        )

    internal = UsuarioSucursalCreateInternal(
        **data.model_dump(),
        estado="activo",
        created_by=UUID(str(current_user["id"])),
    )
    return create_asignacion(db, internal)


# ─── PATCH actualizar asignación ─────────────────────────────────────────────

@router.patch(
    "/{asignacion_id}",
    response_model=UsuarioSucursalRead,
    summary="Actualizar rol o permisos de asignación",
)
def patch_asignacion(
    asignacion_id: UUID,
    values: UsuarioSucursalUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    asignacion = get_asignacion(db, asignacion_id)
    if not asignacion:
        raise NotFoundException("Asignación no encontrada")

    sucursal = get_sucursal(db, UUID(str(asignacion["sucursal_id"])))
    if sucursal:
        verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))

    internal = UsuarioSucursalUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
    )
    updated = update_asignacion(
        db, asignacion_id, internal,
        usuario_id=UUID(str(asignacion["usuario_id"])),
    )
    if not updated:
        raise NotFoundException("No se pudo actualizar la asignación")
    return updated


# ─── DELETE desactivar asignación ───────────────────────────────────────────

@router.delete(
    "/{asignacion_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar asignación de usuario a sucursal",
)
def delete_asignacion(
    asignacion_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    asignacion = get_asignacion(db, asignacion_id)
    if not asignacion:
        raise NotFoundException("Asignación no encontrada")

    sucursal = get_sucursal(db, UUID(str(asignacion["sucursal_id"])))
    if sucursal:
        verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))

    usuario_id = UUID(str(asignacion["usuario_id"]))
    desactivar_asignacion(db, asignacion_id, usuario_id)

    return {
        "message": "Asignación desactivada correctamente. "
                   "Si era la sucursal principal, se promovió otra automáticamente."
    }


# ─── DELETE hard ─────────────────────────────────────────────────────────────

@router.delete(
    "/{asignacion_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar asignación permanentemente",
)
def hard_delete_asignacion_endpoint(
    asignacion_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    asignacion = get_asignacion(db, asignacion_id)
    if not asignacion:
        raise NotFoundException("Asignación no encontrada")

    usuario_id = UUID(str(asignacion["usuario_id"]))
    hard_delete_asignacion(db, asignacion_id, usuario_id)
    return {"message": "Asignación eliminada permanentemente"}
