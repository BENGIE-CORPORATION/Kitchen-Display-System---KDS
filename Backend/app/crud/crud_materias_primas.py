"""
CRUD de Materias Primas y Materias Primas × Sucursales.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.materia_prima import SORTABLE_COLUMNS, TABLE_NAME, TABLE_SUCURSALES
from ..schemas.materia_prima import (
    MateriaPrimaCreateInternal,
    MateriaPrimaSucursalCreate,
    MateriaPrimaSucursalUpdateInternal,
    MateriaPrimaUpdateInternal,
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


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def materia_prima_codigo_exists(
    db: Client,
    empresa_id: UUID,
    codigo: str,
    exclude_id: UUID | None = None,
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("empresa_id", str(empresa_id))
        .eq("codigo", codigo.upper())
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


def materia_prima_sucursal_exists(
    db: Client, materia_prima_id: UUID, sucursal_id: UUID
) -> bool:
    result = (
        db.table(TABLE_SUCURSALES)
        .select("id")
        .eq("materia_prima_id", str(materia_prima_id))
        .eq("sucursal_id", str(sucursal_id))
        .limit(1)
        .execute()
    )
    return len(result.data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_materia_prima(db: Client, data: MateriaPrimaCreateInternal) -> dict:
    payload = _serialize(data.model_dump(exclude_none=False))
    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


def create_materia_prima_sucursal(db: Client, data: MateriaPrimaSucursalCreate) -> dict:
    payload = _serialize(data.model_dump(exclude_none=False))
    result = db.table(TABLE_SUCURSALES).insert(payload).execute()
    return result.data[0]


# ─── READ ONE ─────────────────────────────────────────────────────────────────

def get_materia_prima(db: Client, materia_prima_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(materia_prima_id))
        .neq("estado", "inactivo")
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_materia_prima_sucursal(
    db: Client, materia_prima_id: UUID, sucursal_id: UUID
) -> dict | None:
    result = (
        db.table(TABLE_SUCURSALES)
        .select("*")
        .eq("materia_prima_id", str(materia_prima_id))
        .eq("sucursal_id", str(sucursal_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_materia_prima_sucursal_by_id(db: Client, mps_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_SUCURSALES)
        .select("*")
        .eq("id", str(mps_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


# ─── READ MANY ────────────────────────────────────────────────────────────────

def get_materias_primas(
    db: Client,
    empresa_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "nombre",
    order_desc: bool = False,
    categoria: str | None = None,
    unidad_medida: str | None = None,
    perecedero: bool | None = None,
    estado: str | None = None,
    search: str | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_NAME)
        .select("*", count="exact")
        .eq("empresa_id", str(empresa_id))
        .neq("estado", "inactivo")
    )

    if categoria:
        query = query.eq("categoria", categoria)
    if unidad_medida:
        query = query.eq("unidad_medida", unidad_medida)
    if perecedero is not None:
        query = query.eq("perecedero", perecedero)
    if estado:
        query = query.eq("estado", estado)
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


def get_materias_primas_por_sucursal(
    db: Client,
    sucursal_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    bajo_minimo: bool = False,   # filtra stock_actual < stock_minimo
) -> dict:
    """Lista materias primas con stock de una sucursal. Opcionalmente filtra por bajo mínimo."""
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_SUCURSALES)
        .select("*, materias_primas(*)", count="exact")
        .eq("sucursal_id", str(sucursal_id))
    )

    result = (
        query
        .order("created_at", desc=True)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )

    data = result.data
    if bajo_minimo:
        data = [
            row for row in data
            if Decimal(str(row.get("stock_actual", 0))) < Decimal(str(row.get("stock_minimo", 0)))
        ]

    return paginated_response(
        data=data,
        total=result.count or 0,
        page=page,
        items_per_page=items_per_page,
    )


# ─── UPDATE ───────────────────────────────────────────────────────────────────

def update_materia_prima(
    db: Client, materia_prima_id: UUID, data: MateriaPrimaUpdateInternal
) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    payload["updated_at"] = _now()
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(materia_prima_id))
        .execute()
    )
    return result.data[0] if result.data else None


def update_materia_prima_sucursal(
    db: Client, mps_id: UUID, data: MateriaPrimaSucursalUpdateInternal
) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    payload["updated_at"] = _now()
    result = (
        db.table(TABLE_SUCURSALES)
        .update(payload)
        .eq("id", str(mps_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── SOFT DELETE ──────────────────────────────────────────────────────────────

def soft_delete_materia_prima(
    db: Client, materia_prima_id: UUID, updated_by: UUID
) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "inactivo", "updated_at": _now(), "updated_by": str(updated_by)})
        .eq("id", str(materia_prima_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── HARD DELETE ─────────────────────────────────────────────────────────────

def hard_delete_materia_prima(db: Client, materia_prima_id: UUID) -> bool:
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(materia_prima_id))
        .execute()
    )
    return len(result.data) > 0


def delete_materia_prima_sucursal(db: Client, mps_id: UUID) -> bool:
    result = (
        db.table(TABLE_SUCURSALES)
        .delete()
        .eq("id", str(mps_id))
        .execute()
    )
    return len(result.data) > 0