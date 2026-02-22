from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client

from app.database import get_supabase
from app.schemas.item import ItemCreate, ItemResponse, ItemUpdate

router = APIRouter(prefix="/items", tags=["Items"])


@router.get("/", response_model=list[ItemResponse], summary="Listar todos los items")
def list_items(db: Client = Depends(get_supabase)):
    """Retorna todos los registros de la tabla **items** en Supabase."""
    result = db.table("items").select("*").execute()
    return result.data


@router.get("/{item_id}", response_model=ItemResponse, summary="Obtener un item")
def get_item(item_id: int, db: Client = Depends(get_supabase)):
    result = db.table("items").select("*").eq("id", item_id).single().execute()
    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item no encontrado")
    return result.data


@router.post("/", response_model=ItemResponse, status_code=status.HTTP_201_CREATED, summary="Crear un item")
def create_item(item: ItemCreate, db: Client = Depends(get_supabase)):
    result = db.table("items").insert(item.model_dump()).execute()
    return result.data[0]


@router.patch("/{item_id}", response_model=ItemResponse, summary="Actualizar un item")
def update_item(item_id: int, item: ItemUpdate, db: Client = Depends(get_supabase)):
    data = item.model_dump(exclude_unset=True)
    result = db.table("items").update(data).eq("id", item_id).execute()
    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item no encontrado")
    return result.data[0]


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Eliminar un item")
def delete_item(item_id: int, db: Client = Depends(get_supabase)):
    db.table("items").delete().eq("id", item_id).execute()