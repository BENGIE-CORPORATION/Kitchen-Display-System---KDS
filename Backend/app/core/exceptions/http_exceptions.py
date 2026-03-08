"""
Excepciones HTTP centralizadas.

Todas retornan un body estructurado:
{
    "error": "NOT_FOUND",           ← código de máquina (para el frontend)
    "detail": "Empresa no encontrada"  ← mensaje humano
}

Esto permite al frontend manejar errores por código sin parsear strings.
"""

from fastapi import HTTPException, status


class AppException(HTTPException):
    """Base para todas las excepciones de la app."""
    error_code: str = "INTERNAL_ERROR"

    def __init__(self, detail: str, status_code: int):
        super().__init__(
            status_code=status_code,
            detail={"error": self.error_code, "detail": detail},
        )


class NotFoundException(AppException):
    error_code = "NOT_FOUND"

    def __init__(self, detail: str = "Recurso no encontrado"):
        super().__init__(detail=detail, status_code=status.HTTP_404_NOT_FOUND)


class DuplicateValueException(AppException):
    error_code = "DUPLICATE_VALUE"

    def __init__(self, detail: str = "El valor ya existe"):
        super().__init__(detail=detail, status_code=status.HTTP_409_CONFLICT)


class ForbiddenException(AppException):
    error_code = "FORBIDDEN"

    def __init__(self, detail: str = "No tienes permiso para realizar esta acción"):
        super().__init__(detail=detail, status_code=status.HTTP_403_FORBIDDEN)


class UnauthorizedException(AppException):
    error_code = "UNAUTHORIZED"

    def __init__(self, detail: str = "No autenticado"):
        super().__init__(detail=detail, status_code=status.HTTP_401_UNAUTHORIZED)


class BadRequestException(AppException):
    error_code = "BAD_REQUEST"

    def __init__(self, detail: str = "Solicitud inválida"):
        super().__init__(detail=detail, status_code=status.HTTP_400_BAD_REQUEST)


class RateLimitException(AppException):
    error_code = "RATE_LIMIT_EXCEEDED"

    def __init__(self, detail: str = "Demasiadas solicitudes. Intenta más tarde."):
        super().__init__(detail=detail, status_code=status.HTTP_429_TOO_MANY_REQUESTS)


class ServiceUnavailableException(AppException):
    error_code = "SERVICE_UNAVAILABLE"

    def __init__(self, detail: str = "Servicio no disponible temporalmente"):
        super().__init__(detail=detail, status_code=status.HTTP_503_SERVICE_UNAVAILABLE)