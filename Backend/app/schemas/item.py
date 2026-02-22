from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    is_active: bool = True


class ItemCreate(ItemBase):
    pass


class ItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    is_active: Optional[bool] = None


class ItemResponse(ItemBase):
    id: int
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}