"""
Router de Perfiles de Usuario.

Seguridad por endpoint:
  GET    /perfiles/me              → cualquier autenticado (su propio perfil)
  PATCH  /perfiles/me              → cualquier autenticado (solo sus datos)
  GET    /perfiles/                → admin_empresa (ve su empresa) / super_admin (ve todo)
  GET    /perfiles/{id}            → admin_empresa (su empresa) / super_admin
  PATCH  /perfiles/{id}/rol        → solo super_admin
  PATCH  /perfiles/{id}/estado     → admin_empresa o super_admin
  DELETE /perfiles/{id}            → admin_empresa (su empresa) o super_admin
  DELETE /perfiles/{id}/hard       → solo super_admin
"""

from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from supabase import Client

from ...core.exceptions.http_exceptions import (
    ForbiddenException,
    NotFoundException,
)
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
from pydantic import BaseModel

router = APIRouter(prefix="/perfiles", tags=["Perfiles de Usuario"])


class RolUpdate(BaseModel):
    rol_global: str


class EstadoUpdate(BaseModel):
    estado: str


# ─── GET /perfiles/me ────────────────────────────────────────────────────────

@router.get("/me", response_model=MeResponse, summary="Mi perfil completo")
def get_me(
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    sucursales = get_sucursales_del_usuario(db, UUID(str(current_user["id"])))
    return {"perfil": current_user, "sucursales": sucursales}


# ─── PATCH /perfiles/me ──────────────────────────────────────────────────────

@router.patch("/me", response_model=PerfilRead, summary="Actualizar mi perfil")
def update_me(
    values: PerfilUpdate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    # El usuario NO puede cambiar su propio rol, empresa o estado
    internal = PerfilUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
    )
    updated = update_perfil(db, UUID(str(current_user["id"])), internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar el perfil")
    return updated


# ─── GET /perfiles/ ──────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[PerfilPublicRead],
    summary="Listar perfiles de la empresa",
)
def read_perfiles(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    estado: str | None = None,
    rol_global: str | None = None,
) -> dict:
    # super_admin necesita especificar empresa
    if current_user["rol_global"] == "super_admin":
        from ...core.exceptions.http_exceptions import BadRequestException
        raise BadRequestException("super_admin debe usar /perfiles/empresa/{empresa_id}")

    empresa_id = UUID(str(current_user["empresa_id"]))
    return get_perfiles_by_empresa(
        db=db, empresa_id=empresa_id, page=page,
        items_per_page=items_per_page, estado=estado, rol_global=rol_global,
    )


@router.get(
    "/empresa/{empresa_id}",
    response_model=PaginatedResponse[PerfilPublicRead],
    summary="Listar perfiles por empresa (super_admin o admin)",
)
def read_perfiles_by_empresa(
    empresa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    estado: str | None = None,
    rol_global: str | None = None,
) -> dict:
    verify_empresa_access(current_user, empresa_id)
    return get_perfiles_by_empresa(
        db=db, empresa_id=empresa_id, page=page,
        items_per_page=items_per_page, estado=estado, rol_global=rol_global,
    )


# ─── GET /perfiles/{id} ──────────────────────────────────────────────────────

@router.get("/{usuario_id}", response_model=PerfilRead, summary="Obtener perfil por ID")
def read_perfil(
    usuario_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Perfil no encontrado")
    verify_empresa_access(current_user, UUID(str(perfil["empresa_id"])))
    return perfil


# ─── PATCH /perfiles/{id}/rol ────────────────────────────────────────────────

@router.patch(
    "/{usuario_id}/rol",
    response_model=PerfilRead,
    summary="Cambiar rol global (solo super_admin)",
)
def patch_rol(
    usuario_id: UUID,
    values: RolUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],
) -> dict:
    roles_validos = {"super_admin", "admin_empresa", "empleado"}
    if values.rol_global not in roles_validos:
        from ...core.exceptions.http_exceptions import BadRequestException
        raise BadRequestException(f"Rol inválido. Opciones: {', '.join(roles_validos)}")

    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Perfil no encontrado")

    # Protección: no se puede quitar el rol a uno mismo
    if str(usuario_id) == str(current_user["id"]):
        raise ForbiddenException("No puedes cambiar tu propio rol")

    updated = cambiar_rol(db, usuario_id, values.rol_global)
    if not updated:
        raise NotFoundException("No se pudo actualizar el rol")
    return updated


# ─── PATCH /perfiles/{id}/estado ─────────────────────────────────────────────

@router.patch(
    "/{usuario_id}/estado",
    response_model=PerfilRead,
    summary="Suspender o reactivar usuario",
)
def patch_estado(
    usuario_id: UUID,
    values: EstadoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    estados_validos = {"activo", "inactivo", "suspendido"}
    if values.estado not in estados_validos:
        from ...core.exceptions.http_exceptions import BadRequestException
        raise BadRequestException(f"Estado inválido. Opciones: {', '.join(estados_validos)}")

    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Perfil no encontrado")
    verify_empresa_access(current_user, UUID(str(perfil["empresa_id"])))

    # No se puede suspender a uno mismo
    if str(usuario_id) == str(current_user["id"]):
        raise ForbiddenException("No puedes cambiar tu propio estado")

    updated = cambiar_estado(db, usuario_id, values.estado)
    if not updated:
        raise NotFoundException("No se pudo actualizar el estado")
    return updated


# ─── DELETE /perfiles/{id} (soft) ────────────────────────────────────────────

@router.delete("/{usuario_id}", status_code=status.HTTP_200_OK, summary="Desactivar usuario")
def delete_perfil(
    usuario_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Perfil no encontrado")
    verify_empresa_access(current_user, UUID(str(perfil["empresa_id"])))

    if str(usuario_id) == str(current_user["id"]):
        raise ForbiddenException("No puedes desactivar tu propia cuenta")

    soft_delete_perfil(db, db, usuario_id)
    return {
        "message": f"Usuario '{perfil['nombre_completo']}' desactivado. "
                   "Sus sesiones activas fueron cerradas y asignaciones desactivadas."
    }


# ─── DELETE /perfiles/{id}/hard ──────────────────────────────────────────────

@router.delete(
    "/{usuario_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar usuario permanentemente (super_admin)",
)
def hard_delete_perfil_endpoint(
    usuario_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],
) -> dict:
    perfil = get_perfil_by_id(db, usuario_id)
    if not perfil:
        raise NotFoundException("Perfil no encontrado")

    if str(usuario_id) == str(current_user["id"]):
        raise ForbiddenException("No puedes eliminarte a ti mismo")

    success = hard_delete_perfil(db, db, usuario_id)
    if not success:
        return {
            "message": "Perfil eliminado de BD pero hubo un error al eliminar de Auth. "
                       "Revisar manualmente en Supabase Dashboard.",
            "warning": True,
        }
    return {"message": f"Usuario '{perfil['nombre_completo']}' eliminado permanentemente"}
