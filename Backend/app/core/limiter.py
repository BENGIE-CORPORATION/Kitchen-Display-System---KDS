"""
Configuración central del rate limiter con slowapi.

Límites definidos:
  Auth endpoints (por IP — no requieren token):
    POST /auth/login       → 5  requests / minuto   (previene brute force)
    POST /auth/register    → 3  requests / hora     (previene spam de cuentas)
    POST /auth/refresh     → 20 requests / minuto   (refresh legítimo es frecuente)

  Auth endpoints (por usuario autenticado):
    POST /auth/invite      → 20 requests / hora     (admin creando empleados)
    POST /auth/logout      → 10 requests / minuto

  API general (por IP):
    Todos los demás        → 120 requests / minuto  (uso normal de la API)

Uso en un endpoint:
    from app.core.limiter import limiter

    @router.post("/login")
    @limiter.limit("5/minute")           # por IP (default)
    def login(request: Request, ...):    # Request debe ser el primer parámetro

    @router.post("/invite")
    @limiter.limit("20/hour", key_func=get_user_id_from_token)  # por usuario
    def invite(request: Request, ...):
"""

from slowapi import Limiter
from slowapi.util import get_remote_address


def _get_client_ip(request) -> str:
    """
    Key function para slowapi.
    Respeta X-Forwarded-For cuando hay proxy delante.
    """
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return get_remote_address(request)


def get_user_id_from_token(request) -> str:
    """
    Key function para limitar por usuario autenticado (no por IP).
    Extrae el sub (UUID) del JWT sin validarlo — solo para identificar al usuario.
    Si no hay token válido, cae de vuelta a la IP.
    """
    auth_header = request.headers.get("authorization", "")
    if not auth_header.startswith("Bearer "):
        return _get_client_ip(request)

    try:
        import base64
        import json
        token = auth_header.split(" ")[1]
        payload_b64 = token.split(".")[1]
        payload_b64 += "=" * (4 - len(payload_b64) % 4)
        payload = json.loads(base64.urlsafe_b64decode(payload_b64))
        user_id = payload.get("sub")
        return user_id if user_id else _get_client_ip(request)
    except Exception:
        return _get_client_ip(request)


# Instancia global — se importa en main.py y en los routers que necesiten límites
limiter = Limiter(
    key_func=_get_client_ip,   # comportamiento por defecto: limitar por IP
    default_limits=["120/minute"],  # límite global para todo lo que no tenga decorador
)