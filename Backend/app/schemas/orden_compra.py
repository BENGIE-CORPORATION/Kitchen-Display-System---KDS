from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.orden_compra import CONDICIONES_PAGO, ESTADOS_VALIDOS


# ─── Detalle ──────────────────────────────────────────────────────────────────

class DetalleOrdenBase(BaseModel):
    materia_prima_id: UUID | None = None
    producto_id: UUID | None = None
    cantidad_solicitada: Annotated[Decimal, Field(gt=0, decimal_places=3)]
    unidad_medida: Annotated[str, Field(min_length=1, max_length=30)]
    precio_unitario: Annotated[Decimal, Field(ge=0, decimal_places=4)]
    descuento_porcentaje: Annotated[Decimal, Field(ge=0, le=100, decimal_places=2, default=Decimal("0"))]
    descuento_monto: Annotated[Decimal, Field(ge=0, decimal_places=2, default=Decimal("0"))]
    impuesto_porcentaje: Annotated[Decimal, Field(ge=0, le=100, decimal_places=2, default=Decimal("0"))]
    impuesto_monto: Annotated[Decimal, Field(ge=0, decimal_places=2, default=Decimal("0"))]
    subtotal: Annotated[Decimal, Field(ge=0, decimal_places=2)]
    total: Annotated[Decimal, Field(ge=0, decimal_places=2)]
    notas: Annotated[str | None, Field(default=None)]

    @model_validator(mode="after")
    def validate_item_referencia(self) -> "DetalleOrdenBase":
        if not self.materia_prima_id and not self.producto_id:
            raise ValueError("Debe especificar materia_prima_id o producto_id")
        if self.materia_prima_id and self.producto_id:
            raise ValueError("Solo puede especificar materia_prima_id o producto_id, no ambos")
        return self

    @field_validator("unidad_medida")
    @classmethod
    def clean_unidad(cls, v: str) -> str:
        return sanitize_strict(v)

    @field_validator("notas")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class DetalleOrdenRead(DetalleOrdenBase):
    id: UUID
    orden_compra_id: UUID
    cantidad_recibida: Decimal
    created_at: datetime | None


class DetalleOrdenCreate(DetalleOrdenBase):
    model_config = ConfigDict(extra="forbid")


class DetalleOrdenUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cantidad_solicitada: Annotated[Decimal | None, Field(gt=0, decimal_places=3, default=None)]
    precio_unitario: Annotated[Decimal | None, Field(ge=0, decimal_places=4, default=None)]
    descuento_porcentaje: Annotated[Decimal | None, Field(ge=0, le=100, decimal_places=2, default=None)]
    descuento_monto: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    impuesto_porcentaje: Annotated[Decimal | None, Field(ge=0, le=100, decimal_places=2, default=None)]
    impuesto_monto: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    subtotal: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    total: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    notas: str | None = None


class DetalleOrdenRecepcion(BaseModel):
    """Schema para registrar recepción parcial o total de un ítem."""
    model_config = ConfigDict(extra="forbid")

    cantidad_recibida: Annotated[Decimal, Field(gt=0, decimal_places=3)]


# ─── Orden Compra ─────────────────────────────────────────────────────────────

class OrdenCompraBase(BaseModel):
    sucursal_id: UUID
    proveedor_id: UUID
    numero_orden: Annotated[str, Field(min_length=1, max_length=50)]
    fecha_entrega_esperada: datetime | None = None
    condicion_pago: Annotated[str | None, Field(default=None)]
    notas: Annotated[str | None, Field(default=None)]

    @field_validator("numero_orden")
    @classmethod
    def clean_numero(cls, v: str) -> str:
        return sanitize_strict(v).upper()

    @field_validator("condicion_pago")
    @classmethod
    def validate_condicion(cls, v: str | None) -> str | None:
        if v and v not in CONDICIONES_PAGO:
            raise ValueError(f"Condición de pago inválida. Opciones: {', '.join(CONDICIONES_PAGO)}")
        return v

    @field_validator("notas")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class OrdenCompraRead(OrdenCompraBase):
    id: UUID
    empresa_id: UUID
    fecha_orden: datetime | None
    fecha_entrega_real: datetime | None
    subtotal: Decimal
    impuestos: Decimal
    descuentos: Decimal
    total: Decimal
    estado: str
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID
    updated_by: UUID | None


class OrdenCompraReadDetalle(OrdenCompraRead):
    """Orden con sus líneas de detalle."""
    items: list[DetalleOrdenRead] = []


class OrdenCompraCreate(OrdenCompraBase):
    model_config = ConfigDict(extra="forbid")

    empresa_id: UUID
    items: Annotated[list[DetalleOrdenCreate], Field(min_length=1)]


class OrdenCompraUpdate(BaseModel):
    """Solo editable en estado borrador."""
    model_config = ConfigDict(extra="forbid")

    numero_orden: Annotated[str | None, Field(min_length=1, max_length=50, default=None)]
    fecha_entrega_esperada: datetime | None = None
    condicion_pago: str | None = None
    notas: str | None = None

    @field_validator("numero_orden")
    @classmethod
    def clean_numero(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("condicion_pago")
    @classmethod
    def validate_condicion(cls, v: str | None) -> str | None:
        if v and v not in CONDICIONES_PAGO:
            raise ValueError(f"Condición de pago inválida. Opciones: {', '.join(CONDICIONES_PAGO)}")
        return v


class OrdenCompraEstadoUpdate(BaseModel):
    """Cambio explícito de estado con validación de transición."""
    model_config = ConfigDict(extra="forbid")

    estado: str
    fecha_entrega_real: datetime | None = None  # requerido al pasar a 'recibida'
    notas: str | None = None

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        if v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v