"""
Configuración central de logging con loguru.

Uso en cualquier archivo:
    from app.core.logger import logger
    logger.info("Empresa creada: {empresa_id}", empresa_id=empresa_id)
    logger.warning("Intento de acceso no autorizado: {email}", email=email)
    logger.error("Fallo al conectar con Supabase: {error}", error=str(e))

Niveles disponibles (de menor a mayor severidad):
    TRACE | DEBUG | INFO | SUCCESS | WARNING | ERROR | CRITICAL
"""

import sys
from pathlib import Path

from loguru import logger

# ─── Directorio de logs ───────────────────────────────────────────────────────
LOGS_DIR = Path("logs")
LOGS_DIR.mkdir(exist_ok=True)


def setup_logger(debug: bool = False) -> None:
    """
    Configura loguru. Llamar UNA vez al arrancar la app en main.py.

    En desarrollo: logs en consola con colores, nivel DEBUG.
    En producción: consola INFO + archivo rotativo JSON.
    """
    logger.remove()  # quitar el handler por defecto

    # ── Consola ───────────────────────────────────────────────────────────────
    log_level = "DEBUG" if debug else "INFO"
    logger.add(
        sys.stdout,
        level=log_level,
        colorize=True,
        format=(
            "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
            "<level>{level: <8}</level> | "
            "<cyan>{name}</cyan>:<cyan>{line}</cyan> | "
            "<level>{message}</level>"
        ),
        backtrace=debug,   # stacktrace completo solo en debug
        diagnose=debug,    # variables locales en el stacktrace solo en debug
    )

    # ── Archivo — todos los logs INFO+ ────────────────────────────────────────
    logger.add(
        LOGS_DIR / "app.log",
        level="INFO",
        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name}:{line} | {message}",
        rotation="10 MB",        # nuevo archivo cada 10MB
        retention="30 days",     # borrar archivos de más de 30 días
        compression="zip",       # comprimir los archivos viejos
        encoding="utf-8",
        enqueue=True,            # escritura asíncrona — no bloquea los requests
    )

    # ── Archivo — solo errores (crítico para producción) ──────────────────────
    logger.add(
        LOGS_DIR / "errors.log",
        level="ERROR",
        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name}:{line} | {message}",
        rotation="5 MB",
        retention="90 days",     # errores se guardan más tiempo
        compression="zip",
        encoding="utf-8",
        enqueue=True,
        backtrace=True,          # stacktrace completo siempre en errors.log
        diagnose=False,          # no en producción (puede loguear datos sensibles)
    )

    logger.info("Logger configurado | nivel={level} | debug={debug}", level=log_level, debug=debug)