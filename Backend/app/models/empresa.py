"""
Modelo que representa la tabla `empresas` en Supabase.

SQL para crear la tabla:
─────────────────────────────────────────────
CREATE TABLE empresas (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre_legal    VARCHAR(255) NOT NULL,
  nombre_comercial VARCHAR(255) NOT NULL,
  identificacion  VARCHAR(100) NOT NULL UNIQUE,
  tipo_negocio    VARCHAR(30)  NOT NULL,
  email           VARCHAR(255) NOT NULL,
  telefono        VARCHAR(50),
  direccion_fiscal TEXT,
  pais            VARCHAR(2)   NOT NULL,
  moneda          VARCHAR(3)   NOT NULL DEFAULT 'USD',
  logo_url        TEXT,
  timezone        VARCHAR(50)  DEFAULT 'UTC',
  configuracion   JSONB,
  estado          VARCHAR(20)  NOT NULL DEFAULT 'activo',
  fecha_registro  TIMESTAMPTZ  DEFAULT now(),
  created_at      TIMESTAMPTZ  DEFAULT now(),
  updated_at      TIMESTAMPTZ  DEFAULT now()
);

CREATE UNIQUE INDEX idx_empresas_identificacion ON empresas (identificacion);
CREATE INDEX idx_empresas_estado ON empresas (estado);
CREATE INDEX idx_empresas_tipo   ON empresas (tipo_negocio);
─────────────────────────────────────────────
"""

TABLE_NAME = "empresas"

# Columnas permitidas para ordenamiento (whitelist de seguridad)
SORTABLE_COLUMNS = {
    "nombre_legal",
    "nombre_comercial",
    "tipo_negocio",
    "estado",
    "pais",
    "created_at",
    "fecha_registro",
}

# Columnas permitidas para filtrado
FILTERABLE_COLUMNS = {
    "tipo_negocio",
    "estado",
    "pais",
    "moneda",
}