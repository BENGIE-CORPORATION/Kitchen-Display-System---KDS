from datetime import datetime
from decimal import Decimal
from typing import Annotated, Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.pedido import (
    CANALES_VENTA,
    ESTADOS_COCINA,
    ESTADOS_DETALLE,
    ESTADOS_PAGO,
    ESTADOS_PEDIDO,
    PRIORIDADES,
    TIPOS_PEDIDO,
    TIPOS_VENTA,
)


# ─── Detalle ──────────────────────────────────────────────────────────────────

class DetallePedidoBase(BaseModel):
    producto_id: UUID
    cantidad: Annotated[Decimal, Field(gt=0, decimal_places=3)]
    unidad_medida: Annotated[str, Field(default="unidad", max_length=30)]
    precio_unitario: Annotated[Decimal, Field(ge=0, decimal_places=2)]
    descuento_porcentaje: Annotated[Decimal, Field(ge=0, le=100, decimal_places=2, default=Decimal("0"))]
    descuento_monto: Annotated[Decimal, Field(ge=0, decimal_places=2, default=Decimal("0"))]
    subtotal: Annotated[Decimal, Field(ge=0, decimal_places=2)]
    iva: Annotated[Decimal, Field(ge=0, decimal_places=2, default=Decimal("0"))]
    servicio: Annotated[Decimal, Field(ge=0, decimal_places=2, default=Decimal("0"))]
    total: Annotated[Decimal, Field(ge=0, decimal_places=2)]
    costo_unitario: Annotated[Decimal | None, Field(ge=0, decimal_places=4, default=None)]
    lote_id: UUID | None = None
    variantes_seleccionadas: dict[str, Any] | None = None
    notas: Annotated[str | None, Field(default=None)]

    @field_validator("notas")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class DetallePedidoRead(DetallePedidoBase):
    id: UUID
    pedido_id: UUID
    costo_total: Decimal | None
    utilidad: Decimal | None
    estado: str
    motivo_cancelacion: str | None
    fecha_cancelacion: datetime | None
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID | None
    updated_by: UUID | None
    cancelado_por: UUID | None


class DetallePedidoCreate(DetallePedidoBase):
    model_config = ConfigDict(extra="forbid")


class DetallePedidoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cantidad: Annotated[Decimal | None, Field(gt=0, decimal_places=3, default=None)]
    precio_unitario: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    descuento_porcentaje: Annotated[Decimal | None, Field(ge=0, le=100, decimal_places=2, default=None)]
    descuento_monto: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    subtotal: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    iva: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    servicio: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    total: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    variantes_seleccionadas: dict[str, Any] | None = None
    notas: str | None = None

    @field_validator("notas")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class DetalleCancelacion(BaseModel):
    model_config = ConfigDict(extra="forbid")
    motivo_cancelacion: Annotated[str, Field(min_length=1, max_length=500)]


# ─── Pedido ───────────────────────────────────────────────────────────────────

