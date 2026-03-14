-- ============================================================
-- TABLA: proveedores
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.proveedores (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id              UUID NOT NULL,
    codigo                  VARCHAR(50),
    tipo_identificacion     VARCHAR(30),
    identificacion          VARCHAR(100) NOT NULL,
    nombre_legal            VARCHAR(255) NOT NULL,
    nombre_comercial        VARCHAR(255),
    tipo_proveedor          VARCHAR(30),
    email                   VARCHAR(255),
    telefono                VARCHAR(50),
    telefono_alternativo    VARCHAR(50),
    direccion               TEXT,
    ciudad                  VARCHAR(100),
    pais                    VARCHAR(2),
    sitio_web               VARCHAR(255),
    persona_contacto        VARCHAR(255),
    cargo_contacto          VARCHAR(100),
    email_contacto          VARCHAR(255),
    telefono_contacto       VARCHAR(50),
    condicion_pago          VARCHAR(30) NOT NULL DEFAULT 'contado',
    limite_credito          DECIMAL(12,2),
    cuenta_bancaria         VARCHAR(100),
    notas                   TEXT,
    calificacion            INTEGER,
    estado                  VARCHAR(20) NOT NULL DEFAULT 'activo',
    created_at              TIMESTAMPTZ DEFAULT now(),
    updated_at              TIMESTAMPTZ DEFAULT now(),
    created_by              UUID,
    updated_by              UUID,

    CONSTRAINT fk_proveedores_empresa
        FOREIGN KEY (empresa_id) REFERENCES public.empresas(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_proveedores_tipo_identificacion
        CHECK (tipo_identificacion IN ('RUC', 'CUIT', 'DNI', 'Pasaporte')),

    CONSTRAINT chk_proveedores_tipo
        CHECK (tipo_proveedor IN ('productos', 'servicios', 'materias_primas', 'mixto')),

    CONSTRAINT chk_proveedores_condicion_pago
        CHECK (condicion_pago IN ('contado', 'credito_15', 'credito_30', 'credito_60', 'credito_90')),

    CONSTRAINT chk_proveedores_estado
        CHECK (estado IN ('activo', 'inactivo', 'bloqueado')),

    CONSTRAINT chk_proveedores_calificacion
        CHECK (calificacion BETWEEN 1 AND 5)
);

CREATE UNIQUE INDEX idx_proveedores_identificacion
    ON public.proveedores (empresa_id, identificacion);

CREATE UNIQUE INDEX idx_proveedores_codigo
    ON public.proveedores (empresa_id, codigo)
    WHERE codigo IS NOT NULL;

CREATE INDEX idx_proveedores_empresa ON public.proveedores (empresa_id);
CREATE INDEX idx_proveedores_estado  ON public.proveedores (estado);

ALTER TABLE public.proveedores DISABLE ROW LEVEL SECURITY;