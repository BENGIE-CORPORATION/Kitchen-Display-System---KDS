"""
Router de Auditoría e Historial de Estados — solo lectura.

Estas tablas son append-only. No hay endpoints de creación pública —
los registros se insertan automáticamente desde otros módulos.

Puntos de inserción automática (pendiente integrar):
  - crud_pedidos.cambiar_estado_pedido  → historial_estados_pedido
  - crud_pedidos.cancelar_detalle_item  → historial_estados_detalle
  - auth router (login/logout)          → auditoria
  - Cualquier hard delete               → auditoria

Seguridad:
  GET /pedidos/{id}/historial            → admin_empresa o super_admin
  GET /pedidos/{id}/items/{id}/historial → admin_empresa o super_admin
  GET /auditoria/                        → solo super_admin
  GET /auditoria/registro/{tabla}/{id}   → admin_empresa o super_admin
"""

from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    NotFoundException,
)
from ...core.pagination import PaginatedResponse
from ...core.security import (
    get_current_admin,
    get_current_superadmin,
    verify_empresa_access,
)
from ...crud.crud_auditoria import (
    get_auditoria,
    get_auditoria_por_registro,
    get_historial_detalle,
    get_historial_pedido,
)
from ...crud.crud_pedidos import get_detalle_item, get_pedido
from ...database import get_supabase
from ...schemas.auditoria import (
    AuditoriaRead,
    HistorialEstadetalleRead,
    HistorialEstadoPedidoRead,
)

router = APIRouter(tags=["Auditoría e Historial"])


# ─── GET /pedidos/{id}/historial ──────────────────────────────────────────────

@router.get(
    "/pedidos/{pedido_id}/historial",
    response_model=PaginatedResponse[HistorialEstadoPedidoRead],
    summary="Historial de estados de un pedido",
    description="Lista todos los cambios de estado del pedido en orden cronológico inverso.",
)
def read_historial_pedido(
    pedido_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 50,
    campo_modificado: str | None = None,
) -> dict:
    pedido = get_pedido(db, pedido_id)
    if not pedido:
        raise NotFoundException("Pedido no encontrado")
    verify_empresa_access(current_user, UUID(str(pedido["empresa_id"])))

    return get_historial_pedido(
        db=db, pedido_id=pedido_id, page=page,
        items_per_page=items_per_page, campo_modificado=campo_modificado,
    )


# ─── GET /pedidos/{id}/items/{item_id}/historial ──────────────────────────────

@router.get(
    "/pedidos/{pedido_id}/items/{item_id}/historial",
    response_model=PaginatedResponse[HistorialEstadetalleRead],
    summary="Historial de estados de un ítem de pedido",
)
def read_historial_detalle(
    pedido_id: UUID,
    item_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 50,
) -> dict:
    pedido = get_pedido(db, pedido_id)
    if not pedido:
        raise NotFoundException("Pedido no encontrado")
    verify_empresa_access(current_user, UUID(str(pedido["empresa_id"])))

    item = get_detalle_item(db, item_id)
    if not item or str(item["pedido_id"]) != str(pedido_id):
        raise NotFoundException("Ítem no encontrado en este pedido")

    return get_historial_detalle(
        db=db, detalle_pedido_id=item_id,
        page=page, items_per_page=items_per_page,
    )


# ─── GET /auditoria/ ──────────────────────────────────────────────────────────

@router.get(
    "/auditoria/",
    response_model=PaginatedResponse[AuditoriaRead],
    summary="Consultar log de auditoría",
    description="**Solo super_admin.** Log completo de todas las acciones del sistema.",
)
def read_auditoria(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 50,
    order_by: str = "created_at",
    order_desc: bool = True,
    empresa_id: UUID | None = None,
    sucursal_id: UUID | None = None,
    usuario_id: UUID | None = None,
    modulo: str | None = None,
    tabla: str | None = None,
    accion: str | None = None,
    registro_id: UUID | None = None,
    fecha_desde: datetime | None = None,
    fecha_hasta: datetime | None = None,
) -> dict:
    return get_auditoria(
        db=db, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc,
        empresa_id=empresa_id, sucursal_id=sucursal_id,
        usuario_id=usuario_id, modulo=modulo, tabla=tabla,
        accion=accion, registro_id=registro_id,
        fecha_desde=fecha_desde, fecha_hasta=fecha_hasta,
    )


# ─── GET /auditoria/registro/{tabla}/{id} ─────────────────────────────────────

@router.get(
    "/auditoria/registro/{tabla}/{registro_id}",
    response_model=list[AuditoriaRead],
    summary="Historial de auditoría de un registro específico",
    description="Retorna todos los eventos de auditoría de un registro puntual.",
)
def read_auditoria_registro(
    tabla: str,
    registro_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> list:
    from ...models.auditoria import MODULOS_VALIDOS
    tablas_validas = {
        "pedidos", "detalle_pedidos", "productos", "categorias",
        "clientes", "proveedores", "empleados", "cajas", "sesiones_caja",
        "ordenes_compra", "movimientos_inventario",
    }
    if tabla not in tablas_validas:
        raise BadRequestException(
            f"Tabla inválida. Opciones: {', '.join(sorted(tablas_validas))}"
        )
    return get_auditoria_por_registro(db, tabla, registro_id)