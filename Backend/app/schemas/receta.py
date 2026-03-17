from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.materia_prima import UNIDADES_MEDIDA


class RecetaBase(BaseModel):
    materia_prima_id: UUID
    cantidad: Annotated[Decimal, Field(gt=0, decimal_places=4)]
    unidad_medida: Annotated[str, Field(examples=list(UNIDADES_MEDIDA))]
    notas: Annotated[str | None, Field(default=None)]

    @field_validator("unidad_medida")
    @classmethod
    def validate_unidad(cls, v: str) -> str:
        if v not in UNIDADES_MEDIDA:
            raise ValueError(f"Unidad inválida. Opciones: {', '.join(sorted(UNIDADES_MEDIDA))}")
        return v

    @field_validator("notas")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class RecetaRead(RecetaBase):
    id: UUID
    producto_id: UUID
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID | None


class RecetaReadDetalle(RecetaRead):
    """Incluye datos básicos de la materia prima para respuestas enriquecidas."""
    materia_prima: dict | None = None


class RecetaCreate(RecetaBase):
    model_config = ConfigDict(extra="forbid")


class RecetaUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cantidad: Annotated[Decimal | None, Field(gt=0, decimal_places=4, default=None)]
    unidad_medida: str | None = None
    notas: str | None = None

    @field_validator("unidad_medida")
    @classmethod
    def validate_unidad(cls, v: str | None) -> str | None:
        if v and v not in UNIDADES_MEDIDA:
            raise ValueError(f"Unidad inválida. Opciones: {', '.join(sorted(UNIDADES_MEDIDA))}")
        return v

    @field_validator("notas")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None