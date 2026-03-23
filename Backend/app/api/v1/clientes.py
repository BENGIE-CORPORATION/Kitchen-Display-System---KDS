"""
Router de Clientes — solo lógica HTTP.

Seguridad:
  GET    /clientes/           → admin_empresa o super_admin
  GET    /clientes/{id}       → admin_empresa o super_admin
  POST   /clientes/           → autenticado (empleados también pueden crear clientes)
  PATCH  /clientes/{id}       → admin_empresa o super_admin
  PATCH  /clientes/{id}/puntos → admin_empresa o super_admin
  DELETE /clientes/{id}       → admin_empresa o super_admin [soft]
  DELETE /clientes/{id}/hard  → solo super_admin
"""

from datetime import UTC, datetime
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, status
from loguru import logger
from pydantic import BaseModel, Field
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    NotFoundException,
)
from ...core.limiter import get_user_id_from_token, limiter
from ...core.pagination import PaginatedResponse
from ...core.security import (
    get_current_admin,
    get_current_superadmin,
    get_current_user,
    verify_empresa_access,
)
from ...crud.crud_clientes import (
    actualizar_puntos,
    cliente_email_exists,
    cliente_identificacion_exists,
    create_cliente,
    get_cliente,
    get_clientes,
    hard_delete_cliente,
    soft_delete_cliente,
    update_cliente,
)
from ...database import get_supabase
from ...schemas.cliente import (
    ClienteCreate,
    ClienteCreateInternal,
    ClienteRead,
    ClienteUpdate,
    ClienteUpdateInternal,
)

router = APIRouter(prefix="/clientes", tags=["Clientes"])


class PuntosUpdate(BaseModel):
    puntos: int = Field(..., description="Positivo para sumar, negativo para canje")
    motivo: str | None = Field(default=None, max_length=255)


# ─── GET /clientes/ ───────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[ClienteRead],
    summary="Listar clientes",
    description="admin_empresa ve solo su empresa. super_admin debe especificar empresa_id.",
)
def read_clientes(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "created_at",
    order_desc: bool = True,
    tipo_cliente: str | None = None,
    estado: str | None = None,
    permite_marketing: bool | None = None,
    search: str | None = None,
    empresa_id: UUID | None = None,
) -> dict:
    if current_user["rol_global"] == "super_admin":
        if not empresa_id:
            raise BadRequestException("super_admin debe especificar empresa_id como query param")
        target = empresa_id
    else:
        target = UUID(str(current_user["empresa_id"]))

    return get_clientes(
        db=db, empresa_id=target, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc, tipo_cliente=tipo_cliente,
        estado=estado, permite_marketing=permite_marketing, search=search,
    )


# ─── GET /clientes/{id} ───────────────────────────────────────────────────────

