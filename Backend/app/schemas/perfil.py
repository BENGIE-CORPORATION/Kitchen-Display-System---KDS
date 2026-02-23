from datetime import datetime
from typing import Annotated, Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


# ─── Roles válidos ────────────────────────────────────────────────────────────

RolGlobal = Annotated[
    str,
    Field(
        pattern=r"^(super_admin|admin_empresa|empleado)$",
        examples=["admin_empresa"],
    ),
]

EstadoPerfil = Annotated[
    str,
    Field(pattern=r"^(activo|inactivo|suspendido)$", examples=["activo"]),
]


# ─── Read (lo que se retorna al cliente) ──────────────────────────────────────

class PerfilRead(BaseModel):
    id: UUID                          # mismo UUID que auth.users
    empresa_id: UUID
    nombre_completo: str
    email: str
    telefono: str | None
    avatar_url: str | None
    rol_global: str
    estado: str
    configuracion: dict[str, Any] | None
    ultimo_acceso: datetime | None
    created_at: datetime | None
    updated_at: datetime | None


# ─── Read público (menos campos — para listar empleados) ──────────────────────

class PerfilPublicRead(BaseModel):
    id: UUID
    nombre_completo: str
    email: str
    avatar_url: str | None
    rol_global: str
    estado: str


# ─── Create interno (lo que tu backend guarda en Supabase) ───────────────────

class PerfilCreateInternal(BaseModel):
    """
    Se crea automáticamente después de que Supabase Auth registra al usuario.
    El `id` viene del UUID de auth.users — no lo genera el cliente.
    """
    id: UUID                          # UUID de auth.users
    empresa_id: UUID
    nombre_completo: Annotated[str, Field(min_length=2, max_length=255)]
    email: EmailStr
    telefono: str | None = None
    avatar_url: str | None = None
    rol_global: RolGlobal = "admin_empresa"
    estado: EstadoPerfil = "activo"
    configuracion: dict[str, Any] | None = None
    created_by: UUID | None = None


# ─── Update (PATCH — todos opcionales) ───────────────────────────────────────

class PerfilUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre_completo: Annotated[str | None, Field(min_length=2, max_length=255, default=None)]
    telefono: Annotated[str | None, Field(max_length=50, default=None)]
    avatar_url: Annotated[
        str | None,
        Field(pattern=r"^(https?|ftp)://[^\s/$.?#].[^\s]*$", default=None),
    ]
    configuracion: dict[str, Any] | None = None


# ─── Update interno (incluye campos que el cliente no puede tocar) ────────────

class PerfilUpdateInternal(PerfilUpdate):
    updated_at: datetime
    ultimo_acceso: datetime | None = None
    estado: str | None = None
    rol_global: str | None = None    # solo super_admin puede cambiar esto


# ─── Respuesta del /me con contexto completo ─────────────────────────────────

class MeResponse(BaseModel):
    """Perfil completo del usuario autenticado + sus accesos a sucursales."""
    perfil: PerfilRead
    sucursales: list[dict[str, Any]] = []   # sus asignaciones en usuarios_sucursales