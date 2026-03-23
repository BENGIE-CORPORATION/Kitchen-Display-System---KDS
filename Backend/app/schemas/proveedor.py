from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.proveedor import (
    CONDICIONES_PAGO,
    ESTADOS_VALIDOS,
    TIPOS_IDENTIFICACION,
    TIPOS_PROVEEDOR,
)


# ─── Base ─────────────────────────────────────────────────────────────────────

class ProveedorBase(BaseModel):
    identificacion: Annotated[str, Field(min_length=2, max_length=100)]
    nombre_legal: Annotated[str, Field(min_length=2, max_length=255)]
    codigo: Annotated[str | None, Field(max_length=50, default=None)]
    tipo_identificacion: Annotated[str | None, Field(default=None)]
    nombre_comercial: Annotated[str | None, Field(max_length=255, default=None)]
    tipo_proveedor: Annotated[str | None, Field(default=None)]
    email: Annotated[EmailStr | None, Field(default=None)]
    telefono: Annotated[str | None, Field(max_length=50, default=None)]
    telefono_alternativo: Annotated[str | None, Field(max_length=50, default=None)]
    direccion: Annotated[str | None, Field(default=None)]
    ciudad: Annotated[str | None, Field(max_length=100, default=None)]
    pais: Annotated[str | None, Field(min_length=2, max_length=2, default=None)]
    sitio_web: Annotated[str | None, Field(max_length=255, default=None)]
    persona_contacto: Annotated[str | None, Field(max_length=255, default=None)]
    cargo_contacto: Annotated[str | None, Field(max_length=100, default=None)]
    email_contacto: Annotated[EmailStr | None, Field(default=None)]
    telefono_contacto: Annotated[str | None, Field(max_length=50, default=None)]
    condicion_pago: Annotated[str, Field(default="contado")]
    limite_credito: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    cuenta_bancaria: Annotated[str | None, Field(max_length=100, default=None)]
    notas: Annotated[str | None, Field(default=None)]
    calificacion: Annotated[int | None, Field(ge=1, le=5, default=None)]

    @field_validator("nombre_legal", "nombre_comercial", "persona_contacto",
                     "cargo_contacto", "ciudad")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("identificacion", "codigo")
    @classmethod
    def clean_upper(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("direccion", "notas")
    @classmethod
    def clean_text(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("tipo_identificacion")
    @classmethod
    def validate_tipo_identificacion(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_IDENTIFICACION:
            raise ValueError(f"Tipo identificación inválido. Opciones: {', '.join(TIPOS_IDENTIFICACION)}")
        return v

    @field_validator("tipo_proveedor")
    @classmethod
    def validate_tipo_proveedor(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_PROVEEDOR:
            raise ValueError(f"Tipo proveedor inválido. Opciones: {', '.join(TIPOS_PROVEEDOR)}")
        return v

    @field_validator("condicion_pago")
    @classmethod
    def validate_condicion_pago(cls, v: str) -> str:
        if v not in CONDICIONES_PAGO:
            raise ValueError(f"Condición de pago inválida. Opciones: {', '.join(CONDICIONES_PAGO)}")
        return v


# ─── Read ─────────────────────────────────────────────────────────────────────

class ProveedorRead(ProveedorBase):
    id: UUID
    empresa_id: UUID
    estado: str
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID | None
    updated_by: UUID | None


# ─── Create ───────────────────────────────────────────────────────────────────

class ProveedorCreate(ProveedorBase):
    model_config = ConfigDict(extra="forbid")

    empresa_id: UUID
    estado: Annotated[str, Field(default="activo")]

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        if v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v


# ─── CreateInternal ───────────────────────────────────────────────────────────

class ProveedorCreateInternal(ProveedorCreate):
    created_by: UUID | None = None


# ─── Update ───────────────────────────────────────────────────────────────────

class ProveedorUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre_legal: Annotated[str | None, Field(min_length=2, max_length=255, default=None)]
    nombre_comercial: Annotated[str | None, Field(max_length=255, default=None)]
    codigo: Annotated[str | None, Field(max_length=50, default=None)]
    tipo_identificacion: str | None = None
    tipo_proveedor: str | None = None
    email: Annotated[EmailStr | None, Field(default=None)]
    telefono: Annotated[str | None, Field(max_length=50, default=None)]
    telefono_alternativo: Annotated[str | None, Field(max_length=50, default=None)]
    direccion: str | None = None
    ciudad: Annotated[str | None, Field(max_length=100, default=None)]
    pais: Annotated[str | None, Field(min_length=2, max_length=2, default=None)]
    sitio_web: Annotated[str | None, Field(max_length=255, default=None)]
    persona_contacto: Annotated[str | None, Field(max_length=255, default=None)]
    cargo_contacto: Annotated[str | None, Field(max_length=100, default=None)]
    email_contacto: Annotated[EmailStr | None, Field(default=None)]
    telefono_contacto: Annotated[str | None, Field(max_length=50, default=None)]
    condicion_pago: str | None = None
    limite_credito: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    cuenta_bancaria: Annotated[str | None, Field(max_length=100, default=None)]
    notas: str | None = None
    calificacion: Annotated[int | None, Field(ge=1, le=5, default=None)]
    estado: str | None = None

    @field_validator("nombre_legal", "nombre_comercial", "persona_contacto",
                     "cargo_contacto", "ciudad")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("codigo")
    @classmethod
    def clean_upper(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("direccion", "notas")
    @classmethod
    def clean_text(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("tipo_identificacion")
    @classmethod
    def validate_tipo_identificacion(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_IDENTIFICACION:
            raise ValueError(f"Tipo identificación inválido. Opciones: {', '.join(TIPOS_IDENTIFICACION)}")
        return v

    @field_validator("tipo_proveedor")
    @classmethod
    def validate_tipo_proveedor(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_PROVEEDOR:
            raise ValueError(f"Tipo proveedor inválido. Opciones: {', '.join(TIPOS_PROVEEDOR)}")
        return v

    @field_validator("condicion_pago")
    @classmethod
    def validate_condicion_pago(cls, v: str | None) -> str | None:
        if v and v not in CONDICIONES_PAGO:
            raise ValueError(f"Condición de pago inválida. Opciones: {', '.join(CONDICIONES_PAGO)}")
        return v

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str | None) -> str | None:
        if v and v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v


# ─── UpdateInternal ───────────────────────────────────────────────────────────

class ProveedorUpdateInternal(ProveedorUpdate):
    updated_at: datetime
    updated_by: UUID | None = None