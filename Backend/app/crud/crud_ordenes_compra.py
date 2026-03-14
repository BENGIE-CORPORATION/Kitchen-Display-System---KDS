"""
CRUD de Órdenes de Compra y su detalle.
Las órdenes solo son editables en estado 'borrador'.
Los totales se recalculan automáticamente al modificar ítems.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.orden_compra import SORTABLE_COLUMNS, TABLE_DETALLE, TABLE_NAME
from ..schemas.orden_compra import (
    DetalleOrdenCreate,
    DetalleOrdenUpdate,
    OrdenCompraCreate,
    OrdenCompraUpdate,
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
    """Recalcula subtotal, impuestos, descuentos y total desde los ítems."""
    subtotal = sum(Decimal(str(i.get("subtotal", 0))) for i in items)
    impuestos = sum(Decimal(str(i.get("impuesto_monto", 0))) for i in items)
    descuentos = sum(Decimal(str(i.get("descuento_monto", 0))) for i in items)
    total = subtotal + impuestos - descuentos
    return {
        "subtotal": float(subtotal),
        "impuestos": float(impuestos),
        "descuentos": float(descuentos),
        "total": float(total),
    }


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def numero_orden_exists(
    db: Client,
    sucursal_id: UUID,
    numero_orden: str,
    exclude_id: UUID | None = None,
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("sucursal_id", str(sucursal_id))
        .eq("numero_orden", numero_orden.upper())
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_orden_compra(
    db: Client,
    data: OrdenCompraCreate,
    created_by: UUID,
) -> dict:
    """
    Crea la orden y sus ítems en dos operaciones.
    Los totales se calculan desde los ítems provistos.
    """
    items_data = [_serialize(item.model_dump()) for item in data.items]
    totales = _calcular_totales(items_data)

    orden_payload = _serialize(data.model_dump(exclude={"items"}))
    orden_payload.update({
        "estado": "borrador",
        "created_by": str(created_by),
        "updated_by": str(created_by),
        **totales,
    })

    orden = db.table(TABLE_NAME).insert(orden_payload).execute().data[0]
    orden_id = orden["id"]

    # Insertar ítems con el orden_compra_id
    for item in items_data:
        item["orden_compra_id"] = orden_id
        item["cantidad_recibida"] = 0
    db.table(TABLE_DETALLE).insert(items_data).execute()

    return orden


# ─── READ ONE ─────────────────────────────────────────────────────────────────

def get_orden_compra(db: Client, orden_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(orden_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_orden_compra_con_detalle(db: Client, orden_id: UUID) -> dict | None:
    """Retorna la orden con todos sus ítems."""
    orden = get_orden_compra(db, orden_id)
    if not orden:
        return None
    items = (
        db.table(TABLE_DETALLE)
        .select("*")
        .eq("orden_compra_id", str(orden_id))
        .execute()
        .data
    )
    orden["items"] = items
    return orden


# ─── READ MANY ────────────────────────────────────────────────────────────────

def get_ordenes_compra(
    db: Client,
    empresa_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "fecha_orden",
    order_desc: bool = True,
    sucursal_id: UUID | None = None,
    proveedor_id: UUID | None = None,
    estado: str | None = None,
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
    if proveedor_id:
        query = query.eq("proveedor_id", str(proveedor_id))
    if estado:
        query = query.eq("estado", estado)
    if fecha_desde:
        query = query.gte("fecha_orden", fecha_desde.isoformat())
    if fecha_hasta:
        query = query.lte("fecha_orden", fecha_hasta.isoformat())

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


# ─── UPDATE ORDEN (solo borrador) ────────────────────────────────────────────

def update_orden_compra(
    db: Client, orden_id: UUID, data: OrdenCompraUpdate, updated_by: UUID
) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    payload["updated_at"] = _now()
    payload["updated_by"] = str(updated_by)
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(orden_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── CAMBIO DE ESTADO ────────────────────────────────────────────────────────

def cambiar_estado_orden(
    db: Client,
    orden_id: UUID,
    nuevo_estado: str,
    updated_by: UUID,
    fecha_entrega_real: datetime | None = None,
    notas: str | None = None,
) -> dict | None:
    payload: dict = {
        "estado": nuevo_estado,
        "updated_at": _now(),
        "updated_by": str(updated_by),
    }
    if fecha_entrega_real:
        payload["fecha_entrega_real"] = fecha_entrega_real.isoformat()
    if notas:
        payload["notas"] = notas
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(orden_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── DETALLE — CRUD ──────────────────────────────────────────────────────────

def get_detalle_item(db: Client, item_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_DETALLE)
        .select("*")
        .eq("id", str(item_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def add_detalle_item(db: Client, orden_id: UUID, data: DetalleOrdenCreate) -> dict:
    payload = _serialize(data.model_dump())
    payload["orden_compra_id"] = str(orden_id)
    payload["cantidad_recibida"] = 0
    result = db.table(TABLE_DETALLE).insert(payload).execute()
    item = result.data[0]
    _recalcular_totales_orden(db, orden_id)
    return item


def update_detalle_item(
    db: Client, item_id: UUID, data: DetalleOrdenUpdate, orden_id: UUID
) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    result = (
        db.table(TABLE_DETALLE)
        .update(payload)
        .eq("id", str(item_id))
        .execute()
    )
    item = result.data[0] if result.data else None
    if item:
        _recalcular_totales_orden(db, orden_id)
    return item


def delete_detalle_item(db: Client, item_id: UUID, orden_id: UUID) -> bool:
    result = (
        db.table(TABLE_DETALLE)
        .delete()
        .eq("id", str(item_id))
        .execute()
    )
    if result.data:
        _recalcular_totales_orden(db, orden_id)
    return len(result.data) > 0


def registrar_recepcion_item(
    db: Client, item_id: UUID, cantidad_recibida: Decimal, orden_id: UUID
) -> dict | None:
    """Acumula la cantidad recibida en un ítem."""
    result = (
        db.table(TABLE_DETALLE)
        .update({"cantidad_recibida": float(cantidad_recibida)})
        .eq("id", str(item_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── HELPERS INTERNOS ────────────────────────────────────────────────────────

def _recalcular_totales_orden(db: Client, orden_id: UUID) -> None:
    """Recalcula y persiste los totales de la orden desde sus ítems actuales."""
    items = (
        db.table(TABLE_DETALLE)
        .select("subtotal, impuesto_monto, descuento_monto")
        .eq("orden_compra_id", str(orden_id))
        .execute()
        .data
    )
    totales = _calcular_totales(items)
    totales["updated_at"] = _now()
    db.table(TABLE_NAME).update(totales).eq("id", str(orden_id)).execute()


# ─── SOFT / HARD DELETE ──────────────────────────────────────────────────────

def cancelar_orden(db: Client, orden_id: UUID, updated_by: UUID, motivo: str | None = None) -> dict | None:
    """Cancelar es el soft delete de órdenes — estado final, no se puede revertir."""
    payload: dict = {
        "estado": "cancelada",
        "updated_at": _now(),
        "updated_by": str(updated_by),
    }
    if motivo:
        payload["notas"] = motivo
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(orden_id))
        .execute()
    )
    return result.data[0] if result.data else None


def hard_delete_orden(db: Client, orden_id: UUID) -> bool:
    """Elimina físicamente la orden y su detalle en cascada."""
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(orden_id))
        .execute()
    )
    return len(result.data) > 0