@router.get("/{cliente_id}", response_model=ClienteRead, summary="Obtener cliente")
def read_cliente(
    cliente_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    cliente = get_cliente(db, cliente_id)
    if not cliente:
        raise NotFoundException("Cliente no encontrado")
    verify_empresa_access(current_user, UUID(str(cliente["empresa_id"])))
    return cliente


# ─── POST /clientes/ ──────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=ClienteRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear cliente",
    description="Los empleados también pueden crear clientes en su empresa.",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def write_cliente(
    request: Request,
    data: ClienteCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    verify_empresa_access(current_user, data.empresa_id)

    if data.identificacion and cliente_identificacion_exists(db, data.empresa_id, data.identificacion):
        raise DuplicateValueException(
            f"La identificación '{data.identificacion}' ya está registrada en esta empresa"
        )
    if data.email and cliente_email_exists(db, data.empresa_id, str(data.email)):
        raise DuplicateValueException(
            f"El email '{data.email}' ya está registrado en esta empresa"
        )

    internal = ClienteCreateInternal(
        **data.model_dump(),
        created_by=UUID(str(current_user["id"])),
    )
    nuevo = create_cliente(db, internal)

    logger.info(
        "Cliente creado | id={id} | nombre={nombre} | empresa={emp} | por={admin}",
        id=nuevo.get("id"),
        nombre=f"{nuevo.get('nombre')} {nuevo.get('apellido') or ''}".strip(),
        emp=str(data.empresa_id),
        admin=current_user.get("email"),
    )
    return nuevo


# ─── PATCH /clientes/{id} ─────────────────────────────────────────────────────

@router.patch("/{cliente_id}", response_model=ClienteRead, summary="Actualizar cliente")
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def patch_cliente(
    request: Request,
    cliente_id: UUID,
    values: ClienteUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    cliente = get_cliente(db, cliente_id)
    if not cliente:
        raise NotFoundException("Cliente no encontrado")
    verify_empresa_access(current_user, UUID(str(cliente["empresa_id"])))

    empresa_id = UUID(str(cliente["empresa_id"]))

    if values.identificacion and values.identificacion.upper() != cliente.get("identificacion"):
        if cliente_identificacion_exists(db, empresa_id, values.identificacion, exclude_id=cliente_id):
            raise DuplicateValueException(f"La identificación '{values.identificacion}' ya existe en esta empresa")

    if values.email and str(values.email).lower() != str(cliente.get("email") or "").lower():
        if cliente_email_exists(db, empresa_id, str(values.email), exclude_id=cliente_id):
            raise DuplicateValueException(f"El email '{values.email}' ya existe en esta empresa")

    internal = ClienteUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
        updated_by=UUID(str(current_user["id"])),
    )
    updated = update_cliente(db, cliente_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar el cliente")

    logger.info("Cliente actualizado | id={id} | por={admin}",
                id=str(cliente_id), admin=current_user.get("email"))
    return updated


# ─── PATCH /clientes/{id}/puntos ──────────────────────────────────────────────

@router.patch(
    "/{cliente_id}/puntos",
    response_model=ClienteRead,
    summary="Ajustar puntos de fidelidad",
    description="Suma puntos (positivo) o canjea puntos (negativo). No puede quedar en negativo.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def patch_puntos(
    request: Request,
    cliente_id: UUID,
    values: PuntosUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    cliente = get_cliente(db, cliente_id)
    if not cliente:
        raise NotFoundException("Cliente no encontrado")
    verify_empresa_access(current_user, UUID(str(cliente["empresa_id"])))

    puntos_actuales = int(cliente.get("puntos_fidelidad", 0))
    if values.puntos < 0 and abs(values.puntos) > puntos_actuales:
        raise BadRequestException(
            f"No hay suficientes puntos para canjear. Disponibles: {puntos_actuales}"
        )

    updated = actualizar_puntos(db, cliente_id, values.puntos)
    if not updated:
        raise NotFoundException("No se pudo actualizar los puntos")

    accion = "sumados" if values.puntos >= 0 else "canjeados"
    logger.info(
        "Puntos {accion} | cliente={id} | puntos={pts} | por={admin}",
        accion=accion, id=str(cliente_id),
        pts=values.puntos, admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /clientes/{id} ── soft delete ─────────────────────────────────────

@router.delete("/{cliente_id}", status_code=status.HTTP_200_OK, summary="Desactivar cliente")
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def delete_cliente(
    request: Request,
    cliente_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    cliente = get_cliente(db, cliente_id)
    if not cliente:
        raise NotFoundException("Cliente no encontrado")
    verify_empresa_access(current_user, UUID(str(cliente["empresa_id"])))

    soft_delete_cliente(db, cliente_id, UUID(str(current_user["id"])))

    nombre = f"{cliente.get('nombre')} {cliente.get('apellido') or ''}".strip()
    logger.warning("Cliente desactivado [soft] | id={id} | nombre={nombre} | por={admin}",
                   id=str(cliente_id), nombre=nombre, admin=current_user.get("email"))
    return {"message": f"Cliente '{nombre}' desactivado correctamente"}


# ─── DELETE /clientes/{id}/hard ───────────────────────────────────────────────

@router.delete(
    "/{cliente_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar cliente permanentemente",
    description="**Solo super_admin.** Fallará si tiene pedidos asociados.",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_cliente_endpoint(
    request: Request,
    cliente_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    cliente = get_cliente(db, cliente_id)
    if not cliente:
        raise NotFoundException("Cliente no encontrado")

    hard_delete_cliente(db, cliente_id)

    nombre = f"{cliente.get('nombre')} {cliente.get('apellido') or ''}".strip()
    logger.warning("Cliente ELIMINADO [hard] | id={id} | nombre={nombre} | por={admin}",
                   id=str(cliente_id), nombre=nombre, admin=current_user.get("email"))
    return {"message": f"Cliente '{nombre}' eliminado permanentemente"}