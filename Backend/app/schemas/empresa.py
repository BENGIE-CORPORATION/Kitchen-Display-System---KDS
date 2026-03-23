from datetime import datetime
from typing import Annotated, Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field

# ─── Enums como literales ─────────────────────────────────────────────────────
TipoNegocio = Annotated[
    str,
    Field(pattern=r"^(restaurante|supermercado|retail|mixto)$", examples=["restaurante"]),
]

EstadoEmpresa = Annotated[
    str,
    Field(pattern=r"^(activo|suspendido|inactivo)$", examples=["activo"]),
]

PaisISO = Annotated[
    str,
    Field(min_length=2, max_length=2, examples=["EC"], description="Código ISO 3166-1 alpha-2"),
]

MonedaISO = Annotated[
    str,
    Field(min_length=3, max_length=3, examples=["USD"], description="Código ISO 4217"),
]


# ─── Base ─────────────────────────────────────────────────────────────────────
class EmpresaBase(BaseModel):
    nombre_legal: Annotated[str, Field(min_length=2, max_length=255, examples=["Corporación Ejemplo S.A."])]
    nombre_comercial: Annotated[str, Field(min_length=2, max_length=255, examples=["Ejemplo"])]
    identificacion: Annotated[
        str,
        Field(min_length=2, max_length=100, examples=["1790012345001"], description="RUC / CUIT / RFC / Tax ID"),
    ]
    tipo_negocio: TipoNegocio
    email: Annotated[EmailStr, Field(examples=["empresa@ejemplo.com"])]
    telefono: Annotated[str | None, Field(max_length=50, default=None, examples=["+593999000000"])]
    direccion_fiscal: Annotated[str | None, Field(default=None, examples=["Av. Principal 123"])]
    pais: PaisISO
    moneda: MonedaISO = "USD"
    logo_url: Annotated[
        str | None,
        Field(
            default=None,
            pattern=r"^(https?|ftp)://[^\s/$.?#].[^\s]*$",
            examples=["https://storage.example.com/logos/empresa.png"],
        ),
    ]
    timezone: Annotated[str, Field(default="UTC", max_length=50, examples=["America/Guayaquil"])]
    configuracion: Annotated[
        dict[str, Any] | None,
        Field(default=None, examples=[{"iva_default": 12, "servicio_default": 10}]),
    ]


# ─── Read (respuesta pública) ─────────────────────────────────────────────────
class EmpresaRead(EmpresaBase):
    id: UUID
    estado: str
    fecha_registro: datetime | None
    created_at: datetime | None
    updated_at: datetime | None


# ─── Create (entrada del cliente) ─────────────────────────────────────────────
class EmpresaCreate(EmpresaBase):
    model_config = ConfigDict(extra="forbid")

    estado: EstadoEmpresa = "activo"


# ─── Internal Create (lo que va a Supabase) ───────────────────────────────────
class EmpresaCreateInternal(EmpresaCreate):
    """Igual a EmpresaCreate. Existe para poder añadir campos internos
    (ej: created_by) sin exponer al cliente."""
    pass


# ─── Update (PATCH — todos opcionales) ───────────────────────────────────────
class EmpresaUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre_legal: Annotated[str | None, Field(min_length=2, max_length=255, default=None)]
    nombre_comercial: Annotated[str | None, Field(min_length=2, max_length=255, default=None)]
    email: Annotated[EmailStr | None, Field(default=None)]
    telefono: Annotated[str | None, Field(max_length=50, default=None)]
    direccion_fiscal: Annotated[str | None, Field(default=None)]
    logo_url: Annotated[
        str | None,
        Field(default=None, pattern=r"^(https?|ftp)://[^\s/$.?#].[^\s]*$"),
    ]
    timezone: Annotated[str | None, Field(max_length=50, default=None)]
    configuracion: Annotated[dict[str, Any] | None, Field(default=None)]
    estado: Annotated[str | None, Field(pattern=r"^(activo|suspendido|inactivo)$", default=None)]


# ─── Internal Update (añade updated_at automáticamente) ──────────────────────
class EmpresaUpdateInternal(EmpresaUpdate):
    updated_at: datetime


# ─── Delete (soft delete) ─────────────────────────────────────────────────────
class EmpresaDelete(BaseModel):
    model_config = ConfigDict(extra="forbid")
    estado: str = "inactivo"
    updated_at: datetime