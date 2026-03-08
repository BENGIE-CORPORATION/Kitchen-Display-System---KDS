"""
Router de Perfiles de Usuario — solo lógica HTTP.
Toda la lógica de base de datos vive en app/crud/crud_perfiles_usuario.py

Seguridad:
  GET    /perfiles/me              → cualquier autenticado (su propio perfil)
  PATCH  /perfiles/me              → cualquier autenticado (solo sus datos)
  GET    /perfiles/                → admin_empresa (su empresa) / super_admin (todas)
  GET    /perfiles/empresa/{id}    → admin_empresa + verify_empresa_access / super_admin
  GET    /perfiles/{id}            → admin_empresa (su empresa) / super_admin
  PATCH  /perfiles/{id}/rol        → solo super_admin (no puede cambiar su propio rol)
  PATCH  /perfiles/{id}/estado     → admin_empresa o super_admin (no puede cambiar su propio estado)
  DELETE /perfiles/{id}            → admin_empresa (su empresa) o super_admin  [soft]
  DELETE /perfiles/{id}/hard       → solo super_admin
"""

from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, status
from loguru import logger
from pydantic import BaseModel
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
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
from ...crud.crud_perfiles_usuario import (
    cambiar_estado,
    cambiar_rol,
    get_perfil_by_id,
    get_perfiles_by_empresa,
    get_sucursales_del_usuario,
    hard_delete_perfil,
    soft_delete_perfil,
    update_perfil,
)
from ...database import get_supabase
from ...schemas.perfil import (
    MeResponse,
    PerfilPublicRead,
    PerfilRead,
    PerfilUpdate,
    PerfilUpdateInternal,
)

router = APIRouter(prefix="/perfiles", tags=["Perfiles de Usuario"])

ROLES_VALIDOS = {"super_admin", "admin_empresa", "empleado"}
ESTADOS_VALIDOS = {"activo", "inactivo", "suspendido"}


class RolUpdate(BaseModel):
    rol_global: str


class EstadoUpdate(BaseModel):
    estado: str


# ─── GET /perfiles/me ────────────────────────────────────────────────────────

