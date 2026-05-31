from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.mesa import ESTADOS_MESA


# ─── Mesa ─────────────────────────────────────────────────────────────────────

class MesaBase(BaseModel):
    numero: Annotated[str, Field(min_length=1, max_length=20)]
    nombre: Annotated[str | None, Field(max_length=100, default=None)]
    capacidad: Annotated[int, Field(ge=1, default=2)]
    zona: Annotated[str | None, Field(max_length=100, default=None)]
    notas: Annotated[str | None, Field(default=None)]

    @field_validator("numero")
    @classmethod
    def clean_numero(cls, v: str) -> str:
        return sanitize_strict(v).upper()

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("zona")
    @classmethod
    def clean_zona(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("notas")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class MesaRead(MesaBase):
    id: UUID
    empresa_id: UUID
    sucursal_id: UUID
    estado: str
    is_active: bool
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID | None = None
    updated_by: UUID | None = None


class MesaCreate(MesaBase):
    model_config = ConfigDict(extra="forbid")

    empresa_id: UUID
    sucursal_id: UUID


class MesaUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre: Annotated[str | None, Field(max_length=100, default=None)]
    capacidad: Annotated[int | None, Field(ge=1, default=None)]
    zona: Annotated[str | None, Field(max_length=100, default=None)]
    notas: Annotated[str | None, Field(default=None)]

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("zona")
    @classmethod
    def clean_zona(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("notas")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class MesaEstadoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    estado: str

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        if v not in ESTADOS_MESA:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(sorted(ESTADOS_MESA))}")
        return v
