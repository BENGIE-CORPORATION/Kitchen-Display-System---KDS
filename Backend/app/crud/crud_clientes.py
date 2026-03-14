"""
CRUD de Clientes.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.cliente import SORTABLE_COLUMNS, TABLE_NAME
from ..schemas.cliente import ClienteCreateInternal, ClienteUpdateInternal


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
        elif hasattr(value, "isoformat"):   # date
            result[key] = value.isoformat()
        else:
            result[key] = value
    return result


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def cliente_identificacion_exists(
    db: Client, empresa_id: UUID, identificacion: str, exclude_id: UUID | None = None
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("empresa_id", str(empresa_id))
        .eq("identificacion", identificacion.upper())
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


def cliente_email_exists(
    db: Client, empresa_id: UUID, email: str, exclude_id: UUID | None = None
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("empresa_id", str(empresa_id))
        .eq("email", email.lower())
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_cliente(db: Client, data: ClienteCreateInternal) -> dict:
    payload = _serialize(data.model_dump(exclude_none=False))
    # Inicializar contadores
    payload.setdefault("puntos_fidelidad", 0)
    payload.setdefault("total_compras", 0.0)
    payload.setdefault("cantidad_compras", 0)
    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ONE ─────────────────────────────────────────────────────────────────

def get_cliente(db: Client, cliente_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(cliente_id))
        .neq("estado", "inactivo")
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


# ─── READ MANY ────────────────────────────────────────────────────────────────

def get_clientes(
    db: Client,
    empresa_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "created_at",
    order_desc: bool = True,
    tipo_cliente: str | None = None,
    estado: str | None = None,
    permite_marketing: bool | None = None,
    search: str | None = None,   # busca en nombre, apellido, email, identificacion
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_NAME)
        .select("*", count="exact")
        .eq("empresa_id", str(empresa_id))
        .neq("estado", "inactivo")
    )

    if tipo_cliente:
        query = query.eq("tipo_cliente", tipo_cliente)
    if estado:
        query = query.eq("estado", estado)
    if permite_marketing is not None:
        query = query.eq("permite_marketing", permite_marketing)
    if search:
        query = query.ilike("nombre", f"%{search}%")

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

def update_cliente(db: Client, cliente_id: UUID, data: ClienteUpdateInternal) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    payload["updated_at"] = _now()
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(cliente_id))
        .execute()
    )
    return result.data[0] if result.data else None


def actualizar_stats_compra(
    db: Client, cliente_id: UUID, monto_compra: Decimal
) -> dict | None:
    """
    Actualiza última compra, total_compras y cantidad_compras.
    Llamado desde el módulo de pedidos al confirmar un pago.
    """
    cliente = get_cliente(db, cliente_id)
    if not cliente:
        return None

    nuevo_total = Decimal(str(cliente.get("total_compras", 0))) + monto_compra
    nueva_cantidad = int(cliente.get("cantidad_compras", 0)) + 1

    result = (
        db.table(TABLE_NAME)
        .update({
            "ultima_compra": _now(),
            "total_compras": float(nuevo_total),
            "cantidad_compras": nueva_cantidad,
            "updated_at": _now(),
        })
        .eq("id", str(cliente_id))
        .execute()
    )
    return result.data[0] if result.data else None


def actualizar_puntos(db: Client, cliente_id: UUID, puntos: int) -> dict | None:
    """Suma o resta puntos de fidelidad. Acepta valores negativos para canje."""
    cliente = get_cliente(db, cliente_id)
    if not cliente:
        return None

    nuevos_puntos = max(0, int(cliente.get("puntos_fidelidad", 0)) + puntos)
    result = (
        db.table(TABLE_NAME)
        .update({"puntos_fidelidad": nuevos_puntos, "updated_at": _now()})
        .eq("id", str(cliente_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── SOFT DELETE ──────────────────────────────────────────────────────────────

def soft_delete_cliente(db: Client, cliente_id: UUID, updated_by: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "inactivo", "updated_at": _now(), "updated_by": str(updated_by)})
        .eq("id", str(cliente_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── HARD DELETE ─────────────────────────────────────────────────────────────

def hard_delete_cliente(db: Client, cliente_id: UUID) -> bool:
    result = db.table(TABLE_NAME).delete().eq("id", str(cliente_id)).execute()
    return len(result.data) > 0