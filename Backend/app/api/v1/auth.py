"""
Router de Autenticación.
Endpoints públicos:  /register, /login, /refresh
Endpoints protegidos: /me, /logout, /invite
"""
import secrets
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    ForbiddenException,
    NotFoundException,
    UnauthorizedException,
)
from ...core.security import get_current_user
from ...crud.crud_perfiles import (
    create_perfil,
    get_perfil_by_email,
    get_sucursales_del_usuario,
    update_ultimo_acceso,
)
from ...database import get_supabase, get_supabase_admin
from ...schemas.auth import (
    InviteEmpleadoRequest,
    LoginRequest,
    MessageResponse,
    RefreshTokenRequest,
    RegisterRequest,
    TokenResponse,
)
from ...schemas.perfil import MeResponse, PerfilCreateInternal

router = APIRouter(prefix="/auth", tags=["Auth"])


# ─── POST /auth/register ─────────────────────────────────────────────────────

@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar nuevo admin de empresa",
    description="""
Crea una cuenta para el administrador de una empresa.

**Flujo:**
1. Verifica que el email no esté en uso
2. Crea el usuario en Supabase Auth
3. Crea el perfil en `perfiles_usuario` con rol `admin_empresa`
4. Retorna los tokens de acceso

**Nota:** Para crear empleados usa `/auth/invite`.
    """,
)
def register(
    data: RegisterRequest,
    db: Annotated[Client, Depends(get_supabase)],
    db_admin: Annotated[Client, Depends(get_supabase_admin)],
) -> dict:
    # 1. Verificar duplicado de email
    if get_perfil_by_email(db, data.email):
        raise DuplicateValueException("El email ya está registrado")

    # 2. Crear en Supabase Auth
    # Usamos db_admin con email_confirm=True para no requerir verificación de email
    try:
        auth_response = db_admin.auth.admin.create_user({
            "email": data.email,
            "password": data.password,
            "email_confirm": True,
        })
    except Exception as e:
        raise BadRequestException(f"Error al crear cuenta: {str(e)}")

    if not auth_response.user:
        raise BadRequestException("No se pudo crear la cuenta. Intenta de nuevo.")

    auth_user = auth_response.user

    # 3. Crear perfil en perfiles_usuario
    # Si esto falla → rollback: borrar usuario de auth para evitar el limbo
    try:
        perfil = PerfilCreateInternal(
            id=UUID(auth_user.id),
            empresa_id=UUID(data.empresa_id),
            nombre_completo=data.nombre_completo,
            email=data.email,
            rol_global="admin_empresa",
            estado="activo",
        )
        create_perfil(db, perfil)
    except Exception as e:
        # ROLLBACK: eliminar de auth para no dejar usuario huérfano
        try:
            db_admin.auth.admin.delete_user(auth_user.id)
        except Exception:
            pass  # Si el rollback también falla, al menos logueamos
        raise BadRequestException(f"Error al crear perfil: {str(e)}")

    # 4. Hacer login para obtener los tokens (admin.create_user no retorna sesión)
    try:
        login_response = db.auth.sign_in_with_password({
            "email": data.email,
            "password": data.password,
        })
        session = login_response.session
    except Exception:
        # El usuario fue creado pero no podemos hacer login automático
        # No es crítico — puede hacer login manualmente
        return {
            "access_token": "",
            "refresh_token": "",
            "token_type": "bearer",
            "expires_in": 0,
            "message": "Cuenta creada. Por favor inicia sesión manualmente."
        }

    return {
        "access_token": session.access_token,
        "refresh_token": session.refresh_token,
        "token_type": "bearer",
        "expires_in": session.expires_in,
    }


# ─── POST /auth/login ────────────────────────────────────────────────────────

