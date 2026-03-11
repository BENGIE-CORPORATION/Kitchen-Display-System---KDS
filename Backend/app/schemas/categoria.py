from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.categoria import ESTADOS_VALIDOS, TIPOS_VALIDOS


# ─── Base ─────────────────────────────────────────────────────────────────────

class CategoriaBase(BaseModel):
    nombre: Annotated[str, Field(min_length=1, max_length=255)]
    tipo: Annotated[str, Field(examples=["alimento", "bebida", "producto", "servicio"])]
    codigo: Annotated[str | None, Field(max_length=50, default=None)]
    categoria_padre_id: UUID | None = None
    descripcion: Annotated[str | None, Field(default=None)]
    imagen_url: Annotated[str | None, Field(max_length=2048, default=None)]
    orden: Annotated[int, Field(default=0, ge=0)]

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str) -> str:
        return sanitize_strict(v)

    @field_validator("codigo")
    @classmethod
    def clean_codigo(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("descripcion")
    @classmethod
    def clean_descripcion(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("tipo")
    @classmethod
    def validate_tipo(cls, v: str) -> str:
        if v not in TIPOS_VALIDOS:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(TIPOS_VALIDOS)}")
        return v


# ─── Read ─────────────────────────────────────────────────────────────────────

class CategoriaRead(CategoriaBase):
    id: UUID
    empresa_id: UUID
    estado: str
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID | None
    updated_by: UUID | None


# ─── Create ───────────────────────────────────────────────────────────────────

class CategoriaCreate(CategoriaBase):
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

class CategoriaCreateInternal(CategoriaCreate):
    created_by: UUID | None = None


# ─── Update ───────────────────────────────────────────────────────────────────

class CategoriaUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre: Annotated[str | None, Field(min_length=1, max_length=255, default=None)]
    tipo: str | None = None
    codigo: Annotated[str | None, Field(max_length=50, default=None)]
    categoria_padre_id: UUID | None = None
    descripcion: str | None = None
    imagen_url: Annotated[str | None, Field(max_length=2048, default=None)]
    orden: Annotated[int | None, Field(ge=0, default=None)]
    estado: str | None = None

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("codigo")
    @classmethod
    def clean_codigo(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("descripcion")
    @classmethod
    def clean_descripcion(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("tipo")
    @classmethod
    def validate_tipo(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_VALIDOS:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(TIPOS_VALIDOS)}")
        return v

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str | None) -> str | None:
        if v and v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v


# ─── UpdateInternal ───────────────────────────────────────────────────────────

class CategoriaUpdateInternal(CategoriaUpdate):
    updated_at: datetime
    updated_by: UUID | None = None