"""
Configuración central de logging con loguru.

Salida: JSON estructurado → /logs/app.json  (consumido por Promtail → Loki → Grafana)
        Consola colorizada → stdout           (solo para desarrollo local)

Formato JSON de cada línea:
    {
        "ts":     "2026-05-30T14:23:01.123Z",   ← timestamp ISO 8601 UTC
        "level":  "INFO",
        "logger": "app.api.v1.pedidos",
        "func":   "write_pedido",
        "line":   205,
        "msg":    "Pedido creado | id=abc | tipo=mesa | total=25.00"
        "exception": "..."                       ← solo si hay excepción
        // + cualquier campo añadido con logger.bind(key=val)
    }

Uso en cualquier archivo:
    from loguru import logger
    logger.info("Empresa creada | id={empresa_id}", empresa_id=empresa_id)
    logger.warning("Acceso no autorizado | email={email}", email=email)
    logger.error("Fallo Supabase | error={error}", error=str(e))

    # Con contexto estructurado (queda en el JSON como campo extra):
    logger.bind(empresa_id=str(empresa_id), usuario=email).info("Pedido creado")

Niveles disponibles (de menor a mayor severidad):
    TRACE | DEBUG | INFO | SUCCESS | WARNING | ERROR | CRITICAL
"""

import json
import sys
import traceback
from pathlib import Path

from loguru import logger

# ─── Directorio de logs ───────────────────────────────────────────────────────
LOGS_DIR = Path("logs")
LOGS_DIR.mkdir(exist_ok=True)


# ─── Serializador JSON ────────────────────────────────────────────────────────

def _json_format(record: dict) -> str:
    """
    Formateador de loguru que produce una línea JSON por registro.

    Asigna el JSON serializado en extra["__json"] para que el string
    de formato "{extra[__json]}\\n" lo expanda sin procesar caracteres
    especiales del mensaje original.
    """
    data: dict = {
        "ts":     record["time"].strftime("%Y-%m-%dT%H:%M:%S.") +
                  f"{record['time'].microsecond // 1000:03d}Z",
        "level":  record["level"].name,
        "logger": record["name"],
        "func":   record["function"],
        "line":   record["line"],
        "msg":    record["message"],
    }

    # Contexto extra añadido con logger.bind(key=val) o contextualize()
    for key, val in record["extra"].items():
        if key != "__json":
            data[key] = val

    # Información de excepción cuando existe
    if record["exception"] is not None:
        exc_type, exc_val, exc_tb = record["exception"]
        data["exception"] = "".join(
            traceback.format_exception(exc_type, exc_val, exc_tb)
        ).strip()

    record["extra"]["__json"] = json.dumps(data, ensure_ascii=False, default=str)
    return "{extra[__json]}\n"


# ─── Configuración principal ──────────────────────────────────────────────────

def setup_logger(debug: bool = False) -> None:
    """
    Configura loguru. Llamar UNA vez al arrancar la app en main.py.

    Sinks configurados:
      · stdout     — consola colorizada (nivel DEBUG en dev, INFO en prod)
      · app.json   — JSON estructurado para Loki (INFO+, rotación 10 MB, 30 días)
    """
    logger.remove()

    # ── Consola ───────────────────────────────────────────────────────────────
    console_level = "DEBUG" if debug else "INFO"
    logger.add(
        sys.stdout,
        level=console_level,
        colorize=True,
        format=(
            "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
            "<level>{level: <8}</level> | "
            "<cyan>{name}</cyan>:<cyan>{line}</cyan> | "
            "<level>{message}</level>"
        ),
        backtrace=debug,
        diagnose=debug,
    )

    # ── JSON para Loki (reemplaza los archivos de texto anteriores) ───────────
    logger.add(
        LOGS_DIR / "app.json",
        level="INFO",
        format=_json_format,
        rotation="10 MB",
        retention="30 days",
        compression="zip",
        encoding="utf-8",
        enqueue=True,        # escritura asíncrona — no bloquea los requests
        backtrace=True,      # stacktrace completo en excepciones
        diagnose=False,      # no exponer variables locales en producción
    )

    logger.info(
        "Logger configurado | nivel_consola={level} | sink=app.json | debug={debug}",
        level=console_level,
        debug=debug,
    )
