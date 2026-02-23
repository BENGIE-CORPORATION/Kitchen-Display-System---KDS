from typing import Generic, TypeVar
from pydantic import BaseModel

T = TypeVar("T")


class PaginatedResponse(BaseModel, Generic[T]):
    data: list[T]
    total: int
    page: int
    items_per_page: int
    total_pages: int


def paginated_response(data: list, total: int, page: int, items_per_page: int) -> dict:
    return {
        "data": data,
        "total": total,
        "page": page,
        "items_per_page": items_per_page,
        "total_pages": -(-total // items_per_page),  # ceil division
    }


def compute_offset(page: int, items_per_page: int) -> int:
    return (page - 1) * items_per_page