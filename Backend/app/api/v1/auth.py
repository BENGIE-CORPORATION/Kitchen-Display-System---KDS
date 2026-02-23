"""
Router de Autenticación.
Endpoints públicos: /register, /login, /refresh
Endpoints protegidos: /me, /logout, /invite
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    NotFoundException,
    UnauthorizedException,
)
from ...core.security import get_current_user
from ...crud.crud_perfiles import (
    create_perfil,
    get_perfil_by_email,
    get_sucursales_del_usuario,
    perfil_exists,
    update_ultimo_acceso,
)
from ...database import get_supabase
from ...schemas.auth import (
    InviteEmpleadoRequest,
    LoginRequest,
    MessageResponse,
    RefreshTokenRequest,
    RegisterRequest,
    TokenResponse,
)
from ...schemas.perfil import MeResponse, PerfilCreateInternal, PerfilRead

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

**Nota:** Para crear empleados, usa el endpoint `/auth/invite`.
    """,
)
def register(
    data: RegisterRequest,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    # 1. Verificar que el email no esté en uso en perfiles_usuario
    if get_perfil_by_email(db, data.email):
        raise DuplicateValueException("El email ya está registrado")

    # 2. Registrar en Supabase Auth
    try:
        auth_response = db.auth.sign_up({
            "email": data.email,
            "password": data.password,
        })
    except Exception as e:
        raise BadRequestException(f"Error al crear cuenta: {str(e)}")

    if not auth_response.user:
        raise BadRequestException("No se pudo crear la cuenta. Intenta de nuevo.")

    auth_user = auth_response.user

    # 3. Crear perfil en perfiles_usuario
    perfil = PerfilCreateInternal(
        id=UUID(auth_user.id),
        empresa_id=UUID(data.empresa_id),
        nombre_completo=data.nombre_completo,
        email=data.email,
        rol_global="admin_empresa",
        estado="activo",
    )
    create_perfil(db, perfil)

    # 4. Retornar tokens
    session = auth_response.session
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
        # Siempre mismo mensaje — no revelar si el email existe o no
        raise UnauthorizedException("Email o contraseña incorrectos")

    if not auth_response.user or not auth_response.session:
        raise UnauthorizedException("Email o contraseña incorrectos")

    # 2. Verificar que el perfil existe y está activo
    perfil = get_perfil_by_email(db, data.email)
    if not perfil:
        raise NotFoundException("Perfil no encontrado. Contacta al administrador.")

    if perfil.get("estado") != "activo":
        estado = perfil.get("estado", "inactivo")
        raise UnauthorizedException(f"Tu cuenta está {estado}. Contacta al administrador.")

    # 3. Actualizar último acceso (no bloqueante)
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
Usa el `refresh_token` para obtener un nuevo `access_token` sin pedir la contraseña.

**Cuándo usarlo:** Cuando el `access_token` expira (por defecto cada 1 hora en Supabase).
    """,
)
def refresh_token(
    data: RefreshTokenRequest,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    try:
        auth_response = db.auth.refresh_session(data.refresh_token)
    except Exception:
        raise UnauthorizedException("Refresh token inválido o expirado. Inicia sesión de nuevo.")

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
    description="Invalida el token actual en Supabase. El cliente debe eliminar los tokens guardados.",
)
def logout(
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    try:
        db.auth.sign_out()
    except Exception:
        pass  # Si falla el sign_out en Supabase, igual respondemos OK
    return {"message": "Sesión cerrada correctamente"}


# ─── GET /auth/me ────────────────────────────────────────────────────────────

@router.get(
    "/me",
    response_model=MeResponse,
    summary="Mi perfil",
    description="""
Retorna el perfil completo del usuario autenticado más sus accesos a sucursales.

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
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Invitar empleado",
    description="""
El admin invita a un empleado. Supabase le envía un email con un link para que
establezca su contraseña.

**Requiere:** rol `admin_empresa` o `super_admin`
    """,
)
def invite_empleado(
    data: InviteEmpleadoRequest,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    # Solo admins pueden invitar
    if current_user.get("rol_global") not in ("admin_empresa", "super_admin"):
        from ...core.exceptions.http_exceptions import ForbiddenException
        raise ForbiddenException("Solo administradores pueden invitar empleados")

    # admin_empresa solo puede invitar a su propia empresa
    if current_user.get("rol_global") == "admin_empresa":
        if str(current_user.get("empresa_id")) != data.empresa_id:
            from ...core.exceptions.http_exceptions import ForbiddenException
            raise ForbiddenException("No puedes invitar usuarios a otra empresa")

    # Verificar que el email no esté en uso
    if get_perfil_by_email(db, data.email):
        raise DuplicateValueException("El email ya está registrado")

    # Invitar via Supabase Auth (envía email automáticamente)
    try:
        auth_response = db.auth.admin.invite_user_by_email(data.email)
    except Exception as e:
        raise BadRequestException(f"Error al enviar invitación: {str(e)}")

    if not auth_response.user:
        raise BadRequestException("No se pudo crear la invitación")

    auth_user = auth_response.user

    # Crear perfil con rol empleado
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

    # Crear asignación en usuarios_sucursales
    db.table("usuarios_sucursales").insert({
        "usuario_id": str(auth_user.id),
        "sucursal_id": data.sucursal_id,
        "rol_sucursal": data.rol_sucursal,
        "estado": "activo",
        "created_by": str(current_user["id"]),
    }).execute()

    return {"message": f"Invitación enviada a {data.email}"}