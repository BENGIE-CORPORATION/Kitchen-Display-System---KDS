"""
Router de Usuarios × Sucursales — solo lógica HTTP.
Toda la lógica de base de datos vive en app/crud/crud_usuarios_sucursales.py

Seguridad:
  GET    /usuarios-sucursales/sucursal/{id}  → admin_empresa o super_admin
  GET    /usuarios-sucursales/usuario/{id}   → el propio usuario, admin_empresa o super_admin
  POST   /usuarios-sucursales/               → admin_empresa o super_admin
  PATCH  /usuarios-sucursales/{id}           → admin_empresa o super_admin
  DELETE /usuarios-sucursales/{id}           → admin_empresa o super_admin  [soft]
  DELETE /usuarios-sucursales/{id}/hard      → solo super_admin
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
from ...crud.crud_perfiles_usuario import get_perfil_by_id
from ...crud.crud_sucursales import get_sucursal
from ...crud.crud_usuarios_sucursales import (
    asignacion_activa_exists,
    create_asignacion,
    desactivar_asignacion,
    get_asignacion,
    get_sucursales_de_usuario,
    get_usuarios_de_sucursal,
    hard_delete_asignacion,
    update_asignacion,
)
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
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    estado: str | None = "activo",
    rol_sucursal: str | None = None,
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")

    verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))  # 🔒 su empresa

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
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> list:
    # Empleado solo puede ver sus propias asignaciones
    if (
        current_user["rol_global"] == "empleado"
        and str(current_user["id"]) != str(usuario_id)
    ):
        raise ForbiddenException("Solo puedes ver tus propias asignaciones")

    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Usuario no encontrado")

    # Admin y super_admin verifican que el usuario sea de su empresa
    if current_user["rol_global"] != "empleado":
        verify_empresa_access(current_user, UUID(str(perfil["empresa_id"])))  # 🔒 su empresa

    return get_sucursales_de_usuario(db, usuario_id)


# ─── POST crear asignación ───────────────────────────────────────────────────

@router.post(
    "/",
    response_model=UsuarioSucursalRead,
    status_code=status.HTTP_201_CREATED,
    summary="Asignar usuario a sucursal",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)  # 🚦 escritura moderada
def create_usuario_sucursal(
    request: Request,
    data: UsuarioSucursalCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    perfil = get_perfil_by_id(db, data.usuario_id)
    if not perfil:
        raise NotFoundException("Usuario no encontrado")

    sucursal = get_sucursal(db, data.sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")

    # Usuario y sucursal deben ser de la misma empresa
    if str(perfil["empresa_id"]) != str(sucursal["empresa_id"]):
        raise BadRequestException("El usuario y la sucursal deben pertenecer a la misma empresa")

    verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))  # 🔒 su empresa

    if asignacion_activa_exists(db, data.usuario_id, data.sucursal_id):
        raise DuplicateValueException("El usuario ya tiene una asignación activa en esta sucursal")

    internal = UsuarioSucursalCreateInternal(
        **data.model_dump(),
        estado="activo",
        created_by=UUID(str(current_user["id"])),
    )
    nueva = create_asignacion(db, internal)

    logger.info(
        "Asignación creada | usuario={usuario} | sucursal={sucursal} | rol={rol} | por={admin}",
        usuario=str(data.usuario_id),
        sucursal=str(data.sucursal_id),
        rol=data.rol_sucursal,
        admin=current_user.get("email"),
    )
    return nueva


# ─── PATCH actualizar asignación ─────────────────────────────────────────────

@router.patch(
    "/{asignacion_id}",
    response_model=UsuarioSucursalRead,
    summary="Actualizar rol o permisos de asignación",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)  # 🚦 escritura moderada
def patch_asignacion(
    request: Request,
    asignacion_id: UUID,
    values: UsuarioSucursalUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    asignacion = get_asignacion(db, asignacion_id)
    if not asignacion:
        raise NotFoundException("Asignación no encontrada")

    sucursal = get_sucursal(db, UUID(str(asignacion["sucursal_id"])))
    if sucursal:
        verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))  # 🔒 su empresa

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

    logger.info(
        "Asignación actualizada | id={id} | por={admin}",
        id=str(asignacion_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE desactivar asignación ────────────────────────────────────────────

@router.delete(
    "/{asignacion_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar asignación (soft delete)",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)  # 🚦 operación crítica
def delete_asignacion(
    request: Request,
    asignacion_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    asignacion = get_asignacion(db, asignacion_id)
    if not asignacion:
        raise NotFoundException("Asignación no encontrada")

    sucursal = get_sucursal(db, UUID(str(asignacion["sucursal_id"])))
    if sucursal:
        verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))  # 🔒 su empresa

    usuario_id = UUID(str(asignacion["usuario_id"]))
    desactivar_asignacion(db, asignacion_id, usuario_id)

    logger.warning(
        "Asignación desactivada [soft] | id={id} | usuario={usuario} | por={admin}",
        id=str(asignacion_id),
        usuario=str(usuario_id),
        admin=current_user.get("email"),
    )
    return {
        "message": "Asignación desactivada correctamente. "
                   "Si era la sucursal principal, se promovió otra automáticamente."
    }


# ─── DELETE hard ─────────────────────────────────────────────────────────────

@router.delete(
    "/{asignacion_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar asignación permanentemente",
    description="Borra físicamente la asignación. **Solo super_admin. Irreversible.**",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)  # 🚦 operación irreversible
def hard_delete_asignacion_endpoint(
    request: Request,
    asignacion_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin (corregido)
) -> dict:
    asignacion = get_asignacion(db, asignacion_id)
    if not asignacion:
        raise NotFoundException("Asignación no encontrada")

    usuario_id = UUID(str(asignacion["usuario_id"]))
    hard_delete_asignacion(db, asignacion_id, usuario_id)

    logger.warning(
        "Asignación ELIMINADA [hard] | id={id} | usuario={usuario} | por={admin}",
        id=str(asignacion_id),
        usuario=str(usuario_id),
        admin=current_user.get("email"),
    )
    return {"message": "Asignación eliminada permanentemente"}