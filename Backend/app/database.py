from supabase import create_client, Client
from app.config import settings

_client: Client | None = None
_admin_client: Client | None = None


def get_supabase() -> Client:
    """Cliente normal — usa la anon o service_role key para queries de datos."""
    global _client
    if _client is None:
        _client = create_client(settings.supabase_url, settings.supabase_key)
    return _client


def get_supabase_admin() -> Client:
    """
    Cliente admin — SIEMPRE usa service_role key.
    Necesario para auth.admin.create_user, delete_user, etc.
    """
    global _admin_client
    if _admin_client is None:
        from supabase.lib.client_options import ClientOptions
        _admin_client = create_client(
            settings.supabase_url,
            settings.supabase_service_key,  # ← service_role obligatorio
        )
    return _admin_client