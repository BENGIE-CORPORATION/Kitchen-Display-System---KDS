from supabase import create_client, Client
from app.config import settings

_supabase_client: Client | None = None


def get_supabase() -> Client:
    """
    Devuelve una instancia singleton del cliente Supabase.
    Úsala como dependencia en tus rutas:

        from app.database import get_supabase

        @router.get("/items")
        def list_items(db: Client = Depends(get_supabase)):
            return db.table("items").select("*").execute()
    """
    global _supabase_client
    if _supabase_client is None:
        _supabase_client = create_client(
            settings.supabase_url,
            settings.supabase_key,
        )
    return _supabase_client