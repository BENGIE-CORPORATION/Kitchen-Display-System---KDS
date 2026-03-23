"""
CRUD de Combos.
Un combo es un producto de tipo 'combo' que contiene otros productos como componentes.
Cada componente tiene cantidad y puede ser opcional o requerido.
No tienen soft delete — son definición estructural del producto.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..models.combo import TABLE_NAME
from ..schemas.combo import ComboCreate, ComboUpdate


def _now() -> str:
    return datetime.now(UTC).isoformat()


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

def componente_exists(db: Client, producto_id: UUID, producto_componente_id: UUID) -> bool:
    """Verifica que un componente no esté ya registrado en el combo."""
    result = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("producto_id", str(producto_id))
        .eq("producto_componente_id", str(producto_componente_id))
        .limit(1)
        .execute()
    )
    return len(result.data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_componente(db: Client, producto_id: UUID, data: ComboCreate) -> dict:
    payload = _serialize(data.model_dump())
    payload["producto_id"] = str(producto_id)
    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ─────────────────────────────────────────────────────────────────────

def get_componente(db: Client, componente_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(componente_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_componentes_por_combo(db: Client, producto_id: UUID) -> list[dict]:
    """
    Lista todos los componentes de un combo.
    Hace join con productos para retornar nombre y datos básicos del componente.
    """
    result = (
        db.table(TABLE_NAME)
        .select("*, productos!combos_producto_componente_id_fkey(id, nombre, unidad_medida, tipo_producto)")
        .eq("producto_id", str(producto_id))
        .execute()
    )
    # Aplanar el join para respuesta más limpia
    rows = []
    for row in result.data:
        componente = row.pop("productos", None)
        row["componente"] = componente
        rows.append(row)
    return rows


# ─── UPDATE ───────────────────────────────────────────────────────────────────

def update_componente(db: Client, componente_id: UUID, data: ComboUpdate) -> dict | None:
    payload = data.model_dump(exclude_unset=True)
    if "cantidad" in payload and payload["cantidad"] is not None:
        payload["cantidad"] = float(payload["cantidad"])
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(componente_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── DELETE ───────────────────────────────────────────────────────────────────

def delete_componente(db: Client, componente_id: UUID) -> bool:
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(componente_id))
        .execute()
    )
    return len(result.data) > 0


def delete_componentes_por_combo(db: Client, producto_id: UUID) -> int:
    """Elimina todos los componentes de un combo. Usado en hard delete de producto."""
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("producto_id", str(producto_id))
        .execute()
    )
    return len(result.data)