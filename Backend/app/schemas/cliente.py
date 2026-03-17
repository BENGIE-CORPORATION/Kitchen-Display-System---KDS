from datetime import date, datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from ..core.sanitizer import sanitize_strict, sanitize_text
from ..models.cliente import ESTADOS_VALIDOS, GENEROS, TIPOS_CLIENTE, TIPOS_IDENTIFICACION


class ClienteBase(BaseModel):
    nombre: Annotated[str, Field(min_length=1, max_length=255)]
    tipo_cliente: Annotated[str, Field(default="final")]
    apellido: Annotated[str | None, Field(max_length=255, default=None)]
    nombre_comercial: Annotated[str | None, Field(max_length=255, default=None)]
    tipo_identificacion: str | None = None
    identificacion: Annotated[str | None, Field(max_length=100, default=None)]
    email: Annotated[EmailStr | None, Field(default=None)]
    telefono: Annotated[str | None, Field(max_length=50, default=None)]
    telefono_alternativo: Annotated[str | None, Field(max_length=50, default=None)]
    fecha_nacimiento: date | None = None
    direccion: Annotated[str | None, Field(default=None)]
    ciudad: Annotated[str | None, Field(max_length=100, default=None)]
    codigo_postal: Annotated[str | None, Field(max_length=20, default=None)]
    pais: Annotated[str | None, Field(min_length=2, max_length=2, default=None)]
    genero: str | None = None
    permite_marketing: bool = False
    notas: Annotated[str | None, Field(default=None)]
    limite_credito: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    descuento_porcentaje: Annotated[Decimal, Field(ge=0, le=100, decimal_places=2, default=Decimal("0"))]

    @field_validator("nombre", "apellido", "nombre_comercial", "ciudad")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("identificacion")
    @classmethod
    def clean_identificacion(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("direccion", "notas")
    @classmethod
    def clean_text(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("tipo_cliente")
    @classmethod
    def validate_tipo(cls, v: str) -> str:
        if v not in TIPOS_CLIENTE:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(TIPOS_CLIENTE)}")
        return v

    @field_validator("tipo_identificacion")
    @classmethod
    def validate_tipo_identificacion(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_IDENTIFICACION:
            raise ValueError(f"Tipo identificación inválido. Opciones: {', '.join(TIPOS_IDENTIFICACION)}")
        return v

    @field_validator("genero")
    @classmethod
    def validate_genero(cls, v: str | None) -> str | None:
        if v and v not in GENEROS:
            raise ValueError(f"Género inválido. Opciones: {', '.join(GENEROS)}")
        return v


class ClienteRead(ClienteBase):
    id: UUID
    empresa_id: UUID
    puntos_fidelidad: int
    fecha_registro: datetime | None
    ultima_compra: datetime | None
    total_compras: Decimal
    cantidad_compras: int
    estado: str
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID | None
    updated_by: UUID | None


class ClienteCreate(ClienteBase):
    model_config = ConfigDict(extra="forbid")

    empresa_id: UUID
    estado: Annotated[str, Field(default="activo")]

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str) -> str:
        if v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v


class ClienteCreateInternal(ClienteCreate):
    created_by: UUID | None = None


class ClienteUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nombre: Annotated[str | None, Field(min_length=1, max_length=255, default=None)]
    apellido: Annotated[str | None, Field(max_length=255, default=None)]
    nombre_comercial: Annotated[str | None, Field(max_length=255, default=None)]
    tipo_cliente: str | None = None
    tipo_identificacion: str | None = None
    identificacion: Annotated[str | None, Field(max_length=100, default=None)]
    email: Annotated[EmailStr | None, Field(default=None)]
    telefono: Annotated[str | None, Field(max_length=50, default=None)]
    telefono_alternativo: Annotated[str | None, Field(max_length=50, default=None)]
    fecha_nacimiento: date | None = None
    direccion: str | None = None
    ciudad: Annotated[str | None, Field(max_length=100, default=None)]
    codigo_postal: Annotated[str | None, Field(max_length=20, default=None)]
    pais: Annotated[str | None, Field(min_length=2, max_length=2, default=None)]
    genero: str | None = None
    permite_marketing: bool | None = None
    notas: str | None = None
    limite_credito: Annotated[Decimal | None, Field(ge=0, decimal_places=2, default=None)]
    descuento_porcentaje: Annotated[Decimal | None, Field(ge=0, le=100, decimal_places=2, default=None)]
    estado: str | None = None

    @field_validator("nombre", "apellido", "nombre_comercial", "ciudad")
    @classmethod
    def clean_strict(cls, v: str | None) -> str | None:
        return sanitize_strict(v) if v else None

    @field_validator("identificacion")
    @classmethod
    def clean_identificacion(cls, v: str | None) -> str | None:
        return sanitize_strict(v).upper() if v else None

    @field_validator("direccion", "notas")
    @classmethod
    def clean_text(cls, v: str | None) -> str | None:
        return sanitize_text(v) if v else None

    @field_validator("tipo_cliente")
    @classmethod
    def validate_tipo(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_CLIENTE:
            raise ValueError(f"Tipo inválido. Opciones: {', '.join(TIPOS_CLIENTE)}")
        return v

    @field_validator("tipo_identificacion")
    @classmethod
    def validate_tipo_identificacion(cls, v: str | None) -> str | None:
        if v and v not in TIPOS_IDENTIFICACION:
            raise ValueError(f"Tipo identificación inválido. Opciones: {', '.join(TIPOS_IDENTIFICACION)}")
        return v

    @field_validator("genero")
    @classmethod
    def validate_genero(cls, v: str | None) -> str | None:
        if v and v not in GENEROS:
            raise ValueError(f"Género inválido. Opciones: {', '.join(GENEROS)}")
        return v

    @field_validator("estado")
    @classmethod
    def validate_estado(cls, v: str | None) -> str | None:
        if v and v not in ESTADOS_VALIDOS:
            raise ValueError(f"Estado inválido. Opciones: {', '.join(ESTADOS_VALIDOS)}")
        return v


class ClienteUpdateInternal(ClienteUpdate):
    updated_at: datetime
    updated_by: UUID | None = None