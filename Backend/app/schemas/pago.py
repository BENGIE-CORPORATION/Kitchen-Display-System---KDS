from datetime import date, datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.pago import (
    ESTADOS_DIVISION,
    ESTADOS_PAGO,
    METODOS_PAGO,
    TIPOS_DIVISION,
    TIPOS_TARJETA,
)


# ─── Pago ─────────────────────────────────────────────────────────────────────

class PagoBase(BaseModel):
    metodo_pago: Annotated[str, Field(examples=list(METODOS_PAGO))]
    monto: Annotated[Decimal, Field(gt=0, decimal_places=2)]
    numero_pago: Annotated[str, Field(min_length=1, max_length=50)]
    monto_recibido: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    referencia: Annotated[str | None, Field(max_length=255, default=None)]
    banco: Annotated[str | None, Field(max_length=100, default=None)]
    numero_cheque: Annotated[str | None, Field(max_length=100, default=None)]
    fecha_cheque: date | None = None
    titular_tarjeta: Annotated[str | None, Field(max_length=255, default=None)]
    ultimos_4_digitos: Annotated[str | None, Field(min_length=4, max_length=4, default=None)]
    tipo_tarjeta: str | None = None
    cuotas: Annotated[int, Field(ge=1, default=1)]
    comprobante_url: Annotated[str | None, Field(max_length=2048, default=None)]
    notas: Annotated[str | None, Field(default=None)]

    @field_validator("metodo_pago")
    @classmethod
    def validate_metodo(cls, v: str) -> str:
        if v not in METODOS_PAGO:
            raise ValueError(f"Método inválido. Opciones: {', '.join(sorted(METODOS_PAGO))}")
        return v

    @field_validator("tipo_tarjeta")
    @classmethod
    def validate_tipo_tarjeta(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_TARJETA:
            raise ValueError(f"Tipo tarjeta inválido. Opciones: {', '.join(TIPOS_TARJETA)}")
        return v

    @field_validator("numero_pago", "referencia", "banco", "numero_cheque", "titular_tarjeta")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("notas")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @model_validator(mode="after")
    def validate_campos_metodo(self) -> "PagoBase":
        # Efectivo: monto_recibido requerido para calcular cambio
        if self.metodo_pago == "efectivo" and self.monto_recibido is None:
            raise ValueError("Los pagos en efectivo requieren 'monto_recibido'")
        if self.metodo_pago == "efectivo" and self.monto_recibido < self.monto:
            raise ValueError("El monto recibido no puede ser menor al monto del pago")
        # Cheque: numero_cheque requerido
        if self.metodo_pago == "cheque" and not self.numero_cheque:
            raise ValueError("Los pagos con cheque requieren 'numero_cheque'")
        # Tarjeta: últimos 4 dígitos requeridos
        if self.metodo_pago in ("tarjeta_debito", "tarjeta_credito") and not self.ultimos_4_digitos:
            raise ValueError("Los pagos con tarjeta requieren 'ultimos_4_digitos'")
        return self


class PagoRead(PagoBase):
    id: UUID
    pedido_id: UUID
    sesion_caja_id: UUID
    cambio: Decimal | None
    estado: str
    created_at: datetime | None
    created_by: UUID


class PagoCreate(PagoBase):
    model_config = ConfigDict(extra="forbid")

    sesion_caja_id: UUID


class PagoEstadoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    estado: str

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        permitidos = {"rechazado", "reversado"}
        if v not in permitidos:
            raise ValueError(f"Solo se puede cambiar a: {', '.join(permitidos)}")
        return v


# ─── División de cuenta ───────────────────────────────────────────────────────

class DetalleDivisionBase(BaseModel):
    detalle_pedido_id: UUID
    cantidad: Annotated[Decimal | None, Field(gt=0, decimal_places=3, default=None)]
    monto: Annotated[Decimal, Field(ge=0, decimal_places=2)]


class DetalleDivisionRead(DetalleDivisionBase):
    id: UUID
    division_id: UUID
    created_at: datetime | None


class DetalleDivisionCreate(DetalleDivisionBase):
    model_config = ConfigDict(extra="forbid")


class DivisionCuentaBase(BaseModel):
    tipo_division: Annotated[str, Field(examples=list(TIPOS_DIVISION))]
    numero_division: Annotated[int, Field(ge=1)]
    porcentaje: Annotated[Decimal | None, Field(ge=0, le=100, decimal_places=2, default=None)]
    monto: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    descripcion: Annotated[str | None, Field(max_length=255, default=None)]

    @field_validator("tipo_division")
    @classmethod
    def validate_tipo(cls, v: str) -> str:
        if v not in TIPOS_DIVISION:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(TIPOS_DIVISION)}")
        return v

    @field_validator("descripcion")
    @classmethod
    def clean_descripcion(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @model_validator(mode="after")
    def validate_por_tipo(self) -> "DivisionCuentaBase":
        if self.tipo_division == "por_porcentaje" and self.porcentaje is None:
            raise ValueError("Las divisiones por porcentaje requieren 'porcentaje'")
        if self.tipo_division == "por_monto" and self.monto is None:
            raise ValueError("Las divisiones por monto requieren 'monto'")
        return self


class DivisionCuentaRead(DivisionCuentaBase):
    id: UUID
    pedido_id: UUID
    estado: str
    created_at: datetime | None
    created_by: UUID | None


class DivisionCuentaReadDetalle(DivisionCuentaRead):
    items: list[DetalleDivisionRead] = []


class DivisionCuentaCreate(DivisionCuentaBase):
    model_config = ConfigDict(extra="forbid")

    items: list[DetalleDivisionCreate] = []


class DivisionEstadoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    estado: str

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        if v not in ESTADOS_DIVISION:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_DIVISION)}")
        return v