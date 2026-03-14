from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.caja import (
    ESTADOS_CAJA,
    ESTADOS_SESION,
    METODOS_PAGO,
    TIPOS_CAJA,
    TIPOS_MOVIMIENTO,
)


# ─── Caja ─────────────────────────────────────────────────────────────────────

class CajaBase(BaseModel):
    codigo: Annotated[str, Field(min_length=1, max_length=50)]
    nombre: Annotated[str, Field(min_length=1, max_length=100)]
    tipo: Annotated[str, Field(default="principal")]
    descripcion: Annotated[str | None, Field(default=None)]
    numero_serie_fiscal: Annotated[str | None, Field(max_length=100, default=None)]

    @field_validator("codigo")
    @classmethod
    def clean_codigo(cls, v: str) -> str:
        return sanitize_strict(v).upper()

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str) -> str:
        return sanitize_strict(v)

    @field_validator("numero_serie_fiscal")
    @classmethod
    def clean_serie(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("descripcion")
    @classmethod
    def clean_descripcion(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("tipo")
    @classmethod
    def validate_tipo(cls, v: str) -> str:
        if v not in TIPOS_CAJA:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(TIPOS_CAJA)}")
        return v


class CajaRead(CajaBase):
    id: UUID
    sucursal_id: UUID
    estado: str
    created_at: datetime | None
    updated_at: datetime | None


class CajaCreate(CajaBase):
    model_config = ConfigDict(extra="forbid")

    sucursal_id: UUID
    estado: Annotated[str, Field(default="activo")]

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        if v not in ESTADOS_CAJA:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_CAJA)}")
        return v


class CajaCreateInternal(CajaCreate):
    pass


class CajaUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre: Annotated[str | None, Field(min_length=1, max_length=100, default=None)]
    tipo: str | None = None
    descripcion: str | None = None
    numero_serie_fiscal: Annotated[str | None, Field(max_length=100, default=None)]
    estado: str | None = None

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("numero_serie_fiscal")
    @classmethod
    def clean_serie(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("descripcion")
    @classmethod
    def clean_descripcion(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("tipo")
    @classmethod
    def validate_tipo(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_CAJA:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(TIPOS_CAJA)}")
        return v

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str | None) -> str | None:
        if v and v not in ESTADOS_CAJA:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_CAJA)}")
        return v


class CajaUpdateInternal(CajaUpdate):
    updated_at: datetime


# ─── SesionCaja ───────────────────────────────────────────────────────────────

class SesionCajaRead(BaseModel):
    id: UUID
    caja_id: UUID
    usuario_id: UUID
    numero_sesion: str
    monto_apertura: Decimal
    monto_cierre: Decimal | None
    monto_esperado: Decimal | None
    diferencia: Decimal | None
    total_ventas: Decimal
    total_efectivo: Decimal
    total_tarjeta_debito: Decimal
    total_tarjeta_credito: Decimal
    total_transferencia: Decimal
    total_sinpe: Decimal
    total_otros: Decimal
    total_entradas: Decimal
    total_salidas: Decimal
    cantidad_transacciones: int
    estado: str
    fecha_apertura: datetime | None
    fecha_cierre: datetime | None
    notas_apertura: str | None
    notas_cierre: str | None
    created_at: datetime | None


class SesionCajaApertura(BaseModel):
    """Schema para abrir una sesión de caja."""
    model_config = ConfigDict(extra="forbid")

    caja_id: UUID
    numero_sesion: Annotated[str, Field(min_length=1, max_length=50)]
    monto_apertura: Annotated[Decimal, Field(ge=0, decimal_places=2)]
    notas_apertura: Annotated[str | None, Field(default=None)]

    @field_validator("numero_sesion")
    @classmethod
    def clean_numero(cls, v: str) -> str:
        return v.strip().upper()

    @field_validator("notas_apertura")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class SesionCajaCierre(BaseModel):
    """Schema para cerrar una sesión de caja."""
    model_config = ConfigDict(extra="forbid")

    monto_cierre: Annotated[Decimal, Field(ge=0, decimal_places=2)]
    notas_cierre: Annotated[str | None, Field(default=None)]

    @field_validator("notas_cierre")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


# ─── MovimientoCaja ───────────────────────────────────────────────────────────

class MovimientoCajaBase(BaseModel):
    tipo: Annotated[str, Field(examples=["entrada", "salida"])]
    concepto: Annotated[str, Field(min_length=1, max_length=255)]
    monto: Annotated[Decimal, Field(gt=0, decimal_places=2)]
    metodo_pago: Annotated[str | None, Field(default=None)]
    comprobante: Annotated[str | None, Field(max_length=255, default=None)]
    documento_url: Annotated[str | None, Field(max_length=2048, default=None)]
    beneficiario: Annotated[str | None, Field(max_length=255, default=None)]
    notas: Annotated[str | None, Field(default=None)]

    @field_validator("tipo")
    @classmethod
    def validate_tipo(cls, v: str) -> str:
        if v not in TIPOS_MOVIMIENTO:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(TIPOS_MOVIMIENTO)}")
        return v

    @field_validator("metodo_pago")
    @classmethod
    def validate_metodo(cls, v: str | None) -> str | None:
        if v and v not in METODOS_PAGO:
            raise ValueError(f"Método de pago inválido. Opciones: {', '.join(METODOS_PAGO)}")
        return v

    @field_validator("concepto", "beneficiario", "comprobante")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("notas")
    @classmethod
    def clean_notas(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None


class MovimientoCajaRead(MovimientoCajaBase):
    id: UUID
    sesion_caja_id: UUID
    created_at: datetime | None
    created_by: UUID


class MovimientoCajaCreate(MovimientoCajaBase):
    model_config = ConfigDict(extra="forbid")