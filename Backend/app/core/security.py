"""
Dependencias de seguridad — se inyectan en los routers con Depends().

Uso en un endpoint:
    def mi_endpoint(current_user: Annotated[PerfilRead, Depends(get_current_user)]):
        ...

Capas disponibles:
    get_current_user        → cualquier usuario autenticado y activo
    get_current_admin       → admin_empresa o super_admin
    get_current_superadmin  → solo super_admin
    verify_empresa_access   → el usuario pertenece a esa empresa
    verify_sucursal_access  → el usuario tiene acceso a esa sucursal
"""

from typing import Annotated
from uuid import UUID

from fastapi import Depends, Header
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from supabase import Client

from ..core.exceptions.http_exceptions import (
    ForbiddenException,
    NotFoundException,
    UnauthorizedException,
)
from ..crud.crud_perfiles import get_perfil_by_id, tiene_acceso_sucursal
from ..database import get_supabase

# Extrae el Bearer token del header Authorization
oauth2_scheme = HTTPBearer(auto_error=False)


# ─── CAPA 1: Verificar JWT y retornar perfil ──────────────────────────────────

def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(oauth2_scheme)],
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    """
    Dependencia base. Verifica que:
    1. Venga un Bearer token en el header
    2. El token sea válido (Supabase lo verifica criptográficamente)
    3. El usuario exista en perfiles_usuario
    4. El usuario esté activo (no suspendido/inactivo)

    Retorna el perfil completo del usuario.
    Se usa en TODOS los endpoints que requieran autenticación.
    """
    # 1. Verificar que venga el header Authorization
    if not credentials:
        raise UnauthorizedException(
            "Se requiere autenticación. Envía el token en el header: Authorization: Bearer <token>"
        )

    token = credentials.credentials

    # 2. Validar el JWT con Supabase (verifica firma, expiración, etc.)
    try:
        auth_response = db.auth.get_user(token)
        if not auth_response or not auth_response.user:
            raise UnauthorizedException("Token inválido o expirado")
        auth_user = auth_response.user
    except Exception:
        raise UnauthorizedException("Token inválido o expirado")

    # 3. Buscar el perfil en perfiles_usuario
    perfil = get_perfil_by_id(db, UUID(auth_user.id))
    if not perfil:
        raise NotFoundException(
            "Perfil de usuario no encontrado. Contacta al administrador."
        )

    # 4. Verificar que el usuario esté activo
    if perfil.get("estado") != "activo":
        estado = perfil.get("estado", "desconocido")
        raise ForbiddenException(
            f"Tu cuenta está {estado}. Contacta al administrador."
        )

    return perfil


# ─── CAPA 2A: Solo admin_empresa o super_admin ────────────────────────────────

def get_current_admin(
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    """
    Requiere rol admin_empresa o super_admin.
    Se usa en endpoints de gestión: crear sucursales, invitar empleados, etc.
    """
    rol = current_user.get("rol_global")
    if rol not in ("admin_empresa", "super_admin"):
        raise ForbiddenException(
            "Se requiere rol de administrador para esta acción"
        )
    return current_user


# ─── CAPA 2B: Solo super_admin ────────────────────────────────────────────────

def get_current_superadmin(
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    """
    Requiere rol super_admin (solo los dueños del sistema).
    Se usa en endpoints críticos: suspender empresas, hard delete, etc.
    """
    if current_user.get("rol_global") != "super_admin":
        raise ForbiddenException(
            "Se requiere rol super_admin para esta acción"
        )
    return current_user


# ─── CAPA 3A: Verificar que el recurso pertenece a la empresa del usuario ─────

def verify_empresa_access(current_user: dict, empresa_id: UUID) -> None:
    """
    Verifica que el usuario pertenezca a la empresa que está intentando acceder.
    Los super_admin pueden acceder a cualquier empresa.

    Uso en router:
        empresa = get_empresa(db, empresa_id)
        verify_empresa_access(current_user, empresa_id)
    """
    if current_user.get("rol_global") == "super_admin":
        return  # super_admin puede acceder a todo

    user_empresa_id = str(current_user.get("empresa_id", ""))
    if user_empresa_id != str(empresa_id):
        raise ForbiddenException(
            "No tienes acceso a los recursos de esta empresa"
        )


# ─── CAPA 3B: Verificar acceso a una sucursal específica ─────────────────────

def verify_sucursal_access(
    db: Client,
    current_user: dict,
    sucursal_id: UUID,
    roles_requeridos: list[str] | None = None,
) -> dict:
    """
    Verifica que el usuario tenga acceso a una sucursal específica.

    - super_admin: acceso total sin verificar
    - admin_empresa: acceso a todas las sucursales de su empresa
    - empleado: solo sus sucursales asignadas en usuarios_sucursales

    Si `roles_requeridos` se especifica, también verifica el rol dentro
    de la sucursal. Ej: roles_requeridos=["administrador", "cajero"]

    Retorna la asignación (con rol_sucursal y permisos) o lanza 403.
    """
    rol_global = current_user.get("rol_global")

    # super_admin pasa siempre
    if rol_global == "super_admin":
        return {"rol_sucursal": "super_admin", "permisos": []}

    # admin_empresa: verificar que la sucursal pertenece a su empresa
    if rol_global == "admin_empresa":
        # La verificación de empresa se hace en el CRUD al consultar la sucursal
        # Aquí simplemente permitimos el paso
        return {"rol_sucursal": "administrador", "permisos": []}

    # empleado: verificar asignación en usuarios_sucursales
    user_id = UUID(str(current_user.get("id")))
    asignacion = tiene_acceso_sucursal(db, user_id, sucursal_id)

    if not asignacion:
        raise ForbiddenException(
            "No tienes acceso a esta sucursal"
        )

    # Verificar rol específico si se requiere
    if roles_requeridos and asignacion.get("rol_sucursal") not in roles_requeridos:
        raise ForbiddenException(
            f"Se requiere uno de estos roles: {', '.join(roles_requeridos)}"
        )

    return asignacion