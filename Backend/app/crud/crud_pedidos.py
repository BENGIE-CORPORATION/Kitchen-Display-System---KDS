"""
CRUD de Pedidos y Detalle de Pedidos.

Reglas clave:
  - Totales del pedido se recalculan desde los ítems.
  - Solo editable en estado 'borrador' o 'abierto'.
  - Al cancelar un ítem, se recalculan los totales del pedido.
  - Al facturar, se vincula la sesión de caja y se actualizan stats del cliente.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.pedido import SORTABLE_COLUMNS, TABLE_DETALLE, TABLE_NAME, TRANSICIONES_PEDIDO
from ..schemas.auditoria import HistorialEstadoPedidoCreate, HistorialEstadetalleCreate
from ..schemas.pedido import (
    DetallePedidoCreate,
    DetallePedidoUpdate,
    PedidoCreate,
    PedidoEstadoUpdate,
    PedidoUpdate,
)


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order(column: str) -> str:
    return column if column in SORTABLE_COLUMNS else "created_at"


def _serialize(payload: dict) -> dict:
    result = {}
    for key, value in payload.items():
        if isinstance(value, UUID):
            result[key] = str(value)
        elif isinstance(value, Decimal):
            result[key] = float(value)
        elif isinstance(value, datetime):
            result[key] = value.isoformat()
        else:
            result[key] = value
    return result


def _calcular_totales(items: list[dict]) -> dict:
    """Recalcula totales del pedido desde los ítems activos (no cancelados)."""
    activos = [i for i in items if i.get("estado") != "cancelado"]
    subtotal  = sum(Decimal(str(i.get("subtotal", 0))) for i in activos)
    total_iva = sum(Decimal(str(i.get("iva", 0))) for i in activos)
    total_srv = sum(Decimal(str(i.get("servicio", 0))) for i in activos)
    total     = sum(Decimal(str(i.get("total", 0))) for i in activos)
    return {
        "subtotal":       float(subtotal),
        "total_iva":      float(total_iva),
        "total_servicio": float(total_srv),
        "total":          float(total),
    }


def _recalcular_totales_pedido(db: Client, pedido_id: UUID) -> None:
    items = (
        db.table(TABLE_DETALLE)
        .select("subtotal, iva, servicio, total, estado")
        .eq("pedido_id", str(pedido_id))
        .execute()
        .data
    )
    totales = _calcular_totales(items)
    totales["updated_at"] = _now()
    db.table(TABLE_NAME).update(totales).eq("id", str(pedido_id)).execute()


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def numero_pedido_exists(
    db: Client, sucursal_id: UUID, numero_pedido: str, exclude_id: UUID | None = None
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("sucursal_id", str(sucursal_id))
        .eq("numero_pedido", numero_pedido)
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_pedido(db: Client, data: PedidoCreate, created_by: UUID) -> dict:
    items_data = [_serialize(item.model_dump()) for item in data.items]
    totales = _calcular_totales(items_data)

    pedido_payload = _serialize(data.model_dump(exclude={"items"}))
    pedido_payload.update({
        "estado": "borrador",
        "estado_pago": "pendiente",
        "estado_cocina": "pendiente",
        "created_by": str(created_by),
        "updated_by": str(created_by),
        "descuento_porcentaje": pedido_payload.get("descuento_porcentaje", 0),
        "descuento_monto": pedido_payload.get("descuento_monto", 0),
        "propina": pedido_payload.get("propina", 0),
        **totales,
    })

    pedido = db.table(TABLE_NAME).insert(pedido_payload).execute().data[0]
    pedido_id = pedido["id"]

    for item in items_data:
        item["pedido_id"] = pedido_id
        item["estado"] = "pendiente"
        item["created_by"] = str(created_by)
        # Calcular utilidad si hay costo
        if item.get("costo_unitario") and item.get("cantidad"):
            costo_total = float(Decimal(str(item["costo_unitario"])) * Decimal(str(item["cantidad"])))
            item["costo_total"] = costo_total
            item["utilidad"] = float(Decimal(str(item.get("total", 0))) - Decimal(str(costo_total)))

    db.table(TABLE_DETALLE).insert(items_data).execute()
    return pedido


# ─── READ ONE ─────────────────────────────────────────────────────────────────

def get_pedido(db: Client, pedido_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(pedido_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_pedido_con_detalle(db: Client, pedido_id: UUID) -> dict | None:
    pedido = get_pedido(db, pedido_id)
    if not pedido:
        return None
    items = (
        db.table(TABLE_DETALLE)
        .select("*")
        .eq("pedido_id", str(pedido_id))
        .execute()
        .data
    )
    pedido["items"] = items
    return pedido


# ─── READ MANY ────────────────────────────────────────────────────────────────

def get_pedidos(
    db: Client,
    empresa_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "fecha_pedido",
    order_desc: bool = True,
    sucursal_id: UUID | None = None,
    estado: str | None = None,
    estado_pago: str | None = None,
    estado_cocina: str | None = None,
    tipo_pedido: str | None = None,
    cliente_id: UUID | None = None,
    mesa_id: UUID | None = None,
    fecha_desde: datetime | None = None,
    fecha_hasta: datetime | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_NAME)
        .select("*", count="exact")
        .eq("empresa_id", str(empresa_id))
    )

    if sucursal_id:
        query = query.eq("sucursal_id", str(sucursal_id))
    if estado:
        query = query.eq("estado", estado)
    if estado_pago:
        query = query.eq("estado_pago", estado_pago)
    if estado_cocina:
        query = query.eq("estado_cocina", estado_cocina)
    if tipo_pedido:
        query = query.eq("tipo_pedido", tipo_pedido)
    if cliente_id:
        query = query.eq("cliente_id", str(cliente_id))
    if mesa_id:
        query = query.eq("mesa_id", str(mesa_id))
    if fecha_desde:
        query = query.gte("fecha_pedido", fecha_desde.isoformat())
    if fecha_hasta:
        query = query.lte("fecha_pedido", fecha_hasta.isoformat())

    result = (
        query
        .order(_safe_order(order_by), desc=order_desc)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )

    return paginated_response(
        data=result.data,
        total=result.count or 0,
        page=page,
        items_per_page=items_per_page,
    )


# ─── UPDATE PEDIDO ────────────────────────────────────────────────────────────

def update_pedido(
    db: Client, pedido_id: UUID, data: PedidoUpdate, updated_by: UUID
) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    payload["updated_at"] = _now()
    payload["updated_by"] = str(updated_by)
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(pedido_id))
        .execute()
    )
    updated = result.data[0] if result.data else None

    # Registrar en historial automáticamente
    if updated:
        try:
            from .crud_auditoria import registrar_cambio_estado_pedido
            registrar_cambio_estado_pedido(db, HistorialEstadoPedidoCreate(
                pedido_id=pedido_id,
                estado_anterior=updated.get("estado") if data.estado == updated.get("estado") else data.estado,
                estado_nuevo=data.estado,
                campo_modificado="estado",
                created_by=updated_by,
            ))
        except Exception:
            pass  # el historial no debe bloquear la operación principal

    return updated


# ─── CAMBIO DE ESTADO ─────────────────────────────────────────────────────────

def cambiar_estado_pedido(
    db: Client, pedido_id: UUID, data: PedidoEstadoUpdate, updated_by: UUID
) -> dict | None:
    payload: dict = {
        "estado": data.estado,
        "updated_at": _now(),
        "updated_by": str(updated_by),
    }

    if data.estado == "cancelado":
        payload["motivo_cancelacion"] = data.motivo_cancelacion

    if data.estado == "facturado":
        payload["sesion_caja_id"] = str(data.sesion_caja_id)
        payload["fecha_facturacion"] = _now()
        if data.estado_pago:
            payload["estado_pago"] = data.estado_pago

    if data.estado == "entregado":
        payload["fecha_entrega"] = _now()

    if data.estado_cocina:
        payload["estado_cocina"] = data.estado_cocina

    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(pedido_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── DETALLE ─────────────────────────────────────────────────────────────────

def get_detalle_item(db: Client, item_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_DETALLE)
        .select("*")
        .eq("id", str(item_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def add_detalle_item(
    db: Client, pedido_id: UUID, data: DetallePedidoCreate, created_by: UUID
) -> dict:
    payload = _serialize(data.model_dump())
    payload["pedido_id"] = str(pedido_id)
    payload["estado"] = "pendiente"
    payload["created_by"] = str(created_by)
    if payload.get("costo_unitario") and payload.get("cantidad"):
        costo_total = float(Decimal(str(payload["costo_unitario"])) * Decimal(str(payload["cantidad"])))
        payload["costo_total"] = costo_total
        payload["utilidad"] = float(Decimal(str(payload.get("total", 0))) - Decimal(str(costo_total)))

    result = db.table(TABLE_DETALLE).insert(payload).execute()
    item = result.data[0]
    _recalcular_totales_pedido(db, pedido_id)
    return item


def update_detalle_item(
    db: Client, item_id: UUID, data: DetallePedidoUpdate, pedido_id: UUID, updated_by: UUID
) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    payload["updated_at"] = _now()
    payload["updated_by"] = str(updated_by)
    result = (
        db.table(TABLE_DETALLE)
        .update(payload)
        .eq("id", str(item_id))
        .execute()
    )
    item = result.data[0] if result.data else None
    if item:
        _recalcular_totales_pedido(db, pedido_id)
        try:
            from .crud_auditoria import registrar_cambio_estado_detalle
            registrar_cambio_estado_detalle(db, HistorialEstadetalleCreate(
                detalle_pedido_id=item_id,
                estado_anterior="activo",
                estado_nuevo="cancelado",
                notas=motivo,
                created_by=cancelado_por,
            ))
        except Exception:
            pass
    return item


def cancelar_detalle_item(
    db: Client, item_id: UUID, pedido_id: UUID, motivo: str, cancelado_por: UUID
) -> dict | None:
    payload = {
        "estado": "cancelado",
        "motivo_cancelacion": motivo,
        "fecha_cancelacion": _now(),
        "cancelado_por": str(cancelado_por),
        "updated_at": _now(),
        "updated_by": str(cancelado_por),
    }
    result = (
        db.table(TABLE_DETALLE)
        .update(payload)
        .eq("id", str(item_id))
        .execute()
    )
    item = result.data[0] if result.data else None
    if item:
        _recalcular_totales_pedido(db, pedido_id)
    return item


# ─── HARD DELETE ─────────────────────────────────────────────────────────────

def hard_delete_pedido(db: Client, pedido_id: UUID) -> bool:
    result = db.table(TABLE_NAME).delete().eq("id", str(pedido_id)).execute()
    return len(result.data) > 0