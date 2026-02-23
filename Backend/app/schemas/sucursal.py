from datetime import time, datetime
from decimal import Decimal
from typing import Annotated, Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


TipoSucursal = Annotated[
    str,
    Field(pattern=r"^(principal|sucursal|bodega|punto_venta)$", examples=["principal"]),
]

EstadoSucursal = Annotated[
    str,
    Field(pattern=r"^(activo|inactivo|mantenimiento)$", examples=["activo"]),
]


class SucursalBase(BaseModel):
    empresa_id: UUID
    codigo: Annotated[str, Field(min_length=1, max_length=50, examples=["SUC-001"])]
    nombre: Annotated[str, Field(min_length=2, max_length=255, examples=["Sucursal Norte"])]
    tipo: TipoSucursal
    direccion: str | None = None
    ciudad: Annotated[str | None, Field(max_length=100, default=None)]
    estado_provincia: Annotated[str | None, Field(max_length=100, default=None)]
    codigo_postal: Annotated[str | None, Field(max_length=20, default=None)]
    pais: Annotated[str | None, Field(min_length=2, max_length=2, default=None)]
    telefono: Annotated[str | None, Field(max_length=50, default=None)]
    email: EmailStr | None = None
    coordenadas_lat: Annotated[Decimal | None, Field(ge=-90, le=90, default=None)]
    coordenadas_lng: Annotated[Decimal | None, Field(ge=-180, le=180, default=None)]
    logo_url: Annotated[
        str | None,
        Field(pattern=r"^(https?|ftp)://[^\s/$.?#].[^\s]*$", default=None),
    ]
    horario_apertura: time | None = None
    horario_cierre: time | None = None
    configuracion: dict[str, Any] | None = None


class SucursalRead(SucursalBase):
    id: UUID
    estado: str
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID | None
    updated_by: UUID | None


class SucursalCreate(SucursalBase):
    model_config = ConfigDict(extra="forbid")
    estado: EstadoSucursal = "activo"


class SucursalCreateInternal(SucursalCreate):
    created_by: UUID | None = None


class SucursalUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre: Annotated[str | None, Field(min_length=2, max_length=255, default=None)]
    tipo: Annotated[str | None, Field(pattern=r"^(principal|sucursal|bodega|punto_venta)$", default=None)]
    direccion: str | None = None
    ciudad: Annotated[str | None, Field(max_length=100, default=None)]
    estado_provincia: Annotated[str | None, Field(max_length=100, default=None)]
    codigo_postal: Annotated[str | None, Field(max_length=20, default=None)]
    telefono: Annotated[str | None, Field(max_length=50, default=None)]
    email: EmailStr | None = None
    coordenadas_lat: Annotated[Decimal | None, Field(ge=-90, le=90, default=None)]
    coordenadas_lng: Annotated[Decimal | None, Field(ge=-180, le=180, default=None)]
    logo_url: Annotated[
        str | None,
        Field(pattern=r"^(https?|ftp)://[^\s/$.?#].[^\s]*$", default=None),
    ]
    horario_apertura: time | None = None
    horario_cierre: time | None = None
    configuracion: dict[str, Any] | None = None
    estado: Annotated[str | None, Field(pattern=r"^(activo|inactivo|mantenimiento)$", default=None)]


class SucursalUpdateInternal(SucursalUpdate):
    updated_at: datetime
    updated_by: UUID | None = None
