from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from typing import Annotated


# ─── Requests del cliente ─────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: Annotated[EmailStr, Field(examples=["admin@empresa.com"])]
    password: Annotated[str, Field(min_length=8, examples=["MiPassword123!"])]


class RegisterRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: Annotated[EmailStr, Field(examples=["admin@empresa.com"])]
    password: Annotated[str, Field(min_length=8, examples=["MiPassword123!"])]
    nombre_completo: Annotated[str, Field(min_length=2, max_length=255, examples=["Juan Pérez"])]
    empresa_id: Annotated[str, Field(description="UUID de la empresa a la que pertenece")]

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        if not any(c.islower() for c in v):
            raise ValueError("La contraseña debe tener al menos una letra minúscula")
        if not any(c.isupper() for c in v):
            raise ValueError("La contraseña debe tener al menos una letra mayúscula")
        if not any(c.isdigit() for c in v):
            raise ValueError("La contraseña debe tener al menos un número")
        return v


class InviteEmpleadoRequest(BaseModel):
    """
    El admin invita a un empleado. Supabase le envía el email de invitación.
    """
    model_config = ConfigDict(extra="forbid")

    email: Annotated[EmailStr, Field(examples=["empleado@empresa.com"])]
    nombre_completo: Annotated[str, Field(min_length=2, max_length=255)]
    empresa_id: Annotated[str, Field(description="UUID de la empresa")]
    sucursal_id: Annotated[str, Field(description="UUID de la sucursal asignada")]
    rol_sucursal: Annotated[
        str,
        Field(
            pattern=r"^(administrador|cajero|mesero|cocinero|bodeguero|vendedor)$",
            examples=["cajero"],
        ),
    ]


class RefreshTokenRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    refresh_token: str


# ─── Responses al cliente ─────────────────────────────────────────────────────

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class MessageResponse(BaseModel):
    message: str