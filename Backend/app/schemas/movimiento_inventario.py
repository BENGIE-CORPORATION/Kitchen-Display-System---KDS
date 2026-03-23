from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.movimiento_inventario import (
    ESTADOS_VALIDOS,
    TIPOS_MOVIMIENTO,
    TIPOS_REQUIEREN_MOTIVO,
    TIPOS_TRANSFERENCIA,
)


# ─── Detalle ──────────────────────────────────────────────────────────────────

class DetalleMovimientoBase(BaseModel):
    materia_prima_id: UUID | None = None
    producto_id: UUID | None = None
    lote_id: UUID | None = None
    cantidad: Annotated[Decimal, Field(gt=0, decimal_places=3)]
    unidad_medida: Annotated[str, Field(min_length=1, max_length=30)]
    costo_unitario: Annotated[Decimal | None, Field(ge=0, decimal_places=4, default=None)]
    costo_total: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    stock_anterior: Annotated[Decimal, Field(ge=0, decimal_places=3)]
    stock_nuevo: Annotated[Decimal, Field(ge=0, decimal_places=3)]
    notas: Annotated[str | None, Field(default=None)]

    @model_validator(mode="after")
    def validate_referencia(self) -> "DetalleMovimientoBase":
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


class DetalleMovimientoRead(DetalleMovimientoBase):
    id: UUID
    movimiento_id: UUID
    created_at: datetime | None


class DetalleMovimientoCreate(DetalleMovimientoBase):
    model_config = ConfigDict(extra="forbid")


# ─── Movimiento ───────────────────────────────────────────────────────────────

class MovimientoInventarioBase(BaseModel):
    tipo_movimiento: Annotated[str, Field(examples=list(TIPOS_MOVIMIENTO))]
    numero_movimiento: Annotated[str, Field(min_length=1, max_length=50)]
    fecha_movimiento: datetime | None = None
    sucursal_origen_id: UUID | None = None
    sucursal_destino_id: UUID | None = None
    proveedor_id: UUID | None = None
    orden_compra_id: UUID | None = None
    pedido_id: UUID | None = None
    motivo: Annotated[str | None, Field(default=None)]
    numero_factura: Annotated[str | None, Field(max_length=100, default=None)]
    documento_url: Annotated[str | None, Field(max_length=2048, default=None)]

    @field_validator("tipo_movimiento")
    @classmethod
    def validate_tipo(cls, v: str) -> str:
        if v not in TIPOS_MOVIMIENTO:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(sorted(TIPOS_MOVIMIENTO))}")
        return v

    @field_validator("numero_movimiento")
    @classmethod
    def clean_numero(cls, v: str) -> str:
        return sanitize_strict(v).upper()

    @field_validator("numero_factura")
    @classmethod
    def clean_factura(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("motivo")
    @classmethod
    def clean_motivo(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @model_validator(mode="after")
    def validate_reglas_negocio(self) -> "MovimientoInventarioBase":
        # Motivo obligatorio para ajustes y mermas
        if self.tipo_movimiento in TIPOS_REQUIEREN_MOTIVO and not self.motivo:
            raise ValueError(
                f"El campo 'motivo' es obligatorio para tipo '{self.tipo_movimiento}'"
            )
        # Transferencias requieren sucursal origen y destino
        if self.tipo_movimiento in TIPOS_TRANSFERENCIA:
            if not self.sucursal_origen_id or not self.sucursal_destino_id:
                raise ValueError(
                    "Las transferencias requieren 'sucursal_origen_id' y 'sucursal_destino_id'"
                )
            if self.sucursal_origen_id == self.sucursal_destino_id:
                raise ValueError(
                    "La sucursal origen y destino no pueden ser la misma"
                )
        return self


class MovimientoInventarioRead(MovimientoInventarioBase):
    id: UUID
    empresa_id: UUID
    sucursal_id: UUID
    usuario_responsable: UUID
    total_costo: Decimal
    estado: str
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID


class MovimientoInventarioReadDetalle(MovimientoInventarioRead):
    items: list[DetalleMovimientoRead] = []


class MovimientoInventarioCreate(MovimientoInventarioBase):
    model_config = ConfigDict(extra="forbid")

    empresa_id: UUID
    sucursal_id: UUID
    items: Annotated[list[DetalleMovimientoCreate], Field(min_length=1)]


class MovimientoInventarioUpdate(BaseModel):
    """Solo editable en estado borrador."""
    model_config = ConfigDict(extra="forbid")

    motivo: str | None = None
    numero_factura: Annotated[str | None, Field(max_length=100, default=None)]
    documento_url: Annotated[str | None, Field(max_length=2048, default=None)]
    notas: str | None = None

    @field_validator("numero_factura")
    @classmethod
    def clean_factura(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("motivo", "notas")
    @classmethod
    def clean_text(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class MovimientoEstadoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    estado: str

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        permitidos = {"completado", "cancelado"}
        if v not in permitidos:
            raise ValueError(f"Solo se puede cambiar a: {', '.join(permitidos)}")
        return v