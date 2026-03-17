"""
CRUD de Lotes de Inventario.
Los lotes rastrean cantidades específicas de materias primas o productos
con su costo unitario, fecha de vencimiento y proveedor de origen.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.lote_inventario import SORTABLE_COLUMNS, TABLE_NAME
from ..schemas.lote_inventario import LoteInventarioCreateInternal, LoteInventarioUpdate


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order(column: str) -> str:
    return column if column in SORTABLE_COLUMNS else "fecha_ingreso"


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


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def numero_lote_exists(
    db: Client,
    sucursal_id: UUID,
    numero_lote: str,
    exclude_id: UUID | None = None,
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("sucursal_id", str(sucursal_id))
        .eq("numero_lote", numero_lote)
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_lote(db: Client, data: LoteInventarioCreateInternal) -> dict:
    payload = _serialize(data.model_dump(exclude_none=False))
    # cantidad_actual se inicializa igual a cantidad_inicial
    if not payload.get("cantidad_actual"):
        payload["cantidad_actual"] = payload["cantidad_inicial"]
    payload["estado"] = "activo"
    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ONE ─────────────────────────────────────────────────────────────────

def get_lote(db: Client, lote_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(lote_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


# ─── READ MANY ────────────────────────────────────────────────────────────────

def get_lotes(
    db: Client,
    sucursal_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "fecha_ingreso",
    order_desc: bool = True,
    materia_prima_id: UUID | None = None,
    producto_id: UUID | None = None,
    estado: str | None = None,
    proximos_a_vencer: int | None = None,  # días — lotes que vencen en N días
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_NAME)
        .select("*", count="exact")
        .eq("sucursal_id", str(sucursal_id))
    )

    if materia_prima_id:
        query = query.eq("materia_prima_id", str(materia_prima_id))
    if producto_id:
        query = query.eq("producto_id", str(producto_id))
    if estado:
        query = query.eq("estado", estado)
    if proximos_a_vencer is not None:
        from datetime import timedelta, timezone
        limite = (datetime.now(timezone.utc) + timedelta(days=proximos_a_vencer)).isoformat()
        now = datetime.now(timezone.utc).isoformat()
        query = (
            query
            .gte("fecha_vencimiento", now)
            .lte("fecha_vencimiento", limite)
        )

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


# ─── UPDATE ───────────────────────────────────────────────────────────────────

def update_lote(db: Client, lote_id: UUID, data: LoteInventarioUpdate) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(lote_id))
        .execute()
    )
    return result.data[0] if result.data else None


def marcar_lote_agotado(db: Client, lote_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "agotado", "cantidad_actual": 0})
        .eq("id", str(lote_id))
        .execute()
    )
    return result.data[0] if result.data else None


def marcar_lotes_vencidos(db: Client, sucursal_id: UUID) -> int:
    """
    Marca como 'vencido' todos los lotes activos cuya fecha_vencimiento
    ya pasó. Útil para un job periódico o al listar lotes.
    """
    from datetime import timezone
    now = datetime.now(timezone.utc).isoformat()
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "vencido"})
        .eq("sucursal_id", str(sucursal_id))
        .eq("estado", "activo")
        .lt("fecha_vencimiento", now)
        .not_.is_("fecha_vencimiento", "null")
        .execute()
    )
    return len(result.data)


# ─── HARD DELETE ─────────────────────────────────────────────────────────────

def hard_delete_lote(db: Client, lote_id: UUID) -> bool:
    """Solo permitido en lotes agotados o errores de registro."""
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(lote_id))
        .execute()
    )
    return len(result.data) > 0