@router.get("/me", response_model=MeResponse, summary="Mi perfil completo")
def get_me(
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    sucursales = get_sucursales_del_usuario(db, UUID(str(current_user["id"])))
    return {"perfil": current_user, "sucursales": sucursales}


# ─── PATCH /perfiles/me ──────────────────────────────────────────────────────

@router.patch("/me", response_model=PerfilRead, summary="Actualizar mi perfil")
@limiter.limit("20/hour", key_func=get_user_id_from_token)  # 🚦 cambios de perfil propios
def update_me(
    request: Request,
    values: PerfilUpdate,
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    # El usuario NO puede cambiar su propio rol, empresa ni estado por esta vía
    internal = PerfilUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
    )
    updated = update_perfil(db, UUID(str(current_user["id"])), internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar el perfil")

    logger.info("Perfil actualizado (self) | email={email}", email=current_user.get("email"))
    return updated


# ─── GET /perfiles/ ──────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[PerfilPublicRead],
    summary="Listar perfiles",
    description="admin_empresa ve solo su empresa. super_admin ve todos.",
)
def read_perfiles(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    estado: str | None = None,
    rol_global: str | None = None,
) -> dict:
    # super_admin no tiene empresa_id — pasa None para listar todos
    empresa_id = None
    if current_user["rol_global"] != "super_admin":
        empresa_id = UUID(str(current_user["empresa_id"]))

    return get_perfiles_by_empresa(
        db=db, empresa_id=empresa_id, page=page,
        items_per_page=items_per_page, estado=estado, rol_global=rol_global,
    )


# ─── GET /perfiles/empresa/{id} ──────────────────────────────────────────────

@router.get(
    "/empresa/{empresa_id}",
    response_model=PaginatedResponse[PerfilPublicRead],
    summary="Listar perfiles por empresa",
)
def read_perfiles_by_empresa(
    empresa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    estado: str | None = None,
    rol_global: str | None = None,
) -> dict:
    verify_empresa_access(current_user, empresa_id)  # 🔒 solo su empresa (salvo super_admin)
    return get_perfiles_by_empresa(
        db=db, empresa_id=empresa_id, page=page,
        items_per_page=items_per_page, estado=estado, rol_global=rol_global,
    )


# ─── GET /perfiles/{id} ──────────────────────────────────────────────────────

@router.get("/{usuario_id}", response_model=PerfilRead, summary="Obtener perfil por ID")
def read_perfil(
    usuario_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Perfil no encontrado")

    verify_empresa_access(current_user, UUID(str(perfil["empresa_id"])))  # 🔒 su empresa
    return perfil


# ─── PATCH /perfiles/{id}/rol ────────────────────────────────────────────────

@router.patch(
    "/{usuario_id}/rol",
    response_model=PerfilRead,
    summary="Cambiar rol global",
    description="Cambia el rol global del usuario. **Solo super_admin.**",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)  # 🚦 cambio de rol es operación sensible
def patch_rol(
    request: Request,
    usuario_id: UUID,
    values: RolUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    if values.rol_global not in ROLES_VALIDOS:
        raise BadRequestException(f"Rol inválido. Opciones: {', '.join(ROLES_VALIDOS)}")

    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Perfil no encontrado")

    if str(usuario_id) == str(current_user["id"]):
        raise ForbiddenException("No puedes cambiar tu propio rol")

    rol_anterior = perfil.get("rol_global")
    updated = cambiar_rol(db, usuario_id, values.rol_global)
    if not updated:
        raise NotFoundException("No se pudo actualizar el rol")

    logger.warning(
        "Rol cambiado | usuario={usuario} | {anterior} → {nuevo} | por={admin}",
        usuario=perfil.get("email"),
        anterior=rol_anterior,
        nuevo=values.rol_global,
        admin=current_user.get("email"),
    )
    return updated


# ─── PATCH /perfiles/{id}/estado ─────────────────────────────────────────────

@router.patch(
    "/{usuario_id}/estado",
    response_model=PerfilRead,
    summary="Suspender o reactivar usuario",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)  # 🚦 cambio de estado es operación sensible
def patch_estado(
    request: Request,
    usuario_id: UUID,
    values: EstadoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    if values.estado not in ESTADOS_VALIDOS:
        raise BadRequestException(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")

    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Perfil no encontrado")

    verify_empresa_access(current_user, UUID(str(perfil["empresa_id"])))  # 🔒 su empresa

    if str(usuario_id) == str(current_user["id"]):
        raise ForbiddenException("No puedes cambiar tu propio estado")

    estado_anterior = perfil.get("estado")
    updated = cambiar_estado(db, usuario_id, values.estado)
    if not updated:
        raise NotFoundException("No se pudo actualizar el estado")

    logger.warning(
        "Estado cambiado | usuario={usuario} | {anterior} → {nuevo} | por={admin}",
        usuario=perfil.get("email"),
        anterior=estado_anterior,
        nuevo=values.estado,
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /perfiles/{id} ── soft delete ─────────────────────────────────────

@router.delete(
    "/{usuario_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar usuario (soft delete)",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)  # 🚦 operación crítica
def delete_perfil(
    request: Request,
    usuario_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Perfil no encontrado")

    verify_empresa_access(current_user, UUID(str(perfil["empresa_id"])))  # 🔒 su empresa

    if str(usuario_id) == str(current_user["id"]):
        raise ForbiddenException("No puedes desactivar tu propia cuenta")

    soft_delete_perfil(db, db, usuario_id)

    logger.warning(
        "Usuario desactivado [soft] | email={email} | por={admin}",
        email=perfil.get("email"),
        admin=current_user.get("email"),
    )
    return {
        "message": f"Usuario '{perfil['nombre_completo']}' desactivado. "
                   "Sus sesiones activas fueron cerradas y asignaciones desactivadas."
    }


# ─── DELETE /perfiles/{id}/hard ──────────────────────────────────────────────

@router.delete(
    "/{usuario_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar usuario permanentemente",
    description="Borra el perfil y lo elimina de Supabase Auth. **Solo super_admin. Irreversible.**",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)  # 🚦 operación irreversible
def hard_delete_perfil_endpoint(
    request: Request,
    usuario_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Perfil no encontrado")

    if str(usuario_id) == str(current_user["id"]):
        raise ForbiddenException("No puedes eliminarte a ti mismo")

    success = hard_delete_perfil(db, db, usuario_id)

    logger.warning(
        "Usuario ELIMINADO [hard] | email={email} | por={admin} | auth_ok={ok}",
        email=perfil.get("email"),
        admin=current_user.get("email"),
        ok=success,
    )

    if not success:
        return {
            "message": "Perfil eliminado de BD pero hubo un error al eliminar de Auth. "
                       "Revisar manualmente en Supabase Dashboard.",
            "warning": True,
        }
    return {"message": f"Usuario '{perfil['nombre_completo']}' eliminado permanentemente"}