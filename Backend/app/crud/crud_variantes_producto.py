"""
CRUD de Variantes de Producto.
Las variantes definen atributos configurables de un producto (Tamaño, Color, etc.)
y sus opciones posibles. No manejan inventario — eso lo hace productos_sucursales.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..models.variante_producto import SORTABLE_COLUMNS, TABLE_NAME
from ..schemas.variante_producto import VarianteProductoCreate, VarianteProductoUpdate


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order(column: str) -> str:
    return column if column in SORTABLE_COLUMNS else "orden"


def _serialize(payload: dict) -> dict:
    """Convierte UUID y Decimal a tipos JSON-serializables para Supabase."""
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

def variante_nombre_exists(
    db: Client,
    producto_id: UUID,
    nombre: str,
    exclude_id: UUID | None = None,
) -> bool:
    """Verifica que no existan dos variantes con el mismo nombre en un producto."""
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("producto_id", str(producto_id))
        .eq("nombre", nombre)
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_variante(db: Client, producto_id: UUID, data: VarianteProductoCreate) -> dict:
    payload = _serialize(data.model_dump())
    payload["producto_id"] = str(producto_id)
    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ─────────────────────────────────────────────────────────────────────

def get_variante(db: Client, variante_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(variante_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_variantes_por_producto(db: Client, producto_id: UUID) -> list[dict]:
    """Retorna todas las variantes de un producto ordenadas por `orden`."""
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("producto_id", str(producto_id))
        .order("orden", desc=False)
        .execute()
    )
    return result.data


# ─── UPDATE ───────────────────────────────────────────────────────────────────

def update_variante(db: Client, variante_id: UUID, data: VarianteProductoUpdate) -> dict | None:
    payload = data.model_dump(exclude_unset=True)
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(variante_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── DELETE ───────────────────────────────────────────────────────────────────

def delete_variante(db: Client, variante_id: UUID) -> bool:
    """Hard delete — las variantes no tienen soft delete (son metadata, no transacciones)."""
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(variante_id))
        .execute()
    )
    return len(result.data) > 0


def delete_variantes_por_producto(db: Client, producto_id: UUID) -> int:
    """Elimina todas las variantes de un producto. Usado en hard delete de producto."""
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("producto_id", str(producto_id))
        .execute()
    )
    return len(result.data)