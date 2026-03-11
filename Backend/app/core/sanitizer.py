"""
Sanitización de inputs de texto.

Pydantic valida tipos y formatos pero no limpia el contenido.
Este módulo elimina caracteres peligrosos de campos de texto libre
antes de que lleguen a la base de datos.

Uso en schemas:
    from app.core.sanitizer import sanitize_text, sanitize_strict

    class EmpresaCreate(BaseModel):
        nombre_legal: str
        descripcion: str | None = None

        @field_validator("nombre_legal")
        @classmethod
        def clean_nombre(cls, v: str) -> str:
            return sanitize_strict(v)   # sin HTML ni caracteres especiales

        @field_validator("descripcion")
        @classmethod
        def clean_descripcion(cls, v: str | None) -> str | None:
            return sanitize_text(v) if v else None   # permite más caracteres
"""

import re
import unicodedata


def sanitize_text(value: str) -> str:
    """
    Limpieza básica para texto libre (descripciones, notas, direcciones).
    - Elimina tags HTML completos
    - Elimina caracteres de control (null bytes, etc.)
    - Normaliza espacios múltiples
    - Strip de espacios al inicio/fin
    Permite: letras, números, puntuación normal, acentos, ñ
    """
    if not value:
        return value

    # Eliminar tags HTML: <script>...</script>, <b>, etc.
    value = re.sub(r"<[^>]+>", "", value)

    # Eliminar caracteres de control (excepto newline y tab que son legítimos)
    value = "".join(
        ch for ch in value
        if unicodedata.category(ch) != "Cc" or ch in ("\n", "\t")
    )

    # Normalizar espacios múltiples en una sola línea
    value = re.sub(r"[ \t]+", " ", value)

    # Normalizar saltos de línea múltiples (máx 2 consecutivos)
    value = re.sub(r"\n{3,}", "\n\n", value)

    return value.strip()


def sanitize_strict(value: str) -> str:
    """
    Limpieza estricta para campos de nombre, código, identificación.
    - Todo lo de sanitize_text
    - Elimina saltos de línea (un nombre no debe tener enters)
    - Elimina caracteres no imprimibles
    Permite: letras (con acentos), números, espacios, guiones, puntos, comas
    """
    if not value:
        return value

    value = sanitize_text(value)

    # Eliminar saltos de línea — no tienen sentido en un nombre
    value = value.replace("\n", " ").replace("\t", " ")

    # Eliminar caracteres que no sean alfanuméricos, espacios o puntuación básica
    # Permite: letras unicode (incluye ñ, acentos), números, espacios, - . , ( ) / & @
    value = re.sub(r"[^\w\s\-.,()\/&@ñÑáéíóúÁÉÍÓÚüÜ]", "", value, flags=re.UNICODE)

    # Normalizar espacios resultantes
    value = re.sub(r"\s+", " ", value)

    return value.strip()


def sanitize_email(value: str) -> str:
    """
    Normaliza emails: lowercase y strip.
    Pydantic EmailStr ya valida el formato — esto solo normaliza.
    """
    return value.strip().lower() if value else value


def sanitize_url(value: str | None) -> str | None:
    """
    Limpieza básica de URLs. Solo strip — la validación la hace el pattern de Pydantic.
    """
    return value.strip() if value else value