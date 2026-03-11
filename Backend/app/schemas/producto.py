from datetime import datetime
from decimal import Decimal
from typing import Annotated, Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.producto import ESTADOS_VALIDOS, TIPOS_PRODUCTO, UNIDADES_MEDIDA


# ─── Base ─────────────────────────────────────────────────────────────────────

class ProductoBase(BaseModel):
    nombre: Annotated[str, Field(min_length=1, max_length=255)]
    categoria_id: UUID
    tipo_producto: Annotated[str, Field(examples=["simple", "compuesto", "servicio", "combo"])]
    unidad_medida: Annotated[str, Field(default="unidad")]
    codigo_interno: Annotated[str | None, Field(max_length=100, default=None)]
    codigo_barras: Annotated[str | None, Field(max_length=100, default=None)]
    descripcion: Annotated[str | None, Field(default=None)]
    descripcion_corta: Annotated[str | None, Field(max_length=500, default=None)]
    marca: Annotated[str | None, Field(max_length=100, default=None)]
    modelo: Annotated[str | None, Field(max_length=100, default=None)]
    imagen_principal_url: Annotated[str | None, Field(max_length=2048, default=None)]
    imagenes_adicionales: list[str] | None = None
    es_vendible: bool = True
    es_comprable: bool = True
    requiere_inventario: bool = True
    permite_decimal: bool = False
    tags: list[str] | None = None

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str) -> str:
        return sanitize_strict(v)

    @field_validator("codigo_interno", "codigo_barras")
    @classmethod
    def clean_codigo(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("descripcion")
    @classmethod
    def clean_descripcion(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("descripcion_corta", "marca", "modelo")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("tipo_producto")
    @classmethod
    def validate_tipo(cls, v: str) -> str:
        if v not in TIPOS_PRODUCTO:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(TIPOS_PRODUCTO)}")
        return v

    @field_validator("unidad_medida")
    @classmethod
    def validate_unidad(cls, v: str) -> str:
        if v not in UNIDADES_MEDIDA:
            raise ValueError(f"Unidad inválida. Opciones: {', '.join(UNIDADES_MEDIDA)}")
        return v


# ─── Read ─────────────────────────────────────────────────────────────────────

class ProductoRead(ProductoBase):
    id: UUID
    empresa_id: UUID
    estado: str
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID | None
    updated_by: UUID | None


# ─── Create ───────────────────────────────────────────────────────────────────

class ProductoCreate(ProductoBase):
    model_config = ConfigDict(extra="forbid")

    empresa_id: UUID
    estado: Annotated[str, Field(default="activo")]

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        if v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v


# ─── CreateInternal ───────────────────────────────────────────────────────────

class ProductoCreateInternal(ProductoCreate):
    created_by: UUID | None = None


# ─── Update ───────────────────────────────────────────────────────────────────

class ProductoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre: Annotated[str | None, Field(min_length=1, max_length=255, default=None)]
    categoria_id: UUID | None = None
    tipo_producto: str | None = None
    unidad_medida: str | None = None
    codigo_interno: Annotated[str | None, Field(max_length=100, default=None)]
    codigo_barras: Annotated[str | None, Field(max_length=100, default=None)]
    descripcion: str | None = None
    descripcion_corta: Annotated[str | None, Field(max_length=500, default=None)]
    marca: Annotated[str | None, Field(max_length=100, default=None)]
    modelo: Annotated[str | None, Field(max_length=100, default=None)]
    imagen_principal_url: Annotated[str | None, Field(max_length=2048, default=None)]
    imagenes_adicionales: list[str] | None = None
    es_vendible: bool | None = None
    es_comprable: bool | None = None
    requiere_inventario: bool | None = None
    permite_decimal: bool | None = None
    tags: list[str] | None = None
    estado: str | None = None

    @field_validator("nombre")
    @classmethod
    def clean_nombre(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("codigo_interno", "codigo_barras")
    @classmethod
    def clean_codigo(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("descripcion")
    @classmethod
    def clean_descripcion(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("descripcion_corta", "marca", "modelo")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("tipo_producto")
    @classmethod
    def validate_tipo(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_PRODUCTO:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(TIPOS_PRODUCTO)}")
        return v

    @field_validator("unidad_medida")
    @classmethod
    def validate_unidad(cls, v: str | None) -> str | None:
        if v and v not in UNIDADES_MEDIDA:
            raise ValueError(f"Unidad inválida. Opciones: {', '.join(UNIDADES_MEDIDA)}")
        return v

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str | None) -> str | None:
        if v and v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v


# ─── UpdateInternal ───────────────────────────────────────────────────────────

class ProductoUpdateInternal(ProductoUpdate):
    updated_at: datetime
    updated_by: UUID | None = None


# ─── ProductoSucursal (precio y stock por sucursal) ───────────────────────────

class ProductoSucursalBase(BaseModel):
    precio_venta: Annotated[Decimal, Field(ge=0, decimal_places=2)]
    precio_costo: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    precio_mayoreo: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    cantidad_mayoreo: Annotated[int | None, Field(ge=1, default=None)]
    aplica_iva: bool = True
    aplica_servicio: bool = True
    porcentaje_iva: Annotated[Decimal, Field(ge=0, le=100, decimal_places=2, default=Decimal("13.00"))]
    porcentaje_servicio: Annotated[Decimal, Field(ge=0, le=100, decimal_places=2, default=Decimal("10.00"))]
    stock_disponible: Annotated[Decimal, Field(ge=0, decimal_places=3, default=Decimal("0"))]
    stock_minimo: Annotated[Decimal, Field(ge=0, decimal_places=3, default=Decimal("0"))]
    stock_maximo: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    punto_reorden: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    ubicacion_fisica: Annotated[str | None, Field(max_length=100, default=None)]
    disponible_venta: bool = True

    @field_validator("ubicacion_fisica")
    @classmethod
    def clean_ubicacion(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None


class ProductoSucursalRead(ProductoSucursalBase):
    id: UUID
    producto_id: UUID
    sucursal_id: UUID
    margen_utilidad: Decimal | None
    created_at: datetime | None
    updated_at: datetime | None


class ProductoSucursalCreate(ProductoSucursalBase):
    model_config = ConfigDict(extra="forbid")

    producto_id: UUID
    sucursal_id: UUID
    margen_utilidad: Annotated[Decimal | None, Field(ge=0, le=100, decimal_places=2, default=None)]


class ProductoSucursalUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    precio_venta: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    precio_costo: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    precio_mayoreo: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    cantidad_mayoreo: Annotated[int | None, Field(ge=1, default=None)]
    aplica_iva: bool | None = None
    aplica_servicio: bool | None = None
    porcentaje_iva: Annotated[Decimal | None, Field(ge=0, le=100, decimal_places=2, default=None)]
    porcentaje_servicio: Annotated[Decimal | None, Field(ge=0, le=100, decimal_places=2, default=None)]
    stock_disponible: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    stock_minimo: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    stock_maximo: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    punto_reorden: Annotated[Decimal | None, Field(ge=0, decimal_places=3, default=None)]
    ubicacion_fisica: Annotated[str | None, Field(max_length=100, default=None)]
    disponible_venta: bool | None = None
    margen_utilidad: Annotated[Decimal | None, Field(ge=0, le=100, decimal_places=2, default=None)]

    @field_validator("ubicacion_fisica")
    @classmethod
    def clean_ubicacion(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None


class ProductoSucursalUpdateInternal(ProductoSucursalUpdate):
    updated_at: datetime