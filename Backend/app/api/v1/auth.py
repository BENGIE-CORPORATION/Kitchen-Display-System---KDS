from pydantic import BaseModel, Field, field_validator
"""
Router de Autenticación.
Endpoints públicos:   /login, /refresh, /register
Endpoints protegidos: /me, /logout, /invite
"""
import secrets
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request, status
from loguru import logger
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    ForbiddenException,
    NotFoundException,
    UnauthorizedException,
)
from ...core.limiter import get_user_id_from_token, limiter
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


# ─── POST /auth/login ────────────────────────────────────────────────────────

@router.post("/login", response_model=TokenResponse, summary="Iniciar sesión")
@limiter.limit("5/minute")   # 🚦 5 intentos por minuto por IP — anti brute force
def login(
    request: Request,        # ← requerido por slowapi (siempre primer parámetro)
    data: LoginRequest,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    try:
        auth_response = db.auth.sign_in_with_password({
            "email": data.email,
            "password": data.password,
        })
    except Exception:
        logger.warning("Login fallido | email={email}", email=data.email)
        raise UnauthorizedException("Email o contraseña incorrectos")

    if not auth_response.user or not auth_response.session:
        logger.warning("Login fallido (sin sesión) | email={email}", email=data.email)
        raise UnauthorizedException("Email o contraseña incorrectos")

    perfil = get_perfil_by_email(db, data.email)
    if not perfil:
        logger.error("Login sin perfil | email={email} | UUID={uid}", email=data.email, uid=auth_response.user.id)
        raise NotFoundException("Perfil no encontrado. Contacta al administrador.")

    if perfil.get("estado") != "activo":
        estado = perfil.get("estado")
        logger.warning("Login bloqueado | email={email} | estado={estado}", email=data.email, estado=estado)
        raise UnauthorizedException(f"Tu cuenta está {estado}. Contacta al administrador.")

    update_ultimo_acceso(db, UUID(str(perfil["id"])))
    logger.info("Login exitoso | email={email} | rol={rol}", email=data.email, rol=perfil.get("rol_global"))

    session = auth_response.session
    return {
        "access_token": session.access_token,
        "refresh_token": session.refresh_token,
        "token_type": "bearer",
        "expires_in": session.expires_in,
    }


# ─── POST /auth/register ─────────────────────────────────────────────────────

@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED, summary="Registrar admin de empresa")
@limiter.limit("3/hour")   # 🚦 3 registros por hora por IP — anti spam
def register(
    request: Request,
    data: RegisterRequest,
    db: Annotated[Client, Depends(get_supabase)],
    db_admin: Annotated[Client, Depends(get_supabase_admin)],
) -> dict:
    if get_perfil_by_email(db, data.email):
        raise DuplicateValueException("El email ya está registrado")

    try:
        auth_response = db_admin.auth.admin.create_user({
            "email": data.email,
            "password": data.password,
            "email_confirm": True,
        })
    except Exception as e:
        logger.error("Error creando usuario en Auth | email={email} | error={error}", email=data.email, error=str(e))
        raise BadRequestException(f"Error al crear cuenta: {str(e)}")

    if not auth_response.user:
        raise BadRequestException("No se pudo crear la cuenta. Intenta de nuevo.")

    auth_user = auth_response.user

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
        logger.error("Rollback registro | email={email} | error={error}", email=data.email, error=str(e))
        try:
            db_admin.auth.admin.delete_user(auth_user.id)
        except Exception:
            pass
        raise BadRequestException(f"Error al crear perfil: {str(e)}")

    logger.info("Admin registrado | email={email} | empresa_id={empresa_id}", email=data.email, empresa_id=data.empresa_id)

    try:
        login_response = db.auth.sign_in_with_password({"email": data.email, "password": data.password})
        session = login_response.session
        return {
            "access_token": session.access_token,
            "refresh_token": session.refresh_token,
            "token_type": "bearer",
            "expires_in": session.expires_in,
        }
    except Exception:
        return {"access_token": "", "refresh_token": "", "token_type": "bearer", "expires_in": 0}


# ─── POST /auth/refresh ──────────────────────────────────────────────────────

