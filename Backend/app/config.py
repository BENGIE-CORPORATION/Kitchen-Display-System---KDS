from pathlib import Path
from importlib.metadata import version, PackageNotFoundError

import tomllib  # stdlib desde Python 3.11
from pydantic_settings import BaseSettings, SettingsConfigDict


# ─── Leer pyproject.toml como fuente de verdad ───────────────
def _read_pyproject() -> dict:
    pyproject_path = Path(__file__).resolve().parent.parent / "pyproject.toml"
    if pyproject_path.exists():
        with open(pyproject_path, "rb") as f:
            return tomllib.load(f)
    return {}


def _get_version() -> str:
    """
    1. Intenta leer la versión del paquete instalado (pip install -e .)
    2. Si no está instalado, la lee directamente del pyproject.toml
    3. Fallback a '0.0.0'
    """
    try:
        return version("mi-backend-fastapi")
    except PackageNotFoundError:
        data = _read_pyproject()
        return data.get("project", {}).get("version", "0.0.0")


def _get_project_name() -> str:
    data = _read_pyproject()
    return data.get("project", {}).get("description", "Mi Backend FastAPI")


# ─── Settings ────────────────────────────────────────────────
class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # Leídos automáticamente desde pyproject.toml — no los definas en .env
    app_name: str = _get_project_name()
    app_version: str = _get_version()
    debug: bool = False
    secret_key: str = "cambia-esto"

    # Supabase
    supabase_url: str
    supabase_key: str


settings = Settings()