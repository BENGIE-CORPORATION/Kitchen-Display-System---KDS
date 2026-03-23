"""
CRUD de Productos y Productos×Sucursales.
Los routers NO deben contener queries directas.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.producto import SORTABLE_COLUMNS, TABLE_NAME, TABLE_SUCURSALES
from ..schemas.producto import (
    ProductoCreateInternal,
    ProductoSucursalCreate,
    ProductoSucursalUpdateInternal,
    ProductoUpdateInternal,
)


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order(column: str) -> str:
    return column if column in SORTABLE_COLUMNS else "created_at"


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

def producto_codigo_exists(
    db: Client,
    empresa_id: UUID,
    codigo_interno: str,
    exclude_id: UUID | None = None,
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("empresa_id", str(empresa_id))
        .eq("codigo_interno", codigo_interno.upper())
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


def producto_sucursal_exists(db: Client, producto_id: UUID, sucursal_id: UUID) -> bool:
    result = (
        db.table(TABLE_SUCURSALES)
        .select("id")
        .eq("producto_id", str(producto_id))
        .eq("sucursal_id", str(sucursal_id))
        .limit(1)
        .execute()
    )
    return len(result.data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_producto(db: Client, data: ProductoCreateInternal) -> dict:
    payload = _serialize(data.model_dump(exclude_none=False))
    if payload.get("codigo_interno"):
        payload["codigo_interno"] = payload["codigo_interno"].upper()
    if payload.get("codigo_barras"):
        payload["codigo_barras"] = payload["codigo_barras"].upper()
    # Serializar listas a JSON-compatible
    for field in ("imagenes_adicionales", "tags"):
        if payload.get(field) is not None:
            payload[field] = payload[field]
    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


def create_producto_sucursal(db: Client, data: ProductoSucursalCreate) -> dict:
    payload = data.model_dump(exclude_none=False)
    # Convertir Decimal a float para Supabase
    for field in ("precio_venta", "precio_costo", "precio_mayoreo", "porcentaje_iva",
                  "porcentaje_servicio", "stock_disponible", "stock_minimo",
                  "stock_maximo", "punto_reorden", "margen_utilidad"):
        if payload.get(field) is not None:
            payload[field] = float(payload[field])
    result = db.table(TABLE_SUCURSALES).insert(payload).execute()
    return result.data[0]


# ─── READ ONE ─────────────────────────────────────────────────────────────────

def get_producto(db: Client, producto_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(producto_id))
        .neq("estado", "inactivo")
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_producto_sucursal(db: Client, producto_id: UUID, sucursal_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_SUCURSALES)
        .select("*")
        .eq("producto_id", str(producto_id))
        .eq("sucursal_id", str(sucursal_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_producto_sucursal_by_id(db: Client, ps_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_SUCURSALES)
        .select("*")
        .eq("id", str(ps_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


# ─── READ MANY ────────────────────────────────────────────────────────────────

def get_productos(
    db: Client,
    empresa_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "created_at",
    order_desc: bool = True,
    categoria_id: UUID | None = None,
    tipo_producto: str | None = None,
    estado: str | None = None,
    es_vendible: bool | None = None,
    search: str | None = None,       # búsqueda por nombre o código
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_NAME)
        .select("*", count="exact")
        .eq("empresa_id", str(empresa_id))
        .neq("estado", "inactivo")
    )

    if categoria_id:
        query = query.eq("categoria_id", str(categoria_id))
    if tipo_producto:
        query = query.eq("tipo_producto", tipo_producto)
    if estado:
        query = query.eq("estado", estado)
    if es_vendible is not None:
        query = query.eq("es_vendible", es_vendible)
    if search:
        # Búsqueda simple por nombre — ilike es case-insensitive en Supabase
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


def get_productos_por_sucursal(
    db: Client,
    sucursal_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    disponible_venta: bool | None = None,
) -> dict:
    """Lista productos con precios y stock para una sucursal específica."""
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_SUCURSALES)
        .select("*, productos(*)", count="exact")
        .eq("sucursal_id", str(sucursal_id))
    )

    if disponible_venta is not None:
        query = query.eq("disponible_venta", disponible_venta)

    result = (
        query
        .order("created_at", desc=True)
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

def update_producto(db: Client, producto_id: UUID, data: ProductoUpdateInternal) -> dict | None:
    payload = data.model_dump(exclude_unset=True)
    if payload.get("codigo_interno"):
        payload["codigo_interno"] = payload["codigo_interno"].upper()
    if payload.get("codigo_barras"):
        payload["codigo_barras"] = payload["codigo_barras"].upper()
    payload["updated_at"] = _now()

    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(producto_id))
        .execute()
    )
    return result.data[0] if result.data else None


def update_producto_sucursal(
    db: Client, ps_id: UUID, data: ProductoSucursalUpdateInternal
) -> dict | None:
    payload = data.model_dump(exclude_unset=True)
    for field in ("precio_venta", "precio_costo", "precio_mayoreo", "porcentaje_iva",
                  "porcentaje_servicio", "stock_disponible", "stock_minimo",
                  "stock_maximo", "punto_reorden", "margen_utilidad"):
        if payload.get(field) is not None:
            payload[field] = float(payload[field])
    payload["updated_at"] = _now()

    result = (
        db.table(TABLE_SUCURSALES)
        .update(payload)
        .eq("id", str(ps_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── SOFT DELETE ──────────────────────────────────────────────────────────────

def soft_delete_producto(db: Client, producto_id: UUID, updated_by: UUID) -> dict | None:
    """
    Marca el producto como inactivo.
    No desactiva productos_sucursales — quedan con disponible_venta en su estado actual.
    """
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "inactivo", "updated_at": _now(), "updated_by": str(updated_by)})
        .eq("id", str(producto_id))
        .execute()
    )
    return result.data[0] if result.data else None


def deshabilitar_producto_en_sucursales(db: Client, producto_id: UUID) -> int:
    """Marca disponible_venta=False en todas las sucursales del producto."""
    result = (
        db.table(TABLE_SUCURSALES)
        .update({"disponible_venta": False, "updated_at": _now()})
        .eq("producto_id", str(producto_id))
        .execute()
    )
    return len(result.data)


# ─── HARD DELETE ─────────────────────────────────────────────────────────────

def hard_delete_producto(db: Client, producto_id: UUID) -> bool:
    """
    Borra físicamente el producto.
    productos_sucursales se eliminan en cascada por FK.
    """
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(producto_id))
        .execute()
    )
    return len(result.data) > 0


def delete_producto_sucursal(db: Client, ps_id: UUID) -> bool:
    """Elimina la configuración de un producto en una sucursal."""
    result = (
        db.table(TABLE_SUCURSALES)
        .delete()
        .eq("id", str(ps_id))
        .execute()
    )
    return len(result.data) > 0