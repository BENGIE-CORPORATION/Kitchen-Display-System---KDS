from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from ..models.lote_inventario import ESTADOS_VALIDOS


class LoteInventarioBase(BaseModel):
    sucursal_id: UUID
    numero_lote: Annotated[str, Field(min_length=1, max_length=100)]
    cantidad_inicial: Annotated[Decimal, Field(gt=0, decimal_places=3)]
    costo_unitario: Annotated[Decimal, Field(ge=0, decimal_places=4)]
    fecha_vencimiento: datetime | None = None
    proveedor_id: UUID | None = None
    materia_prima_id: UUID | None = None
    producto_id: UUID | None = None

    @model_validator(mode="after")
    def validate_referencia(self) -> "LoteInventarioBase":
        if not self.materia_prima_id and not self.producto_id:
            raise ValueError("Debe especificar materia_prima_id o producto_id")
        if self.materia_prima_id and self.producto_id:
            raise ValueError("Solo puede especificar materia_prima_id o producto_id, no ambos")
        return self


class LoteInventarioRead(LoteInventarioBase):
    id: UUID
    cantidad_actual: Decimal
    fecha_ingreso: datetime | None
    estado: str
    created_at: datetime | None


class LoteInventarioCreate(LoteInventarioBase):
    model_config = ConfigDict(extra="forbid")


class LoteInventarioCreateInternal(LoteInventarioCreate):
    cantidad_actual: Decimal | None = None   # se inicializa igual a cantidad_inicial


class LoteInventarioUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cantidad_actual: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    costo_unitario: Annotated[Decimal | None, Field(ge=0, decimal_places=4, default=None)]
    fecha_vencimiento: datetime | None = None
    estado: str | None = None

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str | None) -> str | None:
        if v and v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v