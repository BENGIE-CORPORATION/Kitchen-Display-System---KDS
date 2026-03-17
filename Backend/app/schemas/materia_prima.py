from datetime import datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.materia_prima import ESTADOS_VALIDOS, UNIDADES_MEDIDA


# ─── MateriaPrima Base ────────────────────────────────────────────────────────

class MateriaPrimaBase(BaseModel):
    nombre: Annotated[str, Field(min_length=1, max_length=255)]
    unidad_medida: Annotated[str, Field(examples=list(UNIDADES_MEDIDA))]
    codigo: Annotated[str | None, Field(max_length=100, default=None)]
    descripcion: Annotated[str | None, Field(default=None)]
    categoria: Annotated[str | None, Field(max_length=100, default=None)]
    perecedero: bool = False
    dias_vida_util: Annotated[int | None, Field(ge=1, default=None)]

    @field_validator("nombre", "categoria")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("codigo")
    @classmethod
    def clean_codigo(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("descripcion")
    @classmethod
    def clean_descripcion(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("unidad_medida")
    @classmethod
    def validate_unidad(cls, v: str) -> str:
        if v not in UNIDADES_MEDIDA:
            raise ValueError(f"Unidad inválida. Opciones: {', '.join(sorted(UNIDADES_MEDIDA))}")
        return v

    @field_validator("dias_vida_util")
    @classmethod
    def validate_dias(cls, v: int | None, info) -> int | None:
        # Se valida en model_validator a nivel de clase completa si se necesita
        return v


class MateriaPrimaRead(MateriaPrimaBase):
    id: UUID
    empresa_id: UUID
    estado: str
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID | None
    updated_by: UUID | None


class MateriaPrimaCreate(MateriaPrimaBase):
    model_config = ConfigDict(extra="forbid")

    empresa_id: UUID
    estado: Annotated[str, Field(default="activo")]

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        if v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v


class MateriaPrimaCreateInternal(MateriaPrimaCreate):
    created_by: UUID | None = None


class MateriaPrimaUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre: Annotated[str | None, Field(min_length=1, max_length=255, default=None)]
    unidad_medida: str | None = None
    codigo: Annotated[str | None, Field(max_length=100, default=None)]
    descripcion: str | None = None
    categoria: Annotated[str | None, Field(max_length=100, default=None)]
    perecedero: bool | None = None
    dias_vida_util: Annotated[int | None, Field(ge=1, default=None)]
    estado: str | None = None

    @field_validator("nombre", "categoria")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("codigo")
    @classmethod
    def clean_codigo(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("descripcion")
    @classmethod
    def clean_descripcion(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("unidad_medida")
    @classmethod
    def validate_unidad(cls, v: str | None) -> str | None:
        if v and v not in UNIDADES_MEDIDA:
            raise ValueError(f"Unidad inválida. Opciones: {', '.join(sorted(UNIDADES_MEDIDA))}")
        return v

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str | None) -> str | None:
        if v and v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v


class MateriaPrimaUpdateInternal(MateriaPrimaUpdate):
    updated_at: datetime
    updated_by: UUID | None = None


# ─── MateriaPrimaSucursal ─────────────────────────────────────────────────────

class MateriaPrimaSucursalBase(BaseModel):
    stock_actual: Annotated[Decimal, Field(ge=0, decimal_places=3, default=Decimal("0"))]
    stock_minimo: Annotated[Decimal, Field(ge=0, decimal_places=3, default=Decimal("0"))]
    stock_maximo: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    costo_promedio: Annotated[Decimal, Field(ge=0, decimal_places=4, default=Decimal("0"))]
    ultimo_costo: Annotated[Decimal | None, Field(ge=0, decimal_places=4, default=None)]
    ubicacion_fisica: Annotated[str | None, Field(max_length=100, default=None)]

    @field_validator("ubicacion_fisica")
    @classmethod
    def clean_ubicacion(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None


class MateriaPrimaSucursalRead(MateriaPrimaSucursalBase):
    id: UUID
    materia_prima_id: UUID
    sucursal_id: UUID
    created_at: datetime | None
    updated_at: datetime | None


class MateriaPrimaSucursalCreate(MateriaPrimaSucursalBase):
    model_config = ConfigDict(extra="forbid")

    materia_prima_id: UUID
    sucursal_id: UUID


class MateriaPrimaSucursalUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    stock_actual: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    stock_minimo: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    stock_maximo: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    costo_promedio: Annotated[Decimal | None, Field(ge=0, decimal_places=4, default=None)]
    ultimo_costo: Annotated[Decimal | None, Field(ge=0, decimal_places=4, default=None)]
    ubicacion_fisica: Annotated[str | None, Field(max_length=100, default=None)]

    @field_validator("ubicacion_fisica")
    @classmethod
    def clean_ubicacion(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None


class MateriaPrimaSucursalUpdateInternal(MateriaPrimaSucursalUpdate):
    updated_at: datetime