"""
Router de Empresas — solo lógica HTTP.
Toda la lógica de base de datos vive en app/crud/crud_empresa.py
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from supabase import Client

from ...core.exceptions.http_exceptions import (
    DuplicateValueException,
    NotFoundException,
)
from ...core.pagination import PaginatedResponse
from ...crud.crud_empresa import (
    create_empresa,
    empresa_exists,
    get_empresa,
    get_empresa_by_identificacion,
    get_empresas,
    hard_delete_empresa,
    soft_delete_empresa,
    update_empresa,
)
from ...database import get_supabase
from ...schemas.empresa import (
    EmpresaCreate,
    EmpresaCreateInternal,
    EmpresaRead,
    EmpresaUpdate,
    EmpresaUpdateInternal,
)
from datetime import UTC, datetime

router = APIRouter(prefix="/empresas", tags=["Empresas"])


# ─── POST /empresas ───────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=EmpresaRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear empresa",
    description="Registra una nueva empresa. El campo `identificacion` debe ser único (RUC/Tax ID).",
)
def write_empresa(
    empresa: EmpresaCreate,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    # Verificar duplicado de identificacion
    if empresa_exists(db, identificacion=empresa.identificacion):
        raise DuplicateValueException("La identificación fiscal ya está registrada")

    # Verificar duplicado de email
    if empresa_exists(db, email=empresa.email):
        raise DuplicateValueException("El email ya está registrado")

    internal = EmpresaCreateInternal(**empresa.model_dump())
    return create_empresa(db, internal)


# ─── GET /empresas ────────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[EmpresaRead],
    summary="Listar empresas",
    description="Lista paginada de empresas activas con filtros opcionales.",
)
def read_empresas(
    db: Annotated[Client, Depends(get_supabase)],
    page: Annotated[int, Query(ge=1, description="Número de página")] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100, description="Items por página")] = 10,
    order_by: Annotated[str, Query(description="Columna para ordenar")] = "created_at",
    order_desc: Annotated[bool, Query(description="Orden descendente")] = True,
    estado: Annotated[str | None, Query(description="Filtrar por estado: activo/suspendido")] = None,
    tipo_negocio: Annotated[str | None, Query(description="Filtrar por tipo: restaurante/supermercado/retail/mixto")] = None,
    pais: Annotated[str | None, Query(description="Filtrar por país (ISO 3166-1 alpha-2)")] = None,
) -> dict:
    return get_empresas(
        db=db,
        page=page,
        items_per_page=items_per_page,
        order_by=order_by,
        order_desc=order_desc,
        estado=estado,
        tipo_negocio=tipo_negocio,
        pais=pais,
    )


# ─── GET /empresas/{id} ───────────────────────────────────────────────────────

@router.get(
    "/{empresa_id}",
    response_model=EmpresaRead,
    summary="Obtener empresa",
    description="Retorna el detalle de una empresa por su UUID.",
)
def read_empresa(
    empresa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    empresa = get_empresa(db, empresa_id)
    if not empresa:
        raise NotFoundException("Empresa no encontrada")
    return empresa


# ─── PATCH /empresas/{id} ─────────────────────────────────────────────────────

@router.patch(
    "/{empresa_id}",
    response_model=EmpresaRead,
    summary="Actualizar empresa",
    description="Actualiza parcialmente una empresa. Solo se modifican los campos enviados.",
)
def patch_empresa(
    empresa_id: UUID,
    values: EmpresaUpdate,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    # Verificar que existe
    empresa = get_empresa(db, empresa_id)
    if not empresa:
        raise NotFoundException("Empresa no encontrada")

    # Verificar email duplicado si se está cambiando
    if values.email and values.email != empresa.get("email"):
        if empresa_exists(db, email=str(values.email)):
            raise DuplicateValueException("El email ya está registrado en otra empresa")

    internal = EmpresaUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
    )
    updated = update_empresa(db, empresa_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar la empresa")
    return updated


# ─── DELETE /empresas/{id} (soft) ────────────────────────────────────────────

@router.delete(
    "/{empresa_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar empresa (soft delete)",
    description="Marca la empresa como inactiva. No borra el registro físicamente.",
)
def delete_empresa(
    empresa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    empresa = get_empresa(db, empresa_id)
    if not empresa:
        raise NotFoundException("Empresa no encontrada")

    soft_delete_empresa(db, empresa_id)
    return {"message": f"Empresa '{empresa['nombre_comercial']}' desactivada correctamente"}


# ─── DELETE /empresas/{id}/hard (hard delete — solo superadmin) ───────────────

@router.delete(
    "/{empresa_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar empresa permanentemente",
    description="Borra físicamente el registro. Operación irreversible — solo superadmin.",
    # dependencies=[Depends(get_current_superuser)],  # descomentar cuando tengas auth
)
def hard_delete_empresa_endpoint(
    empresa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
) -> dict:
    if not empresa_exists(db, id=str(empresa_id)):
        raise NotFoundException("Empresa no encontrada")

    hard_delete_empresa(db, empresa_id)
    return {"message": "Empresa eliminada permanentemente"}