@router.post("/refresh", response_model=TokenResponse, summary="Renovar token")
@limiter.limit("20/minute")   # 🚦 20 refreshes por minuto — el cliente puede renovar seguido
def refresh_token(
    request: Request,
    data: RefreshTokenRequest,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    try:
        auth_response = db.auth.refresh_session(data.refresh_token)
    except Exception:
        raise UnauthorizedException("Refresh token inválido o expirado.")

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

@router.post("/logout", response_model=MessageResponse, summary="Cerrar sesión")
@limiter.limit("10/minute", key_func=get_user_id_from_token)
def logout(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    try:
        db.auth.sign_out()
    except Exception:
        pass
    logger.info("Logout | email={email}", email=current_user.get("email"))
    return {"message": "Sesión cerrada correctamente"}


# ─── GET /auth/me ────────────────────────────────────────────────────────────

@router.get("/me", response_model=MeResponse, summary="Mi perfil")
def get_me(
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    # /me no tiene rate limit — es llamado constantemente por el frontend
    user_id = UUID(str(current_user["id"]))
    sucursales = get_sucursales_del_usuario(db, user_id)
    return {"perfil": current_user, "sucursales": sucursales}


# ─── POST /auth/invite ───────────────────────────────────────────────────────

@router.post("/invite", response_model=dict, status_code=status.HTTP_201_CREATED, summary="Crear empleado")
@limiter.limit("20/hour", key_func=get_user_id_from_token)   # 🚦 por usuario, no por IP
def invite_empleado(
    request: Request,
    data: InviteEmpleadoRequest,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
    db_admin: Annotated[Client, Depends(get_supabase_admin)],
) -> dict:
    if current_user.get("rol_global") not in ("admin_empresa", "super_admin"):
        raise ForbiddenException("Solo administradores pueden crear empleados")

    if current_user.get("rol_global") == "admin_empresa":
        if str(current_user.get("empresa_id")) != data.empresa_id:
            raise ForbiddenException("No puedes crear usuarios en otra empresa")

    if get_perfil_by_email(db, data.email):
        raise DuplicateValueException("El email ya está registrado")

    temp_password = secrets.token_urlsafe(12) + "A1!"

    # ── Paso 1: crear en Auth ─────────────────────────────────────────────────
    try:
        auth_response = db_admin.auth.admin.create_user({
            "email": data.email,
            "password": temp_password,
            "email_confirm": True,
        })
    except Exception as e:
        logger.error("Error invite Auth | email={email} | error={error}", email=data.email, error=str(e))
        raise BadRequestException(f"Error al crear usuario en Auth: {str(e)}")

    if not auth_response.user:
        raise BadRequestException("No se pudo crear el usuario")

    auth_user = auth_response.user

    # ── Paso 2: crear perfil — rollback si falla ──────────────────────────────
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
        logger.error("Rollback invite (perfil) | email={email}", email=data.email)
        try:
            db_admin.auth.admin.delete_user(auth_user.id)
        except Exception:
            pass
        raise BadRequestException(f"Error al crear perfil: {str(e)}")

    # ── Paso 3: asignar sucursal — rollback si falla ──────────────────────────
    try:
        db.table("usuarios_sucursales").insert({
            "usuario_id": str(auth_user.id),
            "sucursal_id": data.sucursal_id,
            "rol_sucursal": data.rol_sucursal,
            "es_principal": True,
            "estado": "activo",
            "created_by": str(current_user["id"]),
        }).execute()
    except Exception as e:
        logger.error("Rollback invite (sucursal) | email={email}", email=data.email)
        try:
            db.table("perfiles_usuario").delete().eq("id", str(auth_user.id)).execute()
            db_admin.auth.admin.delete_user(auth_user.id)
        except Exception:
            pass
        raise BadRequestException(f"Error al asignar sucursal: {str(e)}")

    logger.info(
        "Empleado creado | email={email} | rol={rol} | por={admin}",
        email=data.email,
        rol=data.rol_sucursal,
        admin=current_user.get("email"),
    )

    return {
        "message": f"Empleado '{data.nombre_completo}' creado exitosamente",
        "email": data.email,
        "password_temporal": temp_password,
        "nota": "Comparte estas credenciales al empleado de forma segura.",
    }


# ─── POST /auth/change-password ──────────────────────────────────────────────

class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=8)
    new_password: str = Field(min_length=8)

    @field_validator("new_password")
    @classmethod
    def validate_strength(cls, v: str) -> str:
        if not any(c.islower() for c in v):
            raise ValueError("La contraseña debe tener al menos una minúscula")
        if not any(c.isupper() for c in v):
            raise ValueError("La contraseña debe tener al menos una mayúscula")
        if not any(c.isdigit() for c in v):
            raise ValueError("La contraseña debe tener al menos un número")
        return v


@router.post(
    "/change-password",
    response_model=MessageResponse,
    summary="Cambiar contraseña",
    description="""
Permite al usuario cambiar su contraseña verificando la actual primero.
Útil para empleados que recibieron una contraseña temporal via `/auth/invite`.

**Requiere:** `Authorization: Bearer <access_token>`
    """,
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)  # 🚦 5 cambios por hora
def change_password(
    request: Request,
    data: ChangePasswordRequest,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[Client, Depends(get_supabase)],
    db_admin: Annotated[Client, Depends(get_supabase_admin)],
) -> dict:
    email = current_user.get("email")

    # 1. Verificar que la contraseña actual es correcta
    try:
        db.auth.sign_in_with_password({"email": email, "password": data.current_password})
    except Exception:
        logger.warning("Change-password fallido (contraseña incorrecta) | email={email}", email=email)
        raise BadRequestException("La contraseña actual es incorrecta")

    # 2. Verificar que la nueva contraseña es distinta a la actual
    if data.current_password == data.new_password:
        raise BadRequestException("La nueva contraseña debe ser diferente a la actual")

    # 3. Actualizar en Supabase Auth
    try:
        db_admin.auth.admin.update_user_by_id(
            str(current_user["id"]),
            {"password": data.new_password},
        )
    except Exception as e:
        logger.error("Error cambiando contraseña | email={email} | error={error}", email=email, error=str(e))
        raise BadRequestException(f"No se pudo cambiar la contraseña: {str(e)}")

    logger.info("Contraseña cambiada | email={email}", email=email)
    return {"message": "Contraseña actualizada correctamente"}