from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field

from ..models.auditoria import ACCIONES_VALIDAS, MODULOS_VALIDOS


# ─── Historial estados pedido ─────────────────────────────────────────────────

class HistorialEstadoPedidoRead(BaseModel):
    id: UUID
    pedido_id: UUID
    estado_anterior: str | None
    estado_nuevo: str
    campo_modificado: str | None
    notas: str | None
    metadata: dict[str, Any] | None
    ip_address: str | None
    created_at: datetime | None
    created_by: UUID


class HistorialEstadoPedidoCreate(BaseModel):
    """Uso interno — el router y CRUD lo construyen automáticamente."""
    pedido_id: UUID
    estado_anterior: str | None = None
    estado_nuevo: str
    campo_modificado: str | None = None
    notas: str | None = None
    metadata: dict[str, Any] | None = None
    ip_address: str | None = None
    created_by: UUID


# ─── Historial estados detalle ────────────────────────────────────────────────

class HistorialEstadetalleRead(BaseModel):
    id: UUID
    detalle_pedido_id: UUID
    estado_anterior: str | None
    estado_nuevo: str
    notas: str | None
    created_at: datetime | None
    created_by: UUID


class HistorialEstadetalleCreate(BaseModel):
    """Uso interno."""
    detalle_pedido_id: UUID
    estado_anterior: str | None = None
    estado_nuevo: str
    notas: str | None = None
    created_by: UUID


# ─── Auditoría ────────────────────────────────────────────────────────────────

class AuditoriaRead(BaseModel):
    id: UUID
    empresa_id: UUID | None
    sucursal_id: UUID | None
    usuario_id: UUID
    modulo: str
    tabla: str
    registro_id: UUID | None
    accion: str
    datos_anteriores: dict[str, Any] | None
    datos_nuevos: dict[str, Any] | None
    cambios_especificos: dict[str, Any] | None
    ip_address: str | None
    user_agent: str | None
    dispositivo: str | None
    ubicacion_geografica: dict[str, Any] | None
    created_at: datetime | None


class AuditoriaCreate(BaseModel):
    """Uso interno — llamado desde middleware o endpoints clave."""
    empresa_id: UUID | None = None
    sucursal_id: UUID | None = None
    usuario_id: UUID
    modulo: str
    tabla: str
    registro_id: UUID | None = None
    accion: str
    datos_anteriores: dict[str, Any] | None = None
    datos_nuevos: dict[str, Any] | None = None
    cambios_especificos: dict[str, Any] | None = None
    ip_address: str | None = None
    user_agent: str | None = None
    dispositivo: str | None = None
    ubicacion_geografica: dict[str, Any] | None = None