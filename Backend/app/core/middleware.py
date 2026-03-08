"""
Middleware de logging por request.

Intercepta CADA request antes y después de que llegue al router.
No hay que agregar logs en cada endpoint — este middleware lo hace automáticamente.

Qué loguea:
  → Request entrante:  método, path, IP, user-agent
  ← Response saliente: status code, latencia en ms, usuario autenticado si hay token
  ✗ Excepciones:       stacktrace completo en errors.log
"""

import time
from uuid import uuid4

from fastapi import Request, Response
from loguru import logger
from starlette.middleware.base import BaseHTTPMiddleware


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    Loguea cada request con:
    - request_id único (para correlacionar logs de un mismo request)
    - método HTTP + path + query string
    - IP del cliente (respeta X-Forwarded-For para proxies)
    - status code
    - latencia en ms
    - email del usuario si el token JWT está presente
    """

    # Paths que no vale la pena loguear (ruido)
    SKIP_PATHS = {"/docs", "/redoc", "/openapi.json", "/favicon.ico"}

    async def dispatch(self, request: Request, call_next) -> Response:
        # Silenciar paths de documentación
        if request.url.path in self.SKIP_PATHS:
            return await call_next(request)

        # ── ID único por request ──────────────────────────────────────────────
        request_id = str(uuid4())[:8]  # 8 chars son suficientes para correlacionar

        # ── Datos del request ─────────────────────────────────────────────────
        method = request.method
        path = request.url.path
        query = f"?{request.url.query}" if request.url.query else ""
        client_ip = _get_client_ip(request)
        user_agent = request.headers.get("user-agent", "-")[:80]  # truncar UAs largos

        # ── Intentar extraer el usuario del token (sin validarlo aquí) ────────
        user_hint = _extract_user_hint(request)

        start = time.perf_counter()

        logger.info(
            "→ [{request_id}] {method} {path}{query} | ip={ip} | user={user}",
            request_id=request_id,
            method=method,
            path=path,
            query=query,
            ip=client_ip,
            user=user_hint,
        )

        # ── Ejecutar el request ───────────────────────────────────────────────
        try:
            response: Response = await call_next(request)
        except Exception as exc:
            latency_ms = round((time.perf_counter() - start) * 1000, 2)
            logger.exception(
                "✗ [{request_id}] {method} {path} | 500 | {latency}ms | EXCEPCIÓN NO MANEJADA",
                request_id=request_id,
                method=method,
                path=path,
                latency=latency_ms,
            )
            raise  # re-lanzar para que FastAPI devuelva el 500

        latency_ms = round((time.perf_counter() - start) * 1000, 2)
        status = response.status_code

        # ── Elegir nivel de log según el status code ──────────────────────────
        if status < 400:
            log_fn = logger.info
            arrow = "←"
        elif status == 401:
            log_fn = logger.warning
            arrow = "⚠"
        elif status == 403:
            log_fn = logger.warning
            arrow = "⛔"
        elif status == 429:
            log_fn = logger.warning
            arrow = "🚫"
        elif status < 500:
            log_fn = logger.warning
            arrow = "⚠"
        else:
            log_fn = logger.error
            arrow = "✗"

        log_fn(
            "{arrow} [{request_id}] {method} {path} | {status} | {latency}ms | user={user}",
            arrow=arrow,
            request_id=request_id,
            method=method,
            path=path,
            status=status,
            latency=latency_ms,
            user=user_hint,
        )

        # Agregar el request_id al response header (útil para debugging desde el cliente)
        response.headers["X-Request-ID"] = request_id
        return response


def _get_client_ip(request: Request) -> str:
    """Respeta X-Forwarded-For cuando hay un proxy/load balancer delante."""
    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    if request.client:
        return request.client.host
    return "unknown"


def _extract_user_hint(request: Request) -> str:
    """
    Extrae una pista del usuario desde el JWT sin validarlo.
    Solo para logging — la validación real ocurre en get_current_user().
    Retorna el sub (UUID) del token o 'anonymous'.
    """
    auth_header = request.headers.get("authorization", "")
    if not auth_header.startswith("Bearer "):
        return "anonymous"

    try:
        token = auth_header.split(" ")[1]
        # Decodificar el payload del JWT sin verificar la firma (solo para logging)
        import base64
        import json
        payload_b64 = token.split(".")[1]
        # Padding
        payload_b64 += "=" * (4 - len(payload_b64) % 4)
        payload = json.loads(base64.urlsafe_b64decode(payload_b64))
        # Retornar email si existe, si no el sub (UUID)
        return payload.get("email") or payload.get("sub", "unknown")[:8]
    except Exception:
        return "invalid-token"