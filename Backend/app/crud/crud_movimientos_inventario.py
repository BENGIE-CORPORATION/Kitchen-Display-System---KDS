"""
CRUD de Movimientos de Inventario y su detalle.

Reglas clave:
  - Los movimientos en estado 'borrador' son editables.
  - Al completar un movimiento, el stock de productos_sucursales se actualiza.
  - Al cancelar, el stock NO se revierte automáticamente — requiere un movimiento inverso.
  - total_costo se recalcula desde los ítems.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.movimiento_inventario import (
    SORTABLE_COLUMNS,
    TABLE_DETALLE,
    TABLE_NAME,
    TIPOS_ENTRADA,
)
from ..schemas.movimiento_inventario import (
    DetalleMovimientoCreate,
    MovimientoInventarioCreate,
    MovimientoInventarioUpdate,
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


def _calcular_total_costo(items: list[dict]) -> float:
    return float(sum(Decimal(str(i.get("costo_total") or 0)) for i in items))


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def numero_movimiento_exists(
    db: Client,
    empresa_id: UUID,
    numero_movimiento: str,
    exclude_id: UUID | None = None,
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("empresa_id", str(empresa_id))
        .eq("numero_movimiento", numero_movimiento.upper())
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_movimiento(
    db: Client,
    data: MovimientoInventarioCreate,
    usuario_responsable: UUID,
) -> dict:
    items_data = [_serialize(item.model_dump()) for item in data.items]
    total_costo = _calcular_total_costo(items_data)

    mov_payload = _serialize(data.model_dump(exclude={"items"}))
    mov_payload.update({
        "estado": "borrador",
        "total_costo": total_costo,
        "usuario_responsable": str(usuario_responsable),
        "created_by": str(usuario_responsable),
    })

    movimiento = db.table(TABLE_NAME).insert(mov_payload).execute().data[0]
    mov_id = movimiento["id"]

    for item in items_data:
        item["movimiento_id"] = mov_id
    db.table(TABLE_DETALLE).insert(items_data).execute()

    return movimiento


# ─── READ ONE ─────────────────────────────────────────────────────────────────

def get_movimiento(db: Client, movimiento_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(movimiento_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_movimiento_con_detalle(db: Client, movimiento_id: UUID) -> dict | None:
    movimiento = get_movimiento(db, movimiento_id)
    if not movimiento:
        return None
    items = (
        db.table(TABLE_DETALLE)
        .select("*")
        .eq("movimiento_id", str(movimiento_id))
        .execute()
        .data
    )
    movimiento["items"] = items
    return movimiento


# ─── READ MANY ────────────────────────────────────────────────────────────────

def get_movimientos(
    db: Client,
    empresa_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "fecha_movimiento",
    order_desc: bool = True,
    sucursal_id: UUID | None = None,
    tipo_movimiento: str | None = None,
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
    if tipo_movimiento:
        query = query.eq("tipo_movimiento", tipo_movimiento)
    if estado:
        query = query.eq("estado", estado)
    if fecha_desde:
        query = query.gte("fecha_movimiento", fecha_desde.isoformat())
    if fecha_hasta:
        query = query.lte("fecha_movimiento", fecha_hasta.isoformat())

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


# ─── UPDATE (solo borrador) ───────────────────────────────────────────────────

def update_movimiento(
    db: Client, movimiento_id: UUID, data: MovimientoInventarioUpdate
) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    payload["updated_at"] = _now()
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(movimiento_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── COMPLETAR MOVIMIENTO ─────────────────────────────────────────────────────

def _actualizar_stock_producto(
    db: Client, sucursal_id: str, producto_id: str, cantidad: Decimal, es_entrada: bool
) -> None:
    """Actualiza stock_disponible en productos_sucursales."""
    result = (
        db.table("productos_sucursales")
        .select("id, stock_disponible")
        .eq("producto_id", producto_id)
        .eq("sucursal_id", sucursal_id)
        .limit(1)
        .execute()
    )
    if not result.data:
        return  # producto no configurado en la sucursal — omitir

    ps = result.data[0]
    stock_actual = Decimal(str(ps["stock_disponible"]))
    nuevo_stock = stock_actual + cantidad if es_entrada else max(Decimal("0"), stock_actual - cantidad)

    db.table("productos_sucursales").update({
        "stock_disponible": float(nuevo_stock),
        "updated_at": _now(),
    }).eq("id", ps["id"]).execute()


def _actualizar_stock_materia_prima(
    db: Client, sucursal_id: str, materia_prima_id: str, cantidad: Decimal, es_entrada: bool, costo_unitario: Decimal | None
) -> None:
    """
    Actualiza stock_actual en materias_primas_sucursales.
    En entradas recalcula costo_promedio usando promedio ponderado:
      costo_promedio = (stock_anterior * costo_anterior + cantidad * costo_nuevo) / stock_nuevo
    """
    result = (
        db.table("materias_primas_sucursales")
        .select("id, stock_actual, costo_promedio")
        .eq("materia_prima_id", materia_prima_id)
        .eq("sucursal_id", sucursal_id)
        .limit(1)
        .execute()
    )
    if not result.data:
        return  # materia prima no configurada en la sucursal — omitir

    mps = result.data[0]
    stock_actual = Decimal(str(mps["stock_actual"]))
    costo_promedio_actual = Decimal(str(mps["costo_promedio"] or 0))

    payload: dict = {"updated_at": _now()}

    if es_entrada:
        nuevo_stock = stock_actual + cantidad
        # Recalcular costo promedio ponderado si se provee costo unitario
        if costo_unitario and costo_unitario > 0 and nuevo_stock > 0:
            costo_nuevo = (
                (stock_actual * costo_promedio_actual) + (cantidad * costo_unitario)
            ) / nuevo_stock
            payload["costo_promedio"] = float(costo_nuevo.quantize(Decimal("0.0001")))
            payload["ultimo_costo"] = float(costo_unitario)
    else:
        nuevo_stock = max(Decimal("0"), stock_actual - cantidad)

    payload["stock_actual"] = float(nuevo_stock)

    db.table("materias_primas_sucursales").update(payload).eq("id", mps["id"]).execute()


def completar_movimiento(db: Client, movimiento_id: UUID) -> dict | None:
    """
    Cambia estado a 'completado' y actualiza el stock según el tipo de ítem:
      - producto_id    → productos_sucursales.stock_disponible
      - materia_prima_id → materias_primas_sucursales.stock_actual + costo_promedio

    Stock se suma para entradas y se resta para salidas.
    El stock nunca baja de 0.
    """
    movimiento = get_movimiento_con_detalle(db, movimiento_id)
    if not movimiento:
        return None

    es_entrada = movimiento["tipo_movimiento"] in TIPOS_ENTRADA
    sucursal_id = movimiento["sucursal_id"]

    for item in movimiento.get("items", []):
        cantidad = Decimal(str(item["cantidad"]))
        costo_unitario = Decimal(str(item["costo_unitario"])) if item.get("costo_unitario") else None

        if item.get("producto_id"):
            _actualizar_stock_producto(
                db, sucursal_id, item["producto_id"], cantidad, es_entrada
            )
        elif item.get("materia_prima_id"):
            _actualizar_stock_materia_prima(
                db, sucursal_id, item["materia_prima_id"], cantidad, es_entrada, costo_unitario
            )

    # Marcar como completado
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "completado", "updated_at": _now()})
        .eq("id", str(movimiento_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── CANCELAR ────────────────────────────────────────────────────────────────

def cancelar_movimiento(db: Client, movimiento_id: UUID) -> dict | None:
    """
    Cancela el movimiento. Si estaba en borrador no afecta stock.
    Si estaba completado, el stock NO se revierte — requiere movimiento inverso.
    """
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "cancelado", "updated_at": _now()})
        .eq("id", str(movimiento_id))
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


def add_detalle_item(db: Client, movimiento_id: UUID, data: DetalleMovimientoCreate) -> dict:
    payload = _serialize(data.model_dump())
    payload["movimiento_id"] = str(movimiento_id)
    result = db.table(TABLE_DETALLE).insert(payload).execute()
    item = result.data[0]
    _recalcular_total_costo(db, movimiento_id)
    return item


def delete_detalle_item(db: Client, item_id: UUID, movimiento_id: UUID) -> bool:
    result = (
        db.table(TABLE_DETALLE)
        .delete()
        .eq("id", str(item_id))
        .execute()
    )
    if result.data:
        _recalcular_total_costo(db, movimiento_id)
    return len(result.data) > 0


def _recalcular_total_costo(db: Client, movimiento_id: UUID) -> None:
    items = (
        db.table(TABLE_DETALLE)
        .select("costo_total")
        .eq("movimiento_id", str(movimiento_id))
        .execute()
        .data
    )
    total = _calcular_total_costo(items)
    db.table(TABLE_NAME).update({
        "total_costo": total,
        "updated_at": _now(),
    }).eq("id", str(movimiento_id)).execute()


# ─── HARD DELETE ─────────────────────────────────────────────────────────────

def hard_delete_movimiento(db: Client, movimiento_id: UUID) -> bool:
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(movimiento_id))
        .execute()
    )
    return len(result.data) > 0