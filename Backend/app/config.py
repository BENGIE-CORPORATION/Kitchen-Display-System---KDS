"""
Configuración de la aplicación.

Variables de entorno por ambiente:
  Desarrollo:  APP_ENV=development  (default)
  Producción:  APP_ENV=production

El archivo .env se carga según APP_ENV:
  development → .env.development (con fallback a .env)
  production  → .env.production  (con fallback a .env)

Variables requeridas (deben estar en el .env correspondiente):
  SUPABASE_URL, SUPABASE_KEY, SUPABASE_SERVICE_KEY, SUPABASE_JWT_SECRET,
  SECRET_KEY, CORS_ORIGINS
"""

import os
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path

import tomllib
from pydantic_settings import BaseSettings, SettingsConfigDict


def _read_pyproject() -> dict:
    pyproject_path = Path(__file__).resolve().parent.parent / "pyproject.toml"
    if pyproject_path.exists():
        with open(pyproject_path, "rb") as f:
            return tomllib.load(f)
    return {}


def _get_version() -> str:
    try:
        return version("mi-backend-fastapi")
    except PackageNotFoundError:
        data = _read_pyproject()
        return data.get("project", {}).get("version", "0.0.0")


def _get_project_name() -> str:
    data = _read_pyproject()
    return data.get("project", {}).get("description", "KDS Backend")


def _resolve_env_file() -> list[str]:
    """
    Determina qué archivo .env cargar según APP_ENV.
    Siempre carga .env como base — el archivo específico lo sobreescribe.
    """
    env = os.getenv("APP_ENV", "development").lower()
    specific = f".env.{env}"
    # Pydantic-settings carga en orden — el último sobreescribe al anterior
    # Si .env.production no existe, solo usa .env
    files = [".env"]
    if Path(specific).exists():
        files.append(specific)
    return files


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=_resolve_env_file(),
        env_file_encoding="utf-8",
        extra="ignore",  # ignorar variables no declaradas — evita el error de extra inputs
    )

    # ── App ───────────────────────────────────────────────────────────────────
    app_name: str = _get_project_name()
    app_version: str = _get_version()
    app_env: str = "development"
    debug: bool = False
    secret_key: str = "cambia-esto"

    # ── CORS ──────────────────────────────────────────────────────────────────
    # En desarrollo:  CORS_ORIGINS=http://localhost:3000,http://localhost:8000
    # En producción:  CORS_ORIGINS=https://tudominio.com
    # Acepta lista separada por comas — pydantic-settings lo lee como str puro.
    cors_origins: str = "http://localhost:3000,http://localhost:8000"

    @property
    def cors_origins_list(self) -> list[str]:
        """Parsea cors_origins (separado por comas) a lista de strings."""
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    # ── Supabase ──────────────────────────────────────────────────────────────
    supabase_url: str
    supabase_key: str
    supabase_service_key: str = ""   # requerido para auth.admin.* — vacío falla gracefully
    supabase_jwt_secret: str = ""    # requerido para validar JWT

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def is_development(self) -> bool:
        return self.app_env == "development"

    def validate_production_settings(self) -> list[str]:
        """
        Valida que las variables críticas estén bien configuradas en producción.
        Retorna lista de errores — vacía si todo está OK.
        Llamar al arrancar en main.py si is_production.
        """
        errors = []
        if self.secret_key == "cambia-esto":
            errors.append("SECRET_KEY usa el valor por defecto — genera uno con: python -c \"import secrets; print(secrets.token_hex(32))\"")
        if not self.supabase_service_key:
            errors.append("SUPABASE_SERVICE_KEY no definida — /auth/invite y operaciones admin no funcionarán")
        if not self.supabase_jwt_secret:
            errors.append("SUPABASE_JWT_SECRET no definida — autenticación no funcionará")
        if self.debug:
            errors.append("DEBUG=True en producción — desactívalo")
        origins = self.cors_origins_list
        if not origins or "*" in origins:
            errors.append("CORS_ORIGINS no configurado — define los dominios permitidos (ej: https://tudominio.com)")
        elif any("localhost" in o for o in origins):
            errors.append("CORS_ORIGINS contiene 'localhost' — reemplaza con tu dominio real en producción")
        return errors


settings = Settings()