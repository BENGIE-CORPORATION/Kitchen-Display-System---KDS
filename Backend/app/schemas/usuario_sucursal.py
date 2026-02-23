from datetime import datetime
from typing import Annotated, Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


RolSucursal = Annotated[
    str,
    Field(
        pattern=r"^(administrador|cajero|mesero|cocinero|bodeguero|vendedor)$",
        examples=["cajero"],
    ),
]


class UsuarioSucursalBase(BaseModel):
    usuario_id: UUID
    sucursal_id: UUID
    rol_sucursal: RolSucursal
    permisos: list[str] | None = None
    es_principal: bool = False


class UsuarioSucursalRead(UsuarioSucursalBase):
    id: UUID
    estado: str
    fecha_asignacion: datetime | None
    created_at: datetime | None
    updated_at: datetime | None
    created_by: UUID | None
    # Datos expandidos opcionales (cuando se hace join)
    sucursal: dict[str, Any] | None = None
    usuario: dict[str, Any] | None = None


class UsuarioSucursalCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    usuario_id: UUID
    sucursal_id: UUID
    rol_sucursal: RolSucursal
    permisos: list[str] | None = None
    es_principal: bool = False


class UsuarioSucursalCreateInternal(UsuarioSucursalCreate):
    estado: str = "activo"
    created_by: UUID | None = None


class UsuarioSucursalUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    rol_sucursal: Annotated[
        str | None,
        Field(pattern=r"^(administrador|cajero|mesero|cocinero|bodeguero|vendedor)$", default=None),
    ]
    permisos: list[str] | None = None
    es_principal: bool | None = None
    estado: Annotated[str | None, Field(pattern=r"^(activo|inactivo)$", default=None)]


class UsuarioSucursalUpdateInternal(UsuarioSucursalUpdate):
    updated_at: datetime
