"""
Router de Materias Primas — solo lógica HTTP.

Seguridad:
  GET    /materias-primas/                          → admin_empresa o super_admin
  GET    /materias-primas/{id}                      → admin_empresa o super_admin
  GET    /materias-primas/sucursal/{sucursal_id}    → admin_empresa o super_admin
  POST   /materias-primas/                          → admin_empresa o super_admin
  PATCH  /materias-primas/{id}                      → admin_empresa o super_admin
  DELETE /materias-primas/{id}                      → admin_empresa o super_admin [soft]
  DELETE /materias-primas/{id}/hard                 → solo super_admin

  --- Stock por sucursal ---
  GET    /materias-primas/{id}/sucursales/{suc_id}  → admin_empresa o super_admin
  POST   /materias-primas/{id}/sucursales            → admin_empresa o super_admin
  PATCH  /materias-primas/sucursales/{mps_id}        → admin_empresa o super_admin
  DELETE /materias-primas/sucursales/{mps_id}        → admin_empresa o super_admin
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
    get_current_user,
    verify_empresa_access,
    verify_sucursal_access,
)
from ...crud.crud_materias_primas import (
    create_materia_prima,
    create_materia_prima_sucursal,
    delete_materia_prima_sucursal,
    get_materia_prima,
    get_materia_prima_sucursal,
    get_materia_prima_sucursal_by_id,
    get_materias_primas,
    get_materias_primas_por_sucursal,
    hard_delete_materia_prima,
    materia_prima_codigo_exists,
    materia_prima_sucursal_exists,
    soft_delete_materia_prima,
    update_materia_prima,
    update_materia_prima_sucursal,
)
from ...crud.crud_sucursales import get_sucursal
from ...database import get_supabase
from ...schemas.materia_prima import (
    MateriaPrimaCreate,
    MateriaPrimaCreateInternal,
    MateriaPrimaRead,
    MateriaPrimaSucursalCreate,
    MateriaPrimaSucursalRead,
    MateriaPrimaSucursalUpdate,
    MateriaPrimaSucursalUpdateInternal,
    MateriaPrimaUpdate,
    MateriaPrimaUpdateInternal,
)

router = APIRouter(prefix="/materias-primas", tags=["Materias Primas"])


# ─── GET /materias-primas/ ────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[MateriaPrimaRead],
    summary="Listar materias primas",
    description="admin_empresa ve solo su empresa. super_admin debe especificar empresa_id.",
)
def read_materias_primas(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "nombre",
    order_desc: bool = False,
    categoria: str | None = None,
    unidad_medida: str | None = None,
    perecedero: bool | None = None,
    estado: str | None = None,
    search: str | None = None,
    empresa_id: UUID | None = None,
) -> dict:
    if current_user["rol_global"] == "super_admin":
        if not empresa_id:
            raise BadRequestException("super_admin debe especificar empresa_id como query param")
        target = empresa_id
    else:
        target = UUID(str(current_user["empresa_id"]))

    return get_materias_primas(
        db=db, empresa_id=target, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc, categoria=categoria,
        unidad_medida=unidad_medida, perecedero=perecedero, estado=estado, search=search,
    )


# ─── GET /materias-primas/sucursal/{sucursal_id} ──────────────────────────────

@router.get(
    "/sucursal/{sucursal_id}",
    response_model=PaginatedResponse[MateriaPrimaSucursalRead],
    summary="Listar materias primas con stock de una sucursal",
)
def read_materias_por_sucursal(
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    bajo_minimo: bool = False,
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")

    if current_user["rol_global"] == "empleado":
        verify_sucursal_access(db, current_user, sucursal_id)  # 🔒 asignación activa
    else:
        verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))  # 🔒 su empresa

    return get_materias_primas_por_sucursal(
        db=db, sucursal_id=sucursal_id,
        page=page, items_per_page=items_per_page,
        bajo_minimo=bajo_minimo,
    )


# ─── GET /materias-primas/{id} ────────────────────────────────────────────────

@router.get("/{materia_prima_id}", response_model=MateriaPrimaRead, summary="Obtener materia prima")
def read_materia_prima(
    materia_prima_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    mp = get_materia_prima(db, materia_prima_id)
    if not mp:
        raise NotFoundException("Materia prima no encontrada")
    verify_empresa_access(current_user, UUID(str(mp["empresa_id"])))
    return mp


# ─── POST /materias-primas/ ───────────────────────────────────────────────────

@router.post(
    "/",
    response_model=MateriaPrimaRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear materia prima",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def write_materia_prima(
    request: Request,
    data: MateriaPrimaCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    verify_empresa_access(current_user, data.empresa_id)

    if data.codigo and materia_prima_codigo_exists(db, data.empresa_id, data.codigo):
        raise DuplicateValueException(
            f"El código '{data.codigo}' ya existe en esta empresa"
        )

    if data.perecedero and not data.dias_vida_util:
        raise BadRequestException(
            "Las materias primas perecederas requieren 'dias_vida_util'"
        )

    internal = MateriaPrimaCreateInternal(
        **data.model_dump(),
        created_by=UUID(str(current_user["id"])),
    )
    nueva = create_materia_prima(db, internal)

    logger.info(
        "Materia prima creada | id={id} | nombre={nombre} | empresa={emp} | por={admin}",
        id=nueva.get("id"),
        nombre=nueva.get("nombre"),
        emp=str(data.empresa_id),
        admin=current_user.get("email"),
    )
    return nueva


# ─── PATCH /materias-primas/{id} ──────────────────────────────────────────────

@router.patch("/{materia_prima_id}", response_model=MateriaPrimaRead, summary="Actualizar materia prima")
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def patch_materia_prima(
    request: Request,
    materia_prima_id: UUID,
    values: MateriaPrimaUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    mp = get_materia_prima(db, materia_prima_id)
    if not mp:
        raise NotFoundException("Materia prima no encontrada")
    verify_empresa_access(current_user, UUID(str(mp["empresa_id"])))

    if values.codigo and values.codigo.upper() != mp.get("codigo"):
        if materia_prima_codigo_exists(db, UUID(str(mp["empresa_id"])), values.codigo, exclude_id=materia_prima_id):
            raise DuplicateValueException(f"El código '{values.codigo}' ya existe en esta empresa")

    # Validar perecedero + dias_vida_util en conjunto
    es_perecedero = values.perecedero if values.perecedero is not None else mp.get("perecedero", False)
    tiene_dias = values.dias_vida_util or mp.get("dias_vida_util")
    if es_perecedero and not tiene_dias:
        raise BadRequestException("Las materias primas perecederas requieren 'dias_vida_util'")

    internal = MateriaPrimaUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
        updated_by=UUID(str(current_user["id"])),
    )
    updated = update_materia_prima(db, materia_prima_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar la materia prima")

    logger.info(
        "Materia prima actualizada | id={id} | por={admin}",
        id=str(materia_prima_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /materias-primas/{id} ── soft delete ──────────────────────────────

@router.delete(
    "/{materia_prima_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar materia prima (soft delete)",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def delete_materia_prima(
    request: Request,
    materia_prima_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    mp = get_materia_prima(db, materia_prima_id)
    if not mp:
        raise NotFoundException("Materia prima no encontrada")
    verify_empresa_access(current_user, UUID(str(mp["empresa_id"])))

    soft_delete_materia_prima(db, materia_prima_id, UUID(str(current_user["id"])))

    logger.warning(
        "Materia prima desactivada [soft] | id={id} | nombre={nombre} | por={admin}",
        id=str(materia_prima_id),
        nombre=mp.get("nombre"),
        admin=current_user.get("email"),
    )
    return {"message": f"Materia prima '{mp['nombre']}' desactivada correctamente"}


# ─── DELETE /materias-primas/{id}/hard ────────────────────────────────────────

@router.delete(
    "/{materia_prima_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar materia prima permanentemente",
    description="**Solo super_admin.** Fallará si tiene recetas o lotes asociados.",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_materia_prima_endpoint(
    request: Request,
    materia_prima_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    mp = get_materia_prima(db, materia_prima_id)
    if not mp:
        raise NotFoundException("Materia prima no encontrada")

    hard_delete_materia_prima(db, materia_prima_id)

    logger.warning(
        "Materia prima ELIMINADA [hard] | id={id} | nombre={nombre} | por={admin}",
        id=str(materia_prima_id),
        nombre=mp.get("nombre"),
        admin=current_user.get("email"),
    )
    return {"message": f"Materia prima '{mp['nombre']}' eliminada permanentemente"}


# ─── GET /materias-primas/{id}/sucursales/{suc_id} ────────────────────────────

@router.get(
    "/{materia_prima_id}/sucursales/{sucursal_id}",
    response_model=MateriaPrimaSucursalRead,
    summary="Obtener stock de una materia prima en una sucursal",
)
def read_materia_prima_sucursal(
    materia_prima_id: UUID,
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    mp = get_materia_prima(db, materia_prima_id)
    if not mp:
        raise NotFoundException("Materia prima no encontrada")
    verify_empresa_access(current_user, UUID(str(mp["empresa_id"])))

    mps = get_materia_prima_sucursal(db, materia_prima_id, sucursal_id)
    if not mps:
        raise NotFoundException("La materia prima no está configurada en esa sucursal")
    return mps


# ─── POST /materias-primas/{id}/sucursales ────────────────────────────────────

@router.post(
    "/{materia_prima_id}/sucursales",
    response_model=MateriaPrimaSucursalRead,
    status_code=status.HTTP_201_CREATED,
    summary="Configurar materia prima en una sucursal",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def write_materia_prima_sucursal(
    request: Request,
    materia_prima_id: UUID,
    data: MateriaPrimaSucursalCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    mp = get_materia_prima(db, materia_prima_id)
    if not mp:
        raise NotFoundException("Materia prima no encontrada")
    verify_empresa_access(current_user, UUID(str(mp["empresa_id"])))

    sucursal = get_sucursal(db, data.sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")
    if str(sucursal["empresa_id"]) != str(mp["empresa_id"]):
        raise BadRequestException("La sucursal no pertenece a la misma empresa")

    if materia_prima_sucursal_exists(db, materia_prima_id, data.sucursal_id):
        raise DuplicateValueException("La materia prima ya está configurada en esa sucursal")

    data_dict = data.model_dump()
    data_dict["materia_prima_id"] = materia_prima_id
    nueva = create_materia_prima_sucursal(db, MateriaPrimaSucursalCreate(**data_dict))

    logger.info(
        "Materia prima en sucursal creada | mp={mp} | sucursal={suc} | por={admin}",
        mp=str(materia_prima_id),
        suc=str(data.sucursal_id),
        admin=current_user.get("email"),
    )
    return nueva


# ─── PATCH /materias-primas/sucursales/{mps_id} ───────────────────────────────

@router.patch(
    "/sucursales/{mps_id}",
    response_model=MateriaPrimaSucursalRead,
    summary="Actualizar stock o costos de materia prima en sucursal",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def patch_materia_prima_sucursal(
    request: Request,
    mps_id: UUID,
    values: MateriaPrimaSucursalUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    mps = get_materia_prima_sucursal_by_id(db, mps_id)
    if not mps:
        raise NotFoundException("Configuración no encontrada")

    mp = get_materia_prima(db, UUID(str(mps["materia_prima_id"])))
    if mp:
        verify_empresa_access(current_user, UUID(str(mp["empresa_id"])))

    internal = MateriaPrimaSucursalUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
    )
    updated = update_materia_prima_sucursal(db, mps_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar")

    logger.info(
        "Materia prima-sucursal actualizada | id={id} | por={admin}",
        id=str(mps_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /materias-primas/sucursales/{mps_id} ──────────────────────────────

@router.delete(
    "/sucursales/{mps_id}",
    status_code=status.HTTP_200_OK,
    summary="Eliminar configuración de materia prima en sucursal",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def delete_materia_prima_sucursal_endpoint(
    request: Request,
    mps_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    mps = get_materia_prima_sucursal_by_id(db, mps_id)
    if not mps:
        raise NotFoundException("Configuración no encontrada")

    mp = get_materia_prima(db, UUID(str(mps["materia_prima_id"])))
    if mp:
        verify_empresa_access(current_user, UUID(str(mp["empresa_id"])))

    delete_materia_prima_sucursal(db, mps_id)

    logger.warning(
        "Materia prima-sucursal eliminada | id={id} | por={admin}",
        id=str(mps_id),
        admin=current_user.get("email"),
    )
    return {"message": "Configuración de materia prima en sucursal eliminada"}