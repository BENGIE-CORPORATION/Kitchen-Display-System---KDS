"""
CRUD de Recetas.
Una receta define qué materias primas y en qué cantidad se necesitan para producir un producto.
No tienen soft delete — son definición estructural del producto.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..models.receta import TABLE_NAME
from ..schemas.receta import RecetaCreate, RecetaUpdate


def _now() -> str:
    return datetime.now(UTC).isoformat()


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

def receta_ingrediente_exists(
    db: Client,
    producto_id: UUID,
    materia_prima_id: UUID,
    exclude_id: UUID | None = None,
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("producto_id", str(producto_id))
        .eq("materia_prima_id", str(materia_prima_id))
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_ingrediente(
    db: Client, producto_id: UUID, data: RecetaCreate, created_by: UUID
) -> dict:
    payload = _serialize(data.model_dump())
    payload["producto_id"] = str(producto_id)
    payload["created_by"] = str(created_by)
    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ─────────────────────────────────────────────────────────────────────

def get_ingrediente(db: Client, receta_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(receta_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_receta_por_producto(db: Client, producto_id: UUID) -> list[dict]:
    """Retorna todos los ingredientes de un producto con datos de la materia prima."""
    result = (
        db.table(TABLE_NAME)
        .select("*, materias_primas(id, nombre, unidad_medida, categoria, perecedero)")
        .eq("producto_id", str(producto_id))
        .execute()
    )
    rows = []
    for row in result.data:
        mp = row.pop("materias_primas", None)
        row["materia_prima"] = mp
        rows.append(row)
    return rows


# ─── UPDATE ───────────────────────────────────────────────────────────────────

def update_ingrediente(db: Client, receta_id: UUID, data: RecetaUpdate) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    payload["updated_at"] = _now()
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(receta_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── DELETE ───────────────────────────────────────────────────────────────────

def delete_ingrediente(db: Client, receta_id: UUID) -> bool:
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(receta_id))
        .execute()
    )
    return len(result.data) > 0


def delete_receta_por_producto(db: Client, producto_id: UUID) -> int:
    """Elimina toda la receta de un producto. Útil en hard delete de producto."""
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("producto_id", str(producto_id))
        .execute()
    )
    return len(result.data)