from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.metodo_pago import TIPOS_METODO_PAGO


# ─── MetodoPago ───────────────────────────────────────────────────────────────

class MetodoPagoBase(BaseModel):
    nombre: Annotated[str, Field(min_length=1, max_length=100)]
    codigo: Annotated[str, Field(min_length=1, max_length=50)]
    tipo: Annotated[str, Field(examples=list(TIPOS_METODO_PAGO))]
    requiere_referencia: bool = False
    requiere_tarjeta: bool = False
    permite_vuelto: bool = False
    comision_porcentaje: Annotated[
        Decimal, Field(ge=0, lt=1, decimal_places=4, default=Decimal("0"))
    ]
    instrucciones: Annotated[str | None, Field(default=None)]

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str) -> str:
        return sanitize_text(v)

    @field_validator("codigo")
    @classmethod
    def clean_codigo(cls, v: str) -> str:
        return sanitize_strict(v).lower()

    @field_validator("tipo")
    @classmethod
    def validate_tipo(cls, v: str) -> str:
        if v not in TIPOS_METODO_PAGO:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(sorted(TIPOS_METODO_PAGO))}")
        return v

    @field_validator("instrucciones")
    @classmethod
    def clean_instrucciones(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class MetodoPagoRead(MetodoPagoBase):
    id: UUID
    empresa_id: UUID
    is_active: bool
    created_at: datetime | None
    updated_at: datetime | None


class MetodoPagoCreate(MetodoPagoBase):
    model_config = ConfigDict(extra="forbid")

    empresa_id: UUID


class MetodoPagoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre: Annotated[str | None, Field(min_length=1, max_length=100, default=None)]
    tipo: str | None = None
    requiere_referencia: bool | None = None
    requiere_tarjeta: bool | None = None
    permite_vuelto: bool | None = None
    comision_porcentaje: Annotated[
        Decimal | None, Field(ge=0, lt=1, decimal_places=4, default=None)
    ]
    instrucciones: str | None = None

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("tipo")
    @classmethod
    def validate_tipo(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_METODO_PAGO:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(sorted(TIPOS_METODO_PAGO))}")
        return v

    @field_validator("instrucciones")
    @classmethod
    def clean_instrucciones(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None