class PedidoBase(BaseModel):
    sucursal_id: UUID
    numero_pedido: Annotated[str, Field(min_length=1, max_length=50)]
    tipo_pedido: Annotated[str, Field(examples=list(TIPOS_PEDIDO))]
    tipo_venta: Annotated[str, Field(default="contado")]
    canal_venta: Annotated[str, Field(default="presencial")]
    mesa_id: UUID | None = None
    cliente_id: UUID | None = None
    nombre_cliente: Annotated[str | None, Field(max_length=255, default=None)]
    telefono_cliente: Annotated[str | None, Field(max_length=50, default=None)]
    direccion_entrega: Annotated[str | None, Field(default=None)]
    cantidad_comensales: Annotated[int | None, Field(ge=1, default=None)]
    mesero_id: UUID | None = None
    prioridad: Annotated[str, Field(default="normal")]
    tiempo_estimado_minutos: Annotated[int | None, Field(ge=1, default=None)]

    @field_validator("numero_pedido", "nombre_cliente")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("direccion_entrega")
    @classmethod
    def clean_text(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("tipo_pedido")
    @classmethod
    def validate_tipo_pedido(cls, v: str) -> str:
        if v not in TIPOS_PEDIDO:
            raise ValueError(f"Tipo pedido inválido. Opciones: {', '.join(TIPOS_PEDIDO)}")
        return v

    @field_validator("tipo_venta")
    @classmethod
    def validate_tipo_venta(cls, v: str) -> str:
        if v not in TIPOS_VENTA:
            raise ValueError(f"Tipo venta inválido. Opciones: {', '.join(TIPOS_VENTA)}")
        return v

    @field_validator("canal_venta")
    @classmethod
    def validate_canal(cls, v: str) -> str:
        if v not in CANALES_VENTA:
            raise ValueError(f"Canal inválido. Opciones: {', '.join(CANALES_VENTA)}")
        return v

    @field_validator("prioridad")
    @classmethod
    def validate_prioridad(cls, v: str) -> str:
        if v not in PRIORIDADES:
            raise ValueError(f"Prioridad inválida. Opciones: {', '.join(PRIORIDADES)}")
        return v

    @model_validator(mode="after")
    def validate_domicilio(self) -> "PedidoBase":
        if self.tipo_pedido == "domicilio" and not self.direccion_entrega:
            raise ValueError("Los pedidos de domicilio requieren 'direccion_entrega'")
        return self


class PedidoRead(PedidoBase):
    id: UUID
    empresa_id: UUID
    numero_factura: str | None
    subtotal: Decimal
    descuento_porcentaje: Decimal
    descuento_monto: Decimal
    total_iva: Decimal
    total_servicio: Decimal
    propina: Decimal
    total: Decimal
    estado: str
    estado_pago: str
    estado_cocina: str | None
    sesion_caja_id: UUID | None
    motivo_cancelacion: str | None
    fecha_pedido: datetime | None
    fecha_facturacion: datetime | None
    fecha_entrega: datetime | None
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID
    updated_by: UUID | None


class PedidoReadDetalle(PedidoRead):
    items: list[DetallePedidoRead] = []


class PedidoCreate(PedidoBase):
    model_config = ConfigDict(extra="forbid")

    empresa_id: UUID
    items: Annotated[list[DetallePedidoCreate], Field(min_length=1)]


class PedidoUpdate(BaseModel):
    """Solo editable en estado borrador o abierto."""
    model_config = ConfigDict(extra="forbid")

    nombre_cliente: Annotated[str | None, Field(max_length=255, default=None)]
    telefono_cliente: Annotated[str | None, Field(max_length=50, default=None)]
    direccion_entrega: str | None = None
    cantidad_comensales: Annotated[int | None, Field(ge=1, default=None)]
    mesero_id: UUID | None = None
    prioridad: str | None = None
    tiempo_estimado_minutos: Annotated[int | None, Field(ge=1, default=None)]
    descuento_porcentaje: Annotated[Decimal | None, Field(ge=0, le=100, decimal_places=2, default=None)]
    descuento_monto: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    propina: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]

    @field_validator("prioridad")
    @classmethod
    def validate_prioridad(cls, v: str | None) -> str | None:
        if v and v not in PRIORIDADES:
            raise ValueError(f"Prioridad inválida. Opciones: {', '.join(PRIORIDADES)}")
        return v


class PedidoEstadoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    estado: str
    motivo_cancelacion: Annotated[str | None, Field(default=None)]
    sesion_caja_id: UUID | None = None     # requerido al facturar
    estado_pago: str | None = None         # actualizable al facturar

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        if v not in ESTADOS_PEDIDO:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_PEDIDO)}")
        return v

    @field_validator("estado_pago")
    @classmethod
    def validate_estado_pago(cls, v: str | None) -> str | None:
        if v and v not in ESTADOS_PAGO:
            raise ValueError(f"Estado pago inválido. Opciones: {', '.join(ESTADOS_PAGO)}")
        return v

    @model_validator(mode="after")
    def validate_cancelacion(self) -> "PedidoEstadoUpdate":
        if self.estado == "cancelado" and not self.motivo_cancelacion:
            raise ValueError("El campo 'motivo_cancelacion' es obligatorio al cancelar")
        if self.estado == "facturado" and not self.sesion_caja_id:
            raise ValueError("El campo 'sesion_caja_id' es obligatorio al facturar")
        return self