@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Iniciar sesión",
    description="Autentica al usuario y retorna JWT + refresh token.",
)
def login(
    data: LoginRequest,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    # 1. Autenticar con Supabase Auth
    try:
        auth_response = db.auth.sign_in_with_password({
            "email": data.email,
            "password": data.password,
        })
    except Exception:
        raise UnauthorizedException("Email o contraseña incorrectos")

    if not auth_response.user or not auth_response.session:
        raise UnauthorizedException("Email o contraseña incorrectos")

    # 2. Verificar perfil activo
    perfil = get_perfil_by_email(db, data.email)
    if not perfil:
        raise NotFoundException("Perfil no encontrado. Contacta al administrador.")

    if perfil.get("estado") != "activo":
        estado = perfil.get("estado", "inactivo")
        raise UnauthorizedException(
            f"Tu cuenta está {estado}. Contacta al administrador."
        )

    # 3. Actualizar último acceso (no bloqueante — si falla no rompe el login)
    update_ultimo_acceso(db, UUID(str(perfil["id"])))

    session = auth_response.session
    return {
        "access_token": session.access_token,
        "refresh_token": session.refresh_token,
        "token_type": "bearer",
        "expires_in": session.expires_in,
    }


# ─── POST /auth/refresh ──────────────────────────────────────────────────────

@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="Renovar token de acceso",
    description="""
Usa el `refresh_token` para obtener un nuevo `access_token` sin pedir contraseña.
El `access_token` expira cada 1 hora por defecto en Supabase.
    """,
)
def refresh_token(
    data: RefreshTokenRequest,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    try:
        auth_response = db.auth.refresh_session(data.refresh_token)
    except Exception:
        raise UnauthorizedException(
            "Refresh token inválido o expirado. Inicia sesión de nuevo."
        )

    if not auth_response.session:
        raise UnauthorizedException("No se pudo renovar la sesión.")

    session = auth_response.session
    return {
        "access_token": session.access_token,
        "refresh_token": session.refresh_token,
        "token_type": "bearer",
        "expires_in": session.expires_in,
    }


# ─── POST /auth/logout ───────────────────────────────────────────────────────

@router.post(
    "/logout",
    response_model=MessageResponse,
    summary="Cerrar sesión",
    description="Invalida el token actual. El cliente debe eliminar los tokens guardados.",
)
def logout(
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    try:
        db.auth.sign_out()
    except Exception:
        pass
    return {"message": "Sesión cerrada correctamente"}


# ─── GET /auth/me ────────────────────────────────────────────────────────────

@router.get(
    "/me",
    response_model=MeResponse,
    summary="Mi perfil completo",
    description="""
Retorna el perfil del usuario autenticado + sus sucursales asignadas.
**Requiere:** `Authorization: Bearer <access_token>`
    """,
)
def get_me(
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    user_id = UUID(str(current_user["id"]))
    sucursales = get_sucursales_del_usuario(db, user_id)
    return {
        "perfil": current_user,
        "sucursales": sucursales,
    }


# ─── POST /auth/invite ───────────────────────────────────────────────────────

@router.post(
    "/invite",
    response_model=dict,
    status_code=status.HTTP_201_CREATED,
    summary="Crear empleado",
    description="""
Crea un nuevo empleado en el sistema.

**Flujo:**
1. Crea el usuario en Supabase Auth con contraseña temporal
2. Crea el perfil en `perfiles_usuario` con rol `empleado`
3. Crea la asignación en `usuarios_sucursales`
4. Retorna la contraseña temporal para compartirla al empleado

**Requiere:** rol `admin_empresa` o `super_admin`

**Rollback automático:** si cualquier paso falla, se deshace lo anterior
para evitar usuarios en estado inconsistente.
    """,
)
def invite_empleado(
    data: InviteEmpleadoRequest,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
    db_admin: Annotated[Client, Depends(get_supabase_admin)],  # ← cliente admin
) -> dict:
    # ── Verificar permisos ────────────────────────────────────────────────────
    if current_user.get("rol_global") not in ("admin_empresa", "super_admin"):
        raise ForbiddenException("Solo administradores pueden crear empleados")

    if current_user.get("rol_global") == "admin_empresa":
        if str(current_user.get("empresa_id")) != data.empresa_id:
            raise ForbiddenException("No puedes crear usuarios en otra empresa")

    # ── Verificar que el email no esté en uso ─────────────────────────────────
    if get_perfil_by_email(db, data.email):
        raise DuplicateValueException("El email ya está registrado")

    # ── Paso 1: Crear en Supabase Auth ────────────────────────────────────────
    temp_password = secrets.token_urlsafe(12) + "A1!"

    try:
        auth_response = db_admin.auth.admin.create_user({  # ← db_admin aquí
            "email": data.email,
            "password": temp_password,
            "email_confirm": True,
        })
    except Exception as e:
        raise BadRequestException(f"Error al crear usuario en Auth: {str(e)}")

    if not auth_response.user:
        raise BadRequestException("No se pudo crear el usuario")

    auth_user = auth_response.user

    # ── Paso 2: Crear perfil ─────────────────────────────────────────────────
    # Si falla → ROLLBACK: borrar de auth
    try:
        perfil = PerfilCreateInternal(
            id=UUID(auth_user.id),
            empresa_id=UUID(data.empresa_id),
            nombre_completo=data.nombre_completo,
            email=data.email,
            rol_global="empleado",
            estado="activo",
            created_by=UUID(str(current_user["id"])),
        )
        create_perfil(db, perfil)
    except Exception as e:
        # ROLLBACK paso 1
        try:
            db_admin.auth.admin.delete_user(auth_user.id)
        except Exception:
            pass
        raise BadRequestException(f"Error al crear perfil: {str(e)}")

    # ── Paso 3: Crear asignación en usuarios_sucursales ───────────────────────
    # Si falla → ROLLBACK: borrar perfil y usuario de auth
    try:
        db.table("usuarios_sucursales").insert({
            "usuario_id": str(auth_user.id),
            "sucursal_id": data.sucursal_id,
            "rol_sucursal": data.rol_sucursal,
            "es_principal": True,   # primera sucursal → es la principal
            "estado": "activo",
            "created_by": str(current_user["id"]),
        }).execute()
    except Exception as e:
        # ROLLBACK pasos 1 y 2
        try:
            db.table("perfiles_usuario").delete().eq("id", str(auth_user.id)).execute()
            db_admin.auth.admin.delete_user(auth_user.id)
        except Exception:
            pass
        raise BadRequestException(f"Error al asignar sucursal: {str(e)}")

    return {
        "message": f"Empleado '{data.nombre_completo}' creado exitosamente",
        "email": data.email,
        "password_temporal": temp_password,
        "nota": "Comparte estas credenciales al empleado de forma segura. Debe cambiar su contraseña en el primer login.",
    }