"""
Router de Cajas, Sesiones y Movimientos de Caja — solo lógica HTTP.

Flujo de sesión:
  abrir → [movimientos] → cerrar → auditar

Seguridad:
  --- Cajas ---
  GET    /cajas/                         → admin_empresa o super_admin
  GET    /cajas/{id}                     → admin_empresa o super_admin
  POST   /cajas/                         → admin_empresa o super_admin
  PATCH  /cajas/{id}                     → admin_empresa o super_admin
  DELETE /cajas/{id}                     → admin_empresa o super_admin [soft]
  DELETE /cajas/{id}/hard                → solo super_admin

  --- Sesiones ---
  GET    /cajas/{id}/sesiones            → admin_empresa o super_admin
  GET    /cajas/{id}/sesiones/activa     → autenticado + misma sucursal
  GET    /cajas/sesiones/{sesion_id}     → admin_empresa o super_admin
  POST   /cajas/{id}/sesiones/abrir      → autenticado + misma sucursal
  PATCH  /cajas/sesiones/{id}/cerrar     → autenticado (el que la abrió) o admin
  PATCH  /cajas/sesiones/{id}/auditar    → solo admin_empresa o super_admin

  --- Movimientos ---
  GET    /cajas/sesiones/{id}/movimientos        → autenticado + misma sucursal
  POST   /cajas/sesiones/{id}/movimientos        → autenticado + sesión abierta
  DELETE /cajas/sesiones/{id}/movimientos/{m_id} → solo super_admin
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
    ForbiddenException,
    NotFoundException,
)
from ...core.limiter import get_user_id_from_token, limiter
from ...core.metrics import cajas_aperturas, cajas_cierres, cajas_sesiones_abiertas
from ...core.pagination import PaginatedResponse
from ...core.security import (
    get_current_admin,
    get_current_superadmin,
    get_current_user,
    verify_empresa_access,
    verify_sucursal_access,
)
from ...crud.crud_cajas import (
    abrir_sesion,
    auditar_sesion,
    caja_codigo_exists,
    cerrar_sesion,
    create_caja,
    create_movimiento_caja,
    get_caja,
    get_cajas,
    get_movimiento_caja,
    get_movimientos_caja,
    get_sesion,
    get_sesion_abierta,
    get_sesiones,
    hard_delete_caja,
    hard_delete_movimiento_caja,
    numero_sesion_exists,
    sesion_abierta_exists,
    soft_delete_caja,
    update_caja,
)
from ...crud.crud_sucursales import get_sucursal
from ...database import get_supabase
from ...schemas.caja import (
    CajaCreate,
    CajaCreateInternal,
    CajaRead,
    CajaUpdate,
    CajaUpdateInternal,
    MovimientoCajaCreate,
    MovimientoCajaRead,
    SesionCajaApertura,
    SesionCajaCierre,
    SesionCajaRead,
)

router = APIRouter(prefix="/cajas", tags=["Cajas"])


def _get_empresa_id(db: Client, sucursal_id: UUID) -> UUID:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")
    return UUID(str(sucursal["empresa_id"]))


def _get_caja_verificada(db: Client, caja_id: UUID, current_user: dict) -> dict:
    caja = get_caja(db, caja_id)
    if not caja:
        raise NotFoundException("Caja no encontrada")
    empresa_id = _get_empresa_id(db, UUID(str(caja["sucursal_id"])))
    verify_empresa_access(current_user, empresa_id)
    return caja


def _get_sesion_verificada(db: Client, sesion_id: UUID, current_user: dict) -> dict:
    sesion = get_sesion(db, sesion_id)
    if not sesion:
        raise NotFoundException("Sesión de caja no encontrada")
    caja = get_caja(db, UUID(str(sesion["caja_id"])))
    if caja:
        empresa_id = _get_empresa_id(db, UUID(str(caja["sucursal_id"])))
        verify_empresa_access(current_user, empresa_id)
    return sesion


# ══════════════════════════════════════════════════════════════════════════════
# CAJAS
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/", response_model=PaginatedResponse[CajaRead], summary="Listar cajas de una sucursal")
def read_cajas(
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "nombre",
    order_desc: bool = False,
    tipo: str | None = None,
    estado: str | None = None,
) -> dict:
    empresa_id = _get_empresa_id(db, sucursal_id)
    verify_empresa_access(current_user, empresa_id)
    return get_cajas(db=db, sucursal_id=sucursal_id, page=page,
                     items_per_page=items_per_page, order_by=order_by,
                     order_desc=order_desc, tipo=tipo, estado=estado)


@router.get("/{caja_id}", response_model=CajaRead, summary="Obtener caja")
def read_caja(
    caja_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    return _get_caja_verificada(db, caja_id, current_user)


@router.post("/", response_model=CajaRead, status_code=status.HTTP_201_CREATED, summary="Crear caja")
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def write_caja(
    request: Request,
    data: CajaCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    empresa_id = _get_empresa_id(db, data.sucursal_id)
    verify_empresa_access(current_user, empresa_id)

    if caja_codigo_exists(db, data.sucursal_id, data.codigo):
        raise DuplicateValueException(f"El código '{data.codigo}' ya existe en esta sucursal")

    nueva = create_caja(db, CajaCreateInternal(**data.model_dump()))
    logger.info("Caja creada | id={id} | nombre={nombre} | por={admin}",
                id=nueva.get("id"), nombre=nueva.get("nombre"), admin=current_user.get("email"))
    return nueva


@router.patch("/{caja_id}", response_model=CajaRead, summary="Actualizar caja")
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def patch_caja(
    request: Request,
    caja_id: UUID,
    values: CajaUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    caja = _get_caja_verificada(db, caja_id, current_user)
    internal = CajaUpdateInternal(**values.model_dump(exclude_unset=True), updated_at=datetime.now(UTC))
    updated = update_caja(db, caja_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar la caja")
    logger.info("Caja actualizada | id={id} | por={admin}", id=str(caja_id), admin=current_user.get("email"))
    return updated


@router.delete("/{caja_id}", status_code=status.HTTP_200_OK, summary="Desactivar caja")
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def delete_caja(
    request: Request,
    caja_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    caja = _get_caja_verificada(db, caja_id, current_user)
    if sesion_abierta_exists(db, caja_id):
        raise BadRequestException("No se puede desactivar una caja con sesión abierta")
    soft_delete_caja(db, caja_id)
    logger.warning("Caja desactivada [soft] | id={id} | nombre={nombre} | por={admin}",
                   id=str(caja_id), nombre=caja.get("nombre"), admin=current_user.get("email"))
    return {"message": f"Caja '{caja['nombre']}' desactivada correctamente"}


@router.delete("/{caja_id}/hard", status_code=status.HTTP_200_OK, summary="Eliminar caja permanentemente")
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_caja_endpoint(
    request: Request,
    caja_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    caja = get_caja(db, caja_id)
    if not caja:
        raise NotFoundException("Caja no encontrada")
    if sesion_abierta_exists(db, caja_id):
        raise BadRequestException("No se puede eliminar una caja con sesión abierta")
    hard_delete_caja(db, caja_id)
    logger.warning("Caja ELIMINADA [hard] | id={id} | nombre={nombre} | por={admin}",
                   id=str(caja_id), nombre=caja.get("nombre"), admin=current_user.get("email"))
    return {"message": f"Caja '{caja['nombre']}' eliminada permanentemente"}


# ══════════════════════════════════════════════════════════════════════════════
# SESIONES DE CAJA
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/{caja_id}/sesiones", response_model=PaginatedResponse[SesionCajaRead], summary="Listar sesiones de una caja")
def read_sesiones(
    caja_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "fecha_apertura",
    order_desc: bool = True,
    estado: str | None = None,
    usuario_id: UUID | None = None,
) -> dict:
    _get_caja_verificada(db, caja_id, current_user)
    return get_sesiones(db=db, caja_id=caja_id, page=page, items_per_page=items_per_page,
                        order_by=order_by, order_desc=order_desc, estado=estado, usuario_id=usuario_id)


@router.get("/{caja_id}/sesiones/activa", response_model=SesionCajaRead, summary="Obtener sesión activa de una caja")
def read_sesion_activa(
    caja_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    _get_caja_verificada(db, caja_id, current_user)
    sesion = get_sesion_abierta(db, caja_id)
    if not sesion:
        raise NotFoundException("No hay sesión abierta en esta caja")
    return sesion


@router.get("/sesiones/{sesion_id}", response_model=SesionCajaRead, summary="Obtener sesión por ID")
def read_sesion(
    sesion_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    return _get_sesion_verificada(db, sesion_id, current_user)


@router.post("/{caja_id}/sesiones/abrir", response_model=SesionCajaRead,
             status_code=status.HTTP_201_CREATED, summary="Abrir sesión de caja")
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def abrir_sesion_endpoint(
    request: Request,
    caja_id: UUID,
    data: SesionCajaApertura,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    caja = get_caja(db, caja_id)
    if not caja:
        raise NotFoundException("Caja no encontrada")
    if caja["estado"] != "activo":
        raise BadRequestException(f"La caja está '{caja['estado']}'. Solo se puede abrir una caja activa.")
    empresa_id = _get_empresa_id(db, UUID(str(caja["sucursal_id"])))
    verify_empresa_access(current_user, empresa_id)

    if sesion_abierta_exists(db, caja_id):
        raise BadRequestException("La caja ya tiene una sesión abierta")
    if numero_sesion_exists(db, caja_id, data.numero_sesion):
        raise DuplicateValueException(f"El número de sesión '{data.numero_sesion}' ya existe en esta caja")

    # Forzar caja_id del path
    data_dict = data.model_dump()
    data_dict["caja_id"] = caja_id
    nueva = abrir_sesion(db, SesionCajaApertura(**data_dict), UUID(str(current_user["id"])))

    logger.info("Sesión abierta | caja={caja} | numero={num} | monto={monto} | por={admin}",
                caja=str(caja_id), num=data.numero_sesion,
                monto=str(data.monto_apertura), admin=current_user.get("email"))
    cajas_aperturas.inc()
    cajas_sesiones_abiertas.inc()
    return nueva


@router.patch("/sesiones/{sesion_id}/cerrar", response_model=SesionCajaRead, summary="Cerrar sesión de caja")
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def cerrar_sesion_endpoint(
    request: Request,
    sesion_id: UUID,
    data: SesionCajaCierre,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    sesion = _get_sesion_verificada(db, sesion_id, current_user)
    if sesion["estado"] != "abierta":
        raise BadRequestException(f"La sesión está '{sesion['estado']}'. Solo se puede cerrar una sesión abierta.")

    # Solo el cajero que la abrió o un admin puede cerrarla
    rol = current_user.get("rol_global")
    if rol == "empleado" and str(sesion["usuario_id"]) != str(current_user["id"]):
        raise ForbiddenException("Solo puedes cerrar sesiones que tú abriste")

    updated = cerrar_sesion(db, sesion_id, data)
    if not updated:
        raise NotFoundException("No se pudo cerrar la sesión")

    logger.warning("Sesión cerrada | id={id} | monto_cierre={monto} | diferencia={dif} | por={admin}",
                   id=str(sesion_id), monto=str(data.monto_cierre),
                   dif=str(updated.get("diferencia")), admin=current_user.get("email"))
    cajas_cierres.inc()
    cajas_sesiones_abiertas.dec()
    return updated


@router.patch("/sesiones/{sesion_id}/auditar", response_model=SesionCajaRead, summary="Auditar sesión de caja")
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def auditar_sesion_endpoint(
    request: Request,
    sesion_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    sesion = _get_sesion_verificada(db, sesion_id, current_user)
    if sesion["estado"] != "cerrada":
        raise BadRequestException("Solo se pueden auditar sesiones cerradas")
    updated = auditar_sesion(db, sesion_id)
    if not updated:
        raise NotFoundException("No se pudo auditar la sesión")
    logger.warning("Sesión auditada | id={id} | por={admin}",
                   id=str(sesion_id), admin=current_user.get("email"))
    return updated


# ══════════════════════════════════════════════════════════════════════════════
# MOVIMIENTOS DE CAJA
# ══════════════════════════════════════════════════════════════════════════════

@router.get("/sesiones/{sesion_id}/movimientos",
            response_model=PaginatedResponse[MovimientoCajaRead],
            summary="Listar movimientos de una sesión")
def read_movimientos_caja(
    sesion_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 50,
    order_by: str = "created_at",
    order_desc: bool = True,
    tipo: str | None = None,
) -> dict:
    _get_sesion_verificada(db, sesion_id, current_user)
    return get_movimientos_caja(db=db, sesion_id=sesion_id, page=page,
                                items_per_page=items_per_page, order_by=order_by,
                                order_desc=order_desc, tipo=tipo)


@router.post("/sesiones/{sesion_id}/movimientos",
             response_model=MovimientoCajaRead,
             status_code=status.HTTP_201_CREATED,
             summary="Registrar movimiento en sesión",
             description="Registra una entrada o salida de efectivo. Actualiza los totales de la sesión automáticamente.")
@limiter.limit("120/hour", key_func=get_user_id_from_token)
def write_movimiento_caja(
    request: Request,
    sesion_id: UUID,
    data: MovimientoCajaCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    sesion = _get_sesion_verificada(db, sesion_id, current_user)
    if sesion["estado"] != "abierta":
        raise BadRequestException("Solo se pueden registrar movimientos en sesiones abiertas")

    nuevo = create_movimiento_caja(db, sesion_id, data, UUID(str(current_user["id"])))

    logger.info("Movimiento caja | sesion={ses} | tipo={tipo} | monto={monto} | por={admin}",
                ses=str(sesion_id), tipo=data.tipo,
                monto=str(data.monto), admin=current_user.get("email"))
    return nuevo


@router.delete("/sesiones/{sesion_id}/movimientos/{movimiento_id}",
               status_code=status.HTTP_200_OK,
               summary="Eliminar movimiento de caja",
               description="**Solo super_admin.** Para corrección de errores. No revierte los totales de la sesión.")
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_movimiento_caja_endpoint(
    request: Request,
    sesion_id: UUID,
    movimiento_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    mov = get_movimiento_caja(db, movimiento_id)
    if not mov:
        raise NotFoundException("Movimiento no encontrado")
    if str(mov["sesion_caja_id"]) != str(sesion_id):
        raise NotFoundException("El movimiento no pertenece a esta sesión")
    hard_delete_movimiento_caja(db, movimiento_id)
    logger.warning("Movimiento caja ELIMINADO [hard] | id={id} | por={admin}",
                   id=str(movimiento_id), admin=current_user.get("email"))
    return {"message": "Movimiento eliminado. Los totales de la sesión no fueron revertidos."}