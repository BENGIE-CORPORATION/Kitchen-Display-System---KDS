from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..core.sanitizer import sanitize_strict


# ─── Base ─────────────────────────────────────────────────────────────────────

class VarianteProductoBase(BaseModel):
    nombre: Annotated[str, Field(min_length=1, max_length=100, examples=["Tamaño", "Color"])]
    opciones: Annotated[list[str], Field(min_length=1, examples=[["Pequeño", "Mediano", "Grande"]])]
    orden: Annotated[int, Field(default=0, ge=0)]

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str) -> str:
        return sanitize_strict(v)

    @field_validator("opciones")
    @classmethod
    def clean_opciones(cls, v: list[str]) -> list[str]:
        if not v:
            raise ValueError("Debe tener al menos una opción")
        cleaned = [sanitize_strict(op) for op in v if op.strip()]
        if not cleaned:
            raise ValueError("Las opciones no pueden estar vacías")
        if len(cleaned) != len(set(cleaned)):
            raise ValueError("Las opciones no pueden repetirse")
        return cleaned


# ─── Read ─────────────────────────────────────────────────────────────────────

class VarianteProductoRead(VarianteProductoBase):
    id: UUID
    producto_id: UUID
    created_at: datetime | None


# ─── Create ───────────────────────────────────────────────────────────────────

class VarianteProductoCreate(VarianteProductoBase):
    model_config = ConfigDict(extra="forbid")


# ─── Update ───────────────────────────────────────────────────────────────────

class VarianteProductoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre: Annotated[str | None, Field(min_length=1, max_length=100, default=None)]
    opciones: Annotated[list[str] | None, Field(min_length=1, default=None)]
    orden: Annotated[int | None, Field(ge=0, default=None)]

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("opciones")
    @classmethod
    def clean_opciones(cls, v: list[str] | None) -> list[str] | None:
        if v is None:
            return None
        if not v:
            raise ValueError("Debe tener al menos una opción")
        cleaned = [sanitize_strict(op) for op in v if op.strip()]
        if not cleaned:
            raise ValueError("Las opciones no pueden estar vacías")
        if len(cleaned) != len(set(cleaned)):
            raise ValueError("Las opciones no pueden repetirse")
        return cleaned