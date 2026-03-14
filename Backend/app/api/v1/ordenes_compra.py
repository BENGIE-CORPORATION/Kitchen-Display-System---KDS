"""
Router de Órdenes de Compra — solo lógica HTTP.

Reglas de negocio:
  - Solo se puede editar una orden en estado 'borrador'
  - Los totales se recalculan automáticamente al modificar ítems
  - Las transiciones de estado siguen un flujo estricto:
    borrador → enviada → confirmada → parcial → recibida
    Cualquier estado → cancelada (excepto recibida y cancelada)

Seguridad:
  GET    /ordenes-compra/                    → admin_empresa o super_admin
  GET    /ordenes-compra/{id}                → admin_empresa o super_admin
  GET    /ordenes-compra/{id}/detalle        → admin_empresa o super_admin
  POST   /ordenes-compra/                    → admin_empresa o super_admin
  PATCH  /ordenes-compra/{id}                → admin_empresa o super_admin (solo borrador)
  PATCH  /ordenes-compra/{id}/estado         → admin_empresa o super_admin
  DELETE /ordenes-compra/{id}                → admin_empresa o super_admin (cancela)
  DELETE /ordenes-compra/{id}/hard           → solo super_admin

  --- Ítems del detalle ---
  POST   /ordenes-compra/{id}/items          → admin_empresa (solo borrador)
  PATCH  /ordenes-compra/{id}/items/{item_id} → admin_empresa (solo borrador)
  DELETE /ordenes-compra/{id}/items/{item_id} → admin_empresa (solo borrador)
  PATCH  /ordenes-compra/{id}/items/{item_id}/recepcion → admin_empresa
"""

from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, status
from loguru import logger
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    ForbiddenException,
    NotFoundException,
)
from ...core.limiter import get_user_id_from_token, limiter
from ...core.pagination import PaginatedResponse
from ...core.security import (
    get_current_admin,
    get_current_superadmin,
    verify_empresa_access,
    verify_sucursal_access,
)
from ...crud.crud_ordenes_compra import (
    add_detalle_item,
    cancelar_orden,
    cambiar_estado_orden,
    create_orden_compra,
    delete_detalle_item,
    get_detalle_item,
    get_orden_compra,
    get_orden_compra_con_detalle,
    get_ordenes_compra,
    hard_delete_orden,
    numero_orden_exists,
    registrar_recepcion_item,
    update_detalle_item,
    update_orden_compra,
)
from ...crud.crud_proveedores import get_proveedor
from ...crud.crud_sucursales import get_sucursal
from ...database import get_supabase
from ...models.orden_compra import TRANSICIONES_ESTADO
from ...schemas.orden_compra import (
    DetalleOrdenCreate,
    DetalleOrdenRead,
    DetalleOrdenRecepcion,
    DetalleOrdenUpdate,
    OrdenCompraCreate,
    OrdenCompraEstadoUpdate,
    OrdenCompraRead,
    OrdenCompraReadDetalle,
    OrdenCompraUpdate,
)

router = APIRouter(prefix="/ordenes-compra", tags=["Órdenes de Compra"])


def _verificar_estado_borrador(orden: dict) -> None:
    if orden["estado"] != "borrador":
        raise BadRequestException(
            f"La orden está en estado '{orden['estado']}'. "
            "Solo se puede modificar en estado 'borrador'."
        )


def _verificar_transicion(estado_actual: str, nuevo_estado: str) -> None:
    permitidos = TRANSICIONES_ESTADO.get(estado_actual, set())
    if nuevo_estado not in permitidos:
        raise BadRequestException(
            f"No se puede cambiar de '{estado_actual}' a '{nuevo_estado}'. "
            f"Transiciones permitidas: {', '.join(permitidos) or 'ninguna (estado final)'}."
        )


