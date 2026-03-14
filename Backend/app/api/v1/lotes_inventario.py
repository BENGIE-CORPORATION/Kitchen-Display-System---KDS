"""
Router de Lotes de Inventario — solo lógica HTTP.

Seguridad:
  GET    /lotes/                    → admin_empresa o super_admin
  GET    /lotes/{id}                → admin_empresa o super_admin
  POST   /lotes/                    → admin_empresa o super_admin
  PATCH  /lotes/{id}                → admin_empresa o super_admin
  PATCH  /lotes/{id}/vencidos       → admin_empresa o super_admin (marcar lotes vencidos en sucursal)
  DELETE /lotes/{id}/hard           → solo super_admin (agotados o error de registro)
"""

from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, status
from loguru import logger
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    NotFoundException,
)
from ...core.limiter import get_user_id_from_token, limiter
from ...core.pagination import PaginatedResponse
from ...core.security import (
    get_current_admin,
    get_current_superadmin,
    verify_empresa_access,
)
from ...crud.crud_lotes_inventario import (
    create_lote,
    get_lote,
    get_lotes,
    hard_delete_lote,
    marcar_lotes_vencidos,
    numero_lote_exists,
    update_lote,
)
from ...crud.crud_materias_primas import get_materia_prima
from ...crud.crud_productos import get_producto
from ...crud.crud_sucursales import get_sucursal
from ...database import get_supabase
from ...schemas.lote_inventario import (
    LoteInventarioCreate,
    LoteInventarioCreateInternal,
    LoteInventarioRead,
    LoteInventarioUpdate,
)

router = APIRouter(prefix="/lotes", tags=["Lotes de Inventario"])


def _get_empresa_id_de_sucursal(db: Client, sucursal_id: UUID) -> UUID:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")
    return UUID(str(sucursal["empresa_id"]))


# ─── GET /lotes/ ──────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[LoteInventarioRead],
    summary="Listar lotes de inventario",
    description="Filtra por sucursal obligatoriamente. Opcionalmente por materia prima, producto o estado.",
)
def read_lotes(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    sucursal_id: UUID,
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "fecha_ingreso",
    order_desc: bool = True,
    materia_prima_id: UUID | None = None,
    producto_id: UUID | None = None,
    estado: str | None = None,
    proximos_a_vencer: int | None = Query(default=None, ge=1, le=365),
) -> dict:
    empresa_id = _get_empresa_id_de_sucursal(db, sucursal_id)
    verify_empresa_access(current_user, empresa_id)

    return get_lotes(
        db=db, sucursal_id=sucursal_id, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc, materia_prima_id=materia_prima_id,
        producto_id=producto_id, estado=estado, proximos_a_vencer=proximos_a_vencer,
    )


# ─── GET /lotes/{id} ──────────────────────────────────────────────────────────

@router.get("/{lote_id}", response_model=LoteInventarioRead, summary="Obtener lote")
def read_lote(
    lote_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    lote = get_lote(db, lote_id)
    if not lote:
        raise NotFoundException("Lote no encontrado")
    empresa_id = _get_empresa_id_de_sucursal(db, UUID(str(lote["sucursal_id"])))
    verify_empresa_access(current_user, empresa_id)
    return lote


# ─── POST /lotes/ ─────────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=LoteInventarioRead,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar lote de inventario",
    description="Registra un lote nuevo. `cantidad_actual` se inicializa igual a `cantidad_inicial`.",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def write_lote(
    request: Request,
    data: LoteInventarioCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    empresa_id = _get_empresa_id_de_sucursal(db, data.sucursal_id)
    verify_empresa_access(current_user, empresa_id)

    # Validar referencia y que pertenezca a la empresa
    if data.materia_prima_id:
        mp = get_materia_prima(db, data.materia_prima_id)
        if not mp:
            raise NotFoundException("Materia prima no encontrada")
        if str(mp["empresa_id"]) != str(empresa_id):
            raise BadRequestException("La materia prima no pertenece a esta empresa")

    if data.producto_id:
        prod = get_producto(db, data.producto_id)
        if not prod:
            raise NotFoundException("Producto no encontrado")
        if str(prod["empresa_id"]) != str(empresa_id):
            raise BadRequestException("El producto no pertenece a esta empresa")

    if numero_lote_exists(db, data.sucursal_id, data.numero_lote):
        raise DuplicateValueException(
            f"El número de lote '{data.numero_lote}' ya existe en esta sucursal"
        )

    internal = LoteInventarioCreateInternal(**data.model_dump())
    nuevo = create_lote(db, internal)

    logger.info(
        "Lote creado | id={id} | numero={num} | sucursal={suc} | por={admin}",
        id=nuevo.get("id"),
        num=nuevo.get("numero_lote"),
        suc=str(data.sucursal_id),
        admin=current_user.get("email"),
    )
    return nuevo


# ─── PATCH /lotes/{id} ────────────────────────────────────────────────────────

@router.patch("/{lote_id}", response_model=LoteInventarioRead, summary="Actualizar lote")
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def patch_lote(
    request: Request,
    lote_id: UUID,
    values: LoteInventarioUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    lote = get_lote(db, lote_id)
    if not lote:
        raise NotFoundException("Lote no encontrado")

    empresa_id = _get_empresa_id_de_sucursal(db, UUID(str(lote["sucursal_id"])))
    verify_empresa_access(current_user, empresa_id)

    if lote["estado"] == "agotado":
        raise BadRequestException("No se puede modificar un lote agotado")

    # Validar que cantidad_actual no supere cantidad_inicial
    if values.cantidad_actual is not None:
        if float(values.cantidad_actual) > float(lote["cantidad_inicial"]):
            raise BadRequestException(
                f"La cantidad actual ({values.cantidad_actual}) no puede superar "
                f"la cantidad inicial ({lote['cantidad_inicial']})"
            )

    updated = update_lote(db, lote_id, values)
    if not updated:
        raise NotFoundException("No se pudo actualizar el lote")

    logger.info(
        "Lote actualizado | id={id} | por={admin}",
        id=str(lote_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── PATCH /lotes/vencidos ────────────────────────────────────────────────────

@router.patch(
    "/vencidos/marcar",
    status_code=status.HTTP_200_OK,
    summary="Marcar lotes vencidos en una sucursal",
    description="Revisa todos los lotes activos de la sucursal y marca como 'vencido' los que ya pasaron su fecha.",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def marcar_vencidos(
    request: Request,
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    empresa_id = _get_empresa_id_de_sucursal(db, sucursal_id)
    verify_empresa_access(current_user, empresa_id)

    afectados = marcar_lotes_vencidos(db, sucursal_id)

    logger.warning(
        "Lotes vencidos marcados | sucursal={suc} | cantidad={n} | por={admin}",
        suc=str(sucursal_id),
        n=afectados,
        admin=current_user.get("email"),
    )
    return {
        "message": f"{afectados} lote(s) marcados como vencidos",
        "lotes_afectados": afectados,
    }


# ─── DELETE /lotes/{id}/hard ──────────────────────────────────────────────────

@router.delete(
    "/{lote_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar lote permanentemente",
    description="**Solo super_admin.** Solo permitido en lotes 'agotado' o 'vencido'.",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_lote_endpoint(
    request: Request,
    lote_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    lote = get_lote(db, lote_id)
    if not lote:
        raise NotFoundException("Lote no encontrado")

    if lote["estado"] == "activo":
        raise BadRequestException(
            "No se puede eliminar un lote activo. "
            "Solo se permiten lotes 'agotado' o 'vencido'."
        )

    hard_delete_lote(db, lote_id)

    logger.warning(
        "Lote ELIMINADO [hard] | id={id} | numero={num} | estado={estado} | por={admin}",
        id=str(lote_id),
        num=lote.get("numero_lote"),
        estado=lote.get("estado"),
        admin=current_user.get("email"),
    )
    return {"message": f"Lote '{lote['numero_lote']}' eliminado permanentemente"}