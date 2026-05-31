"""
Router de Métodos de Pago — solo lógica HTTP.

Reglas de negocio:
  - El código es único por empresa (ej: "efectivo", "visa_credito").
  - Un método desactivado (soft delete) sigue visible para historial.
  - No se puede modificar el campo 'codigo' una vez creado (identidad del método).

Seguridad:
  GET    /metodos-pago/          → autenticado (empleados ven los de su empresa)
  GET    /metodos-pago/{id}      → autenticado + misma empresa
  POST   /metodos-pago/          → admin_empresa o super_admin
  PATCH  /metodos-pago/{id}      → admin_empresa o super_admin
  DELETE /metodos-pago/{id}      → admin_empresa o super_admin [soft]
  DELETE /metodos-pago/{id}/hard → solo super_admin
"""

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
    get_current_user,
    verify_empresa_access,
)
from ...crud.crud_metodos_pago import (
    create_metodo_pago,
    get_metodo_pago,
    get_metodos_pago,
    hard_delete_metodo_pago,
    metodo_pago_codigo_exists,
    soft_delete_metodo_pago,
    update_metodo_pago,
)
from ...database import get_supabase
from ...schemas.metodo_pago import (
    MetodoPagoCreate,
    MetodoPagoRead,
    MetodoPagoUpdate,
)

router = APIRouter(prefix="/metodos-pago", tags=["Métodos de Pago"])


def _get_metodo_verificado(db: Client, metodo_id: UUID, current_user: dict) -> dict:
    metodo = get_metodo_pago(db, metodo_id)
    if not metodo:
        raise NotFoundException("Método de pago no encontrado")
    verify_empresa_access(current_user, UUID(str(metodo["empresa_id"])))
    return metodo


def _get_empresa_id(current_user: dict, empresa_id: UUID | None) -> UUID:
    if current_user["rol_global"] == "super_admin":
        if not empresa_id:
            raise BadRequestException("super_admin debe especificar empresa_id como query param")
        return empresa_id
    return UUID(str(current_user["empresa_id"]))


# ─── GET /metodos-pago/ ───────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[MetodoPagoRead],
    summary="Listar métodos de pago",
)
def read_metodos_pago(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 50,
    order_by: str = "nombre",
    order_desc: bool = False,
    tipo: str | None = None,
    solo_activos: bool = True,
    empresa_id: UUID | None = None,
) -> dict:
    target = _get_empresa_id(current_user, empresa_id)
    return get_metodos_pago(
        db=db, empresa_id=target, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc, tipo=tipo, solo_activos=solo_activos,
    )


# ─── GET /metodos-pago/{id} ───────────────────────────────────────────────────

@router.get("/{metodo_id}", response_model=MetodoPagoRead, summary="Obtener método de pago")
def read_metodo_pago(
    metodo_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    return _get_metodo_verificado(db, metodo_id, current_user)


# ─── POST /metodos-pago/ ──────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=MetodoPagoRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear método de pago",
    description="El código debe ser único por empresa. No se puede cambiar después de crearlo.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def write_metodo_pago(
    request: Request,
    data: MetodoPagoCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    verify_empresa_access(current_user, data.empresa_id)

    if metodo_pago_codigo_exists(db, data.empresa_id, data.codigo):
        raise DuplicateValueException(
            f"Ya existe un método de pago con código '{data.codigo}' en esta empresa"
        )

    nuevo = create_metodo_pago(db, data, created_by=UUID(str(current_user["id"])))
    logger.info(
        "Método de pago creado | id={id} | codigo={codigo} | tipo={tipo} | por={admin}",
        id=nuevo.get("id"), codigo=nuevo.get("codigo"),
        tipo=nuevo.get("tipo"), admin=current_user.get("email"),
    )
    return nuevo


# ─── PATCH /metodos-pago/{id} ─────────────────────────────────────────────────

@router.patch(
    "/{metodo_id}",
    response_model=MetodoPagoRead,
    summary="Actualizar método de pago",
    description="No se puede modificar el campo 'codigo'.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def patch_metodo_pago(
    request: Request,
    metodo_id: UUID,
    values: MetodoPagoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    _get_metodo_verificado(db, metodo_id, current_user)
    updated = update_metodo_pago(db, metodo_id, values, UUID(str(current_user["id"])))
    if not updated:
        raise NotFoundException("No se pudo actualizar el método de pago")
    logger.info("Método de pago actualizado | id={id} | por={admin}",
                id=str(metodo_id), admin=current_user.get("email"))
    return updated


# ─── DELETE /metodos-pago/{id} ────────────────────────────────────────────────

@router.delete(
    "/{metodo_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar método de pago (soft delete)",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)
def delete_metodo_pago(
    request: Request,
    metodo_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    metodo = _get_metodo_verificado(db, metodo_id, current_user)
    if not metodo["is_active"]:
        raise BadRequestException("El método de pago ya está desactivado")
    soft_delete_metodo_pago(db, metodo_id, UUID(str(current_user["id"])))
    logger.warning("Método de pago desactivado | id={id} | codigo={codigo} | por={admin}",
                   id=str(metodo_id), codigo=metodo.get("codigo"),
                   admin=current_user.get("email"))
    return {"message": f"Método de pago '{metodo['nombre']}' desactivado"}


# ─── DELETE /metodos-pago/{id}/hard ───────────────────────────────────────────

@router.delete(
    "/{metodo_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar método de pago permanentemente",
    description="**Solo super_admin.**",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_metodo_pago_endpoint(
    request: Request,
    metodo_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],
) -> dict:
    metodo = get_metodo_pago(db, metodo_id)
    if not metodo:
        raise NotFoundException("Método de pago no encontrado")
    hard_delete_metodo_pago(db, metodo_id)
    logger.warning(
        "Método de pago ELIMINADO [hard] | id={id} | codigo={codigo} | por={admin}",
        id=str(metodo_id), codigo=metodo.get("codigo"),
        admin=current_user.get("email"),
    )
    return {"message": f"Método de pago '{metodo['nombre']}' eliminado permanentemente"}