# ─── GET /ordenes-compra/ ─────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[OrdenCompraRead],
    summary="Listar órdenes de compra",
)
def read_ordenes(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "fecha_orden",
    order_desc: bool = True,
    sucursal_id: UUID | None = None,
    proveedor_id: UUID | None = None,
    estado: str | None = None,
    fecha_desde: datetime | None = None,
    fecha_hasta: datetime | None = None,
    empresa_id: UUID | None = None,
) -> dict:
    if current_user["rol_global"] == "super_admin":
        if not empresa_id:
            raise BadRequestException("super_admin debe especificar empresa_id como query param")
        target = empresa_id
    else:
        target = UUID(str(current_user["empresa_id"]))

    return get_ordenes_compra(
        db=db, empresa_id=target, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc, sucursal_id=sucursal_id,
        proveedor_id=proveedor_id, estado=estado,
        fecha_desde=fecha_desde, fecha_hasta=fecha_hasta,
    )


# ─── GET /ordenes-compra/{id} ─────────────────────────────────────────────────

@router.get("/{orden_id}", response_model=OrdenCompraRead, summary="Obtener orden")
def read_orden(
    orden_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    orden = get_orden_compra(db, orden_id)
    if not orden:
        raise NotFoundException("Orden de compra no encontrada")
    verify_empresa_access(current_user, UUID(str(orden["empresa_id"])))
    return orden


# ─── GET /ordenes-compra/{id}/detalle ─────────────────────────────────────────

@router.get(
    "/{orden_id}/detalle",
    response_model=OrdenCompraReadDetalle,
    summary="Obtener orden con ítems",
)
def read_orden_detalle(
    orden_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    orden = get_orden_compra_con_detalle(db, orden_id)
    if not orden:
        raise NotFoundException("Orden de compra no encontrada")
    verify_empresa_access(current_user, UUID(str(orden["empresa_id"])))
    return orden


# ─── POST /ordenes-compra/ ────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=OrdenCompraRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear orden de compra",
    description="Crea la orden en estado 'borrador' con sus ítems. Los totales se calculan automáticamente.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def write_orden(
    request: Request,
    data: OrdenCompraCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    verify_empresa_access(current_user, data.empresa_id)

    sucursal = get_sucursal(db, data.sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")
    if str(sucursal["empresa_id"]) != str(data.empresa_id):
        raise BadRequestException("La sucursal no pertenece a esta empresa")

    proveedor = get_proveedor(db, data.proveedor_id)
    if not proveedor:
        raise NotFoundException("Proveedor no encontrado")
    if str(proveedor["empresa_id"]) != str(data.empresa_id):
        raise BadRequestException("El proveedor no pertenece a esta empresa")
    if proveedor["estado"] == "bloqueado":
        raise BadRequestException(
            f"El proveedor '{proveedor['nombre_legal']}' está bloqueado. No se pueden crear órdenes."
        )

    if numero_orden_exists(db, data.sucursal_id, data.numero_orden):
        raise DuplicateValueException(
            f"El número de orden '{data.numero_orden}' ya existe en esta sucursal"
        )

    nueva = create_orden_compra(db, data, created_by=UUID(str(current_user["id"])))

    logger.info(
        "Orden de compra creada | id={id} | numero={num} | proveedor={prov} | total={total} | por={admin}",
        id=nueva.get("id"),
        num=nueva.get("numero_orden"),
        prov=proveedor.get("nombre_legal"),
        total=nueva.get("total"),
        admin=current_user.get("email"),
    )
    return nueva


# ─── PATCH /ordenes-compra/{id} ───────────────────────────────────────────────

@router.patch(
    "/{orden_id}",
    response_model=OrdenCompraRead,
    summary="Actualizar orden",
    description="Solo editable en estado 'borrador'.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def patch_orden(
    request: Request,
    orden_id: UUID,
    values: OrdenCompraUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    orden = get_orden_compra(db, orden_id)
    if not orden:
        raise NotFoundException("Orden de compra no encontrada")
    verify_empresa_access(current_user, UUID(str(orden["empresa_id"])))
    _verificar_estado_borrador(orden)

    if values.numero_orden and values.numero_orden.upper() != orden.get("numero_orden"):
        if numero_orden_exists(db, UUID(str(orden["sucursal_id"])), values.numero_orden, exclude_id=orden_id):
            raise DuplicateValueException(f"El número '{values.numero_orden}' ya existe en esta sucursal")

    updated = update_orden_compra(db, orden_id, values, UUID(str(current_user["id"])))
    if not updated:
        raise NotFoundException("No se pudo actualizar la orden")

    logger.info(
        "Orden actualizada | id={id} | por={admin}",
        id=str(orden_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── PATCH /ordenes-compra/{id}/estado ───────────────────────────────────────

@router.patch(
    "/{orden_id}/estado",
    response_model=OrdenCompraRead,
    summary="Cambiar estado de la orden",
    description="Valida que la transición de estado sea permitida según el flujo definido.",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)
def patch_estado_orden(
    request: Request,
    orden_id: UUID,
    values: OrdenCompraEstadoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    orden = get_orden_compra(db, orden_id)
    if not orden:
        raise NotFoundException("Orden de compra no encontrada")
    verify_empresa_access(current_user, UUID(str(orden["empresa_id"])))

    _verificar_transicion(orden["estado"], values.estado)

    # Al recibir, la fecha de entrega real es obligatoria
    if values.estado == "recibida" and not values.fecha_entrega_real:
        raise BadRequestException(
            "Se requiere 'fecha_entrega_real' al marcar la orden como recibida"
        )

    updated = cambiar_estado_orden(
        db, orden_id,
        nuevo_estado=values.estado,
        updated_by=UUID(str(current_user["id"])),
        fecha_entrega_real=values.fecha_entrega_real,
        notas=values.notas,
    )

    logger.warning(
        "Estado de orden cambiado | id={id} | {anterior} → {nuevo} | por={admin}",
        id=str(orden_id),
        anterior=orden["estado"],
        nuevo=values.estado,
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /ordenes-compra/{id} ── cancelar ─────────────────────────────────

@router.delete(
    "/{orden_id}",
    status_code=status.HTTP_200_OK,
    summary="Cancelar orden",
    description="Cancela la orden. Estado final — no se puede revertir.",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def delete_orden(
    request: Request,
    orden_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    orden = get_orden_compra(db, orden_id)
    if not orden:
        raise NotFoundException("Orden de compra no encontrada")
    verify_empresa_access(current_user, UUID(str(orden["empresa_id"])))
    _verificar_transicion(orden["estado"], "cancelada")

    cancelar_orden(db, orden_id, UUID(str(current_user["id"])))

    logger.warning(
        "Orden cancelada | id={id} | numero={num} | por={admin}",
        id=str(orden_id),
        num=orden.get("numero_orden"),
        admin=current_user.get("email"),
    )
    return {"message": f"Orden '{orden['numero_orden']}' cancelada"}


# ─── DELETE /ordenes-compra/{id}/hard ─────────────────────────────────────────

@router.delete(
    "/{orden_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar orden permanentemente",
    description="**Solo super_admin.** Solo permitido en estado 'borrador' o 'cancelada'.",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_orden_endpoint(
    request: Request,
    orden_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    orden = get_orden_compra(db, orden_id)
    if not orden:
        raise NotFoundException("Orden de compra no encontrada")
    if orden["estado"] not in ("borrador", "cancelada"):
        raise BadRequestException(
            f"Solo se pueden eliminar órdenes en estado 'borrador' o 'cancelada'. "
            f"Estado actual: '{orden['estado']}'"
        )

    hard_delete_orden(db, orden_id)

    logger.warning(
        "Orden ELIMINADA [hard] | id={id} | numero={num} | por={admin}",
        id=str(orden_id),
        num=orden.get("numero_orden"),
        admin=current_user.get("email"),
    )
    return {"message": f"Orden '{orden['numero_orden']}' eliminada permanentemente"}


# ─── POST /ordenes-compra/{id}/items ──────────────────────────────────────────

@router.post(
    "/{orden_id}/items",
    response_model=DetalleOrdenRead,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar ítem a la orden",
    description="Solo en estado 'borrador'. Los totales se recalculan automáticamente.",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def add_item(
    request: Request,
    orden_id: UUID,
    data: DetalleOrdenCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    orden = get_orden_compra(db, orden_id)
    if not orden:
        raise NotFoundException("Orden de compra no encontrada")
    verify_empresa_access(current_user, UUID(str(orden["empresa_id"])))
    _verificar_estado_borrador(orden)

    item = add_detalle_item(db, orden_id, data)

    logger.info(
        "Ítem agregado a orden | orden={orden} | por={admin}",
        orden=str(orden_id),
        admin=current_user.get("email"),
    )
    return item


# ─── PATCH /ordenes-compra/{id}/items/{item_id} ───────────────────────────────

@router.patch(
    "/{orden_id}/items/{item_id}",
    response_model=DetalleOrdenRead,
    summary="Actualizar ítem de la orden",
    description="Solo en estado 'borrador'. Los totales se recalculan automáticamente.",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def patch_item(
    request: Request,
    orden_id: UUID,
    item_id: UUID,
    values: DetalleOrdenUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    orden = get_orden_compra(db, orden_id)
    if not orden:
        raise NotFoundException("Orden de compra no encontrada")
    verify_empresa_access(current_user, UUID(str(orden["empresa_id"])))
    _verificar_estado_borrador(orden)

    item = get_detalle_item(db, item_id)
    if not item:
        raise NotFoundException("Ítem no encontrado")
    if str(item["orden_compra_id"]) != str(orden_id):
        raise NotFoundException("El ítem no pertenece a esta orden")

    updated = update_detalle_item(db, item_id, values, orden_id)
    if not updated:
        raise NotFoundException("No se pudo actualizar el ítem")
    return updated


# ─── DELETE /ordenes-compra/{id}/items/{item_id} ──────────────────────────────

@router.delete(
    "/{orden_id}/items/{item_id}",
    status_code=status.HTTP_200_OK,
    summary="Eliminar ítem de la orden",
    description="Solo en estado 'borrador'. Los totales se recalculan automáticamente.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def delete_item(
    request: Request,
    orden_id: UUID,
    item_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    orden = get_orden_compra(db, orden_id)
    if not orden:
        raise NotFoundException("Orden de compra no encontrada")
    verify_empresa_access(current_user, UUID(str(orden["empresa_id"])))
    _verificar_estado_borrador(orden)

    item = get_detalle_item(db, item_id)
    if not item:
        raise NotFoundException("Ítem no encontrado")
    if str(item["orden_compra_id"]) != str(orden_id):
        raise NotFoundException("El ítem no pertenece a esta orden")

    delete_detalle_item(db, item_id, orden_id)

    logger.info(
        "Ítem eliminado de orden | orden={orden} | item={item} | por={admin}",
        orden=str(orden_id),
        item=str(item_id),
        admin=current_user.get("email"),
    )
    return {"message": "Ítem eliminado. Totales recalculados."}


# ─── PATCH /ordenes-compra/{id}/items/{item_id}/recepcion ─────────────────────

@router.patch(
    "/{orden_id}/items/{item_id}/recepcion",
    response_model=DetalleOrdenRead,
    summary="Registrar recepción de un ítem",
    description="Actualiza la cantidad recibida de un ítem. Válido en estados 'confirmada' y 'parcial'.",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def patch_recepcion_item(
    request: Request,
    orden_id: UUID,
    item_id: UUID,
    values: DetalleOrdenRecepcion,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    orden = get_orden_compra(db, orden_id)
    if not orden:
        raise NotFoundException("Orden de compra no encontrada")
    verify_empresa_access(current_user, UUID(str(orden["empresa_id"])))

    if orden["estado"] not in ("confirmada", "parcial"):
        raise BadRequestException(
            f"Solo se puede registrar recepción en órdenes 'confirmada' o 'parcial'. "
            f"Estado actual: '{orden['estado']}'"
        )

    item = get_detalle_item(db, item_id)
    if not item:
        raise NotFoundException("Ítem no encontrado")
    if str(item["orden_compra_id"]) != str(orden_id):
        raise NotFoundException("El ítem no pertenece a esta orden")

    if values.cantidad_recibida > item["cantidad_solicitada"]:
        raise BadRequestException(
            f"La cantidad recibida ({values.cantidad_recibida}) no puede superar "
            f"la solicitada ({item['cantidad_solicitada']})"
        )

    updated = registrar_recepcion_item(db, item_id, values.cantidad_recibida, orden_id)

    logger.info(
        "Recepción registrada | orden={orden} | item={item} | cantidad={qty} | por={admin}",
        orden=str(orden_id),
        item=str(item_id),
        qty=str(values.cantidad_recibida),
        admin=current_user.get("email"),
    )
    return updated