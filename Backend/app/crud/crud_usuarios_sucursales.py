"""
CRUD de Usuarios × Sucursales.
Tabla: public.usuarios_sucursales

Esta tabla es la más delicada — define exactamente qué puede hacer
cada empleado y dónde. Reglas críticas:

1. Un usuario solo puede tener UNA asignación por sucursal (unique constraint)
2. Solo puede haber UNA sucursal principal (es_principal=True) por usuario
3. Al crear la primera asignación → marcarla como principal automáticamente
4. Al desactivar la asignación principal → promover otra como principal
5. Verificar que usuario y sucursal pertenezcan a la misma empresa
"""

from datetime import UTC, datetime
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.usuario_sucursal import TABLE_NAME
from ..schemas.usuario_sucursal import UsuarioSucursalCreateInternal, UsuarioSucursalUpdateInternal


def _now() -> str:
    return datetime.now(UTC).isoformat()


# ─── EXISTS / VALIDACIONES ────────────────────────────────────────────────────

def asignacion_exists(db: Client, usuario_id: UUID, sucursal_id: UUID) -> bool:
    """Verifica si ya existe la asignación (activa o inactiva)."""
    result = (
        db.table(TABLE_NAME).select("id")
        .eq("usuario_id", str(usuario_id))
        .eq("sucursal_id", str(sucursal_id))
        .limit(1).execute()
    )
    return len(result.data) > 0


def asignacion_activa_exists(db: Client, usuario_id: UUID, sucursal_id: UUID) -> bool:
    """Verifica si ya existe una asignación ACTIVA."""
    result = (
        db.table(TABLE_NAME).select("id")
        .eq("usuario_id", str(usuario_id))
        .eq("sucursal_id", str(sucursal_id))
        .eq("estado", "activo")
        .limit(1).execute()
    )
    return len(result.data) > 0


def contar_asignaciones_activas(db: Client, usuario_id: UUID) -> int:
    """Cuenta cuántas sucursales activas tiene el usuario."""
    result = (
        db.table(TABLE_NAME).select("id", count="exact")
        .eq("usuario_id", str(usuario_id))
        .eq("estado", "activo")
        .execute()
    )
    return result.count or 0


def tiene_sucursal_principal(db: Client, usuario_id: UUID) -> bool:
    result = (
        db.table(TABLE_NAME).select("id")
        .eq("usuario_id", str(usuario_id))
        .eq("es_principal", True)
        .eq("estado", "activo")
        .limit(1).execute()
    )
    return len(result.data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_asignacion(db: Client, asignacion: UsuarioSucursalCreateInternal) -> dict:
    """
    Crea una nueva asignación usuario ↔ sucursal.

    AUTO-PRINCIPAL: Si es la primera asignación del usuario,
    se marca automáticamente como sucursal principal.
    """
    payload = asignacion.model_dump()
    for field in ("usuario_id", "sucursal_id", "created_by"):
        if payload.get(field):
            payload[field] = str(payload[field])

    # Si es la primera asignación → automáticamente es la principal
    if not tiene_sucursal_principal(db, asignacion.usuario_id):
        payload["es_principal"] = True

    # Si se pide marcar como principal → quitar la anterior primero
    elif payload.get("es_principal"):
        _quitar_principal_anterior(db, asignacion.usuario_id)

    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


def _quitar_principal_anterior(db: Client, usuario_id: UUID) -> None:
    """Desmarca la sucursal principal actual antes de asignar una nueva."""
    db.table(TABLE_NAME).update({"es_principal": False}).eq(
        "usuario_id", str(usuario_id)
    ).eq("es_principal", True).execute()


# ─── READ ─────────────────────────────────────────────────────────────────────

def get_asignacion(db: Client, asignacion_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*, sucursales(id, nombre, tipo, ciudad), perfiles_usuario(id, nombre_completo, email, rol_global)")
        .eq("id", str(asignacion_id))
        .limit(1).execute()
    )
    return result.data[0] if result.data else None


def get_asignacion_by_usuario_sucursal(
    db: Client, usuario_id: UUID, sucursal_id: UUID
) -> dict | None:
    result = (
        db.table(TABLE_NAME).select("*")
        .eq("usuario_id", str(usuario_id))
        .eq("sucursal_id", str(sucursal_id))
        .limit(1).execute()
    )
    return result.data[0] if result.data else None


def get_usuarios_de_sucursal(
    db: Client,
    sucursal_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    estado: str | None = "activo",
    rol_sucursal: str | None = None,
) -> dict:
    """Lista todos los usuarios asignados a una sucursal."""
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_NAME)
        .select(
            "*, perfiles_usuario(id, nombre_completo, email, avatar_url, estado)",
            count="exact",
        )
        .eq("sucursal_id", str(sucursal_id))
    )
    if estado:
        query = query.eq("estado", estado)
    if rol_sucursal:
        query = query.eq("rol_sucursal", rol_sucursal)

    result = (
        query.order("created_at", desc=True)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )
    return paginated_response(
        data=result.data,
        total=result.count or 0,
        page=page,
        items_per_page=items_per_page,
    )


def get_sucursales_de_usuario(db: Client, usuario_id: UUID) -> list[dict]:
    """Lista todas las sucursales activas de un usuario con datos expandidos."""
    result = (
        db.table(TABLE_NAME)
        .select("*, sucursales(id, nombre, codigo, tipo, ciudad, estado)")
        .eq("usuario_id", str(usuario_id))
        .eq("estado", "activo")
        .order("es_principal", desc=True)  # la principal primero
        .execute()
    )
    return result.data


# ─── UPDATE ───────────────────────────────────────────────────────────────────

def update_asignacion(
    db: Client, asignacion_id: UUID, data: UsuarioSucursalUpdateInternal, usuario_id: UUID
) -> dict | None:
    payload = data.model_dump(exclude_unset=True, exclude_none=True)
    payload["updated_at"] = _now()

    # Si se quiere marcar como principal → quitar la anterior
    if payload.get("es_principal") is True:
        _quitar_principal_anterior(db, usuario_id)

    result = (
        db.table(TABLE_NAME).update(payload)
        .eq("id", str(asignacion_id)).execute()
    )
    return result.data[0] if result.data else None


# ─── DESACTIVAR ASIGNACIÓN ────────────────────────────────────────────────────
# ⚠️ SINCRONIZACIÓN CRÍTICA: si era la principal, promover otra

def desactivar_asignacion(db: Client, asignacion_id: UUID, usuario_id: UUID) -> dict | None:
    """
    Desactiva la asignación de un usuario a una sucursal.

    SINCRONIZACIÓN: si era la sucursal principal, intentar promover
    automáticamente la siguiente asignación activa como nueva principal.
    """
    # Verificar si esta era la principal
    asignacion = get_asignacion(db, asignacion_id)
    era_principal = asignacion and asignacion.get("es_principal", False)

    # Desactivar
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "inactivo", "es_principal": False, "updated_at": _now()})
        .eq("id", str(asignacion_id)).execute()
    )

    # SINCRONIZACIÓN: si era principal → promover otra automáticamente
    if era_principal:
        _promover_nueva_principal(db, usuario_id)

    return result.data[0] if result.data else None


def _promover_nueva_principal(db: Client, usuario_id: UUID) -> None:
    """
    Si el usuario se queda sin principal, busca la siguiente asignación
    activa y la promueve automáticamente.
    """
    # Buscar cualquier asignación activa restante
    result = (
        db.table(TABLE_NAME).select("id")
        .eq("usuario_id", str(usuario_id))
        .eq("estado", "activo")
        .order("fecha_asignacion", desc=False)  # la más antigua → más estable
        .limit(1).execute()
    )
    if result.data:
        nueva_principal_id = result.data[0]["id"]
        db.table(TABLE_NAME).update(
            {"es_principal": True, "updated_at": _now()}
        ).eq("id", nueva_principal_id).execute()


def hard_delete_asignacion(db: Client, asignacion_id: UUID, usuario_id: UUID) -> bool:
    """
    Elimina físicamente la asignación.
    SINCRONIZACIÓN: si era la principal → promover otra.
    """
    asignacion = get_asignacion(db, asignacion_id)
    era_principal = asignacion and asignacion.get("es_principal", False)

    result = db.table(TABLE_NAME).delete().eq("id", str(asignacion_id)).execute()

    if era_principal:
        _promover_nueva_principal(db, usuario_id)

    return len(result.data) > 0
