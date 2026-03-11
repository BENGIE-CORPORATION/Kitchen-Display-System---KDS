from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


# ─── Base ─────────────────────────────────────────────────────────────────────

class ComboBase(BaseModel):
    producto_componente_id: UUID
    cantidad: Annotated[Decimal, Field(gt=0, decimal_places=3, default=Decimal("1"))]
    es_opcional: bool = False


# ─── Read ─────────────────────────────────────────────────────────────────────

class ComboRead(ComboBase):
    id: UUID
    producto_id: UUID
    created_at: datetime | None


class ComboReadDetalle(ComboRead):
    """Incluye datos del producto componente para respuestas enriquecidas."""
    componente: dict | None = None


# ─── Create ───────────────────────────────────────────────────────────────────

class ComboCreate(ComboBase):
    model_config = ConfigDict(extra="forbid")

    @field_validator("cantidad")
    @classmethod
    def validate_cantidad(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("La cantidad debe ser mayor a 0")
        return v


# ─── Update ───────────────────────────────────────────────────────────────────

class ComboUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cantidad: Annotated[Decimal | None, Field(gt=0, decimal_places=3, default=None)]
    es_opcional: bool | None = None

    @field_validator("cantidad")
    @classmethod
    def validate_cantidad(cls, v: Decimal | None) -> Decimal | None:
        if v is not None and v <= 0:
            raise ValueError("La cantidad debe ser mayor a 0")
        return v