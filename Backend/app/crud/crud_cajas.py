"""
CRUD de Cajas, Sesiones de Caja y Movimientos de Caja.

Reglas clave:
  - Solo puede haber una sesión 'abierta' por caja a la vez.
  - Al cerrar, se calcula monto_esperado y diferencia automáticamente.
  - Los movimientos (entradas/salidas) actualizan los totales de la sesión.
  - Una sesión cerrada no admite nuevos movimientos.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.caja import (
    SORTABLE_COLUMNS_CAJAS,
    SORTABLE_COLUMNS_MOVIMIENTOS,
    SORTABLE_COLUMNS_SESIONES,
    TABLE_CAJAS,
    TABLE_MOVIMIENTOS,
    TABLE_SESIONES,
)
from ..schemas.caja import (
    CajaCreateInternal,
    CajaUpdateInternal,
    MovimientoCajaCreate,
    SesionCajaApertura,
    SesionCajaCierre,
)


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order(column: str, table: str = "cajas") -> str:
    mapping = {
        "cajas": SORTABLE_COLUMNS_CAJAS,
        "sesiones": SORTABLE_COLUMNS_SESIONES,
        "movimientos": SORTABLE_COLUMNS_MOVIMIENTOS,
    }
    cols = mapping.get(table, SORTABLE_COLUMNS_CAJAS)
    return column if column in cols else "created_at"


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


# ══════════════════════════════════════════════════════════════════════════════
# CAJAS
# ══════════════════════════════════════════════════════════════════════════════

def caja_codigo_exists(
    db: Client, sucursal_id: UUID, codigo: str, exclude_id: UUID | None = None
) -> bool:
    query = (
        db.table(TABLE_CAJAS)
        .select("id")
        .eq("sucursal_id", str(sucursal_id))
        .eq("codigo", codigo.upper())
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


def create_caja(db: Client, data: CajaCreateInternal) -> dict:
    payload = _serialize(data.model_dump(exclude_none=False))
    result = db.table(TABLE_CAJAS).insert(payload).execute()
    return result.data[0]


def get_caja(db: Client, caja_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_CAJAS)
        .select("*")
        .eq("id", str(caja_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_cajas(
    db: Client,
    sucursal_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "nombre",
    order_desc: bool = False,
    tipo: str | None = None,
    estado: str | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)
    query = (
        db.table(TABLE_CAJAS)
        .select("*", count="exact")
        .eq("sucursal_id", str(sucursal_id))
    )
    if tipo:
        query = query.eq("tipo", tipo)
    if estado:
        query = query.eq("estado", estado)

    result = (
        query
        .order(_safe_order(order_by, "cajas"), desc=order_desc)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )
    return paginated_response(data=result.data, total=result.count or 0, page=page, items_per_page=items_per_page)


def update_caja(db: Client, caja_id: UUID, data: CajaUpdateInternal) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    payload["updated_at"] = _now()
    result = db.table(TABLE_CAJAS).update(payload).eq("id", str(caja_id)).execute()
    return result.data[0] if result.data else None


def soft_delete_caja(db: Client, caja_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_CAJAS)
        .update({"estado": "inactivo", "updated_at": _now()})
        .eq("id", str(caja_id))
        .execute()
    )
    return result.data[0] if result.data else None


def hard_delete_caja(db: Client, caja_id: UUID) -> bool:
    result = db.table(TABLE_CAJAS).delete().eq("id", str(caja_id)).execute()
    return len(result.data) > 0


# ══════════════════════════════════════════════════════════════════════════════
# SESIONES DE CAJA
# ══════════════════════════════════════════════════════════════════════════════

def sesion_abierta_exists(db: Client, caja_id: UUID) -> bool:
    """Verifica si la caja ya tiene una sesión abierta."""
    result = (
        db.table(TABLE_SESIONES)
        .select("id")
        .eq("caja_id", str(caja_id))
        .eq("estado", "abierta")
        .limit(1)
        .execute()
    )
    return len(result.data) > 0


def numero_sesion_exists(db: Client, caja_id: UUID, numero_sesion: str) -> bool:
    result = (
        db.table(TABLE_SESIONES)
        .select("id")
        .eq("caja_id", str(caja_id))
        .eq("numero_sesion", numero_sesion.upper())
        .limit(1)
        .execute()
    )
    return len(result.data) > 0


def abrir_sesion(db: Client, data: SesionCajaApertura, usuario_id: UUID) -> dict:
    payload = _serialize(data.model_dump())
    payload["usuario_id"] = str(usuario_id)
    payload["estado"] = "abierta"
    payload["fecha_apertura"] = _now()
    # Inicializar todos los totales en 0
    for campo in ("total_ventas", "total_efectivo", "total_tarjeta_debito",
                  "total_tarjeta_credito", "total_transferencia", "total_sinpe",
                  "total_otros", "total_entradas", "total_salidas"):
        payload[campo] = 0.0
    payload["cantidad_transacciones"] = 0
    result = db.table(TABLE_SESIONES).insert(payload).execute()
    return result.data[0]


def get_sesion(db: Client, sesion_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_SESIONES)
        .select("*")
        .eq("id", str(sesion_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_sesion_abierta(db: Client, caja_id: UUID) -> dict | None:
    """Retorna la sesión actualmente abierta de una caja, si existe."""
    result = (
        db.table(TABLE_SESIONES)
        .select("*")
        .eq("caja_id", str(caja_id))
        .eq("estado", "abierta")
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_sesiones(
    db: Client,
    caja_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "fecha_apertura",
    order_desc: bool = True,
    estado: str | None = None,
    usuario_id: UUID | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)
    query = (
        db.table(TABLE_SESIONES)
        .select("*", count="exact")
        .eq("caja_id", str(caja_id))
    )
    if estado:
        query = query.eq("estado", estado)
    if usuario_id:
        query = query.eq("usuario_id", str(usuario_id))

    result = (
        query
        .order(_safe_order(order_by, "sesiones"), desc=order_desc)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )
    return paginated_response(data=result.data, total=result.count or 0, page=page, items_per_page=items_per_page)


def cerrar_sesion(db: Client, sesion_id: UUID, data: SesionCajaCierre) -> dict | None:
    """
    Cierra la sesión calculando:
      monto_esperado = monto_apertura + total_entradas - total_salidas + total_ventas_efectivo
      diferencia     = monto_cierre - monto_esperado
    """
    sesion = get_sesion(db, sesion_id)
    if not sesion:
        return None

    monto_apertura  = Decimal(str(sesion["monto_apertura"]))
    total_entradas  = Decimal(str(sesion["total_entradas"]))
    total_salidas   = Decimal(str(sesion["total_salidas"]))
    total_efectivo  = Decimal(str(sesion["total_efectivo"]))
    monto_cierre    = data.monto_cierre

    monto_esperado = monto_apertura + total_entradas - total_salidas + total_efectivo
    diferencia     = monto_cierre - monto_esperado

    payload = {
        "estado": "cerrada",
        "monto_cierre": float(monto_cierre),
        "monto_esperado": float(monto_esperado),
        "diferencia": float(diferencia),
        "fecha_cierre": _now(),
        "notas_cierre": data.notas_cierre,
    }
    result = db.table(TABLE_SESIONES).update(payload).eq("id", str(sesion_id)).execute()
    return result.data[0] if result.data else None


def auditar_sesion(db: Client, sesion_id: UUID) -> dict | None:
    """Marca la sesión como auditada — estado final."""
    result = (
        db.table(TABLE_SESIONES)
        .update({"estado": "auditada"})
        .eq("id", str(sesion_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ══════════════════════════════════════════════════════════════════════════════
# MOVIMIENTOS DE CAJA
# ══════════════════════════════════════════════════════════════════════════════

def create_movimiento_caja(
    db: Client, sesion_id: UUID, data: MovimientoCajaCreate, created_by: UUID
) -> dict:
    """
    Registra un movimiento y actualiza los totales de la sesión en una sola operación.
    """
    payload = _serialize(data.model_dump())
    payload["sesion_caja_id"] = str(sesion_id)
    payload["created_by"] = str(created_by)
    payload["created_at"] = _now()

    result = db.table(TABLE_MOVIMIENTOS).insert(payload).execute()
    movimiento = result.data[0]

    _actualizar_totales_sesion(db, sesion_id, data)
    return movimiento


def _actualizar_totales_sesion(
    db: Client, sesion_id: UUID, data: MovimientoCajaCreate
) -> None:
    """Incrementa el total correspondiente al método de pago y tipo del movimiento."""
    sesion = get_sesion(db, sesion_id)
    if not sesion:
        return

    monto = float(data.monto)
    update: dict = {}

    if data.tipo == "entrada":
        update["total_entradas"] = float(Decimal(str(sesion["total_entradas"])) + Decimal(str(monto)))
    else:
        update["total_salidas"] = float(Decimal(str(sesion["total_salidas"])) + Decimal(str(monto)))

    # Acumular por método de pago
    metodo_campo = {
        "efectivo": "total_efectivo",
        "tarjeta_debito": "total_tarjeta_debito",
        "tarjeta_credito": "total_tarjeta_credito",
        "transferencia": "total_transferencia",
        "sinpe": "total_sinpe",
        "otros": "total_otros",
    }
    if data.metodo_pago and data.metodo_pago in metodo_campo:
        campo = metodo_campo[data.metodo_pago]
        valor_actual = Decimal(str(sesion.get(campo, 0)))
        update[campo] = float(valor_actual + Decimal(str(monto)))

    if update:
        db.table(TABLE_SESIONES).update(update).eq("id", str(sesion_id)).execute()


def get_movimiento_caja(db: Client, movimiento_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_MOVIMIENTOS)
        .select("*")
        .eq("id", str(movimiento_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_movimientos_caja(
    db: Client,
    sesion_id: UUID,
    page: int = 1,
    items_per_page: int = 50,
    order_by: str = "created_at",
    order_desc: bool = True,
    tipo: str | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)
    query = (
        db.table(TABLE_MOVIMIENTOS)
        .select("*", count="exact")
        .eq("sesion_caja_id", str(sesion_id))
    )
    if tipo:
        query = query.eq("tipo", tipo)

    result = (
        query
        .order(_safe_order(order_by, "movimientos"), desc=order_desc)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )
    return paginated_response(data=result.data, total=result.count or 0, page=page, items_per_page=items_per_page)


def hard_delete_movimiento_caja(db: Client, movimiento_id: UUID) -> bool:
    """Solo para corrección de errores — no revierte totales de la sesión."""
    result = db.table(TABLE_MOVIMIENTOS).delete().eq("id", str(movimiento_id)).execute()
    return len(result.data) > 0