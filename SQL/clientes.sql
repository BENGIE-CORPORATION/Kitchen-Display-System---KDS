-- ============================================================
-- TABLA: clientes
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.clientes (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id            UUID NOT NULL,
    tipo_cliente          VARCHAR(30) NOT NULL DEFAULT 'final',
    tipo_identificacion   VARCHAR(30),
    identificacion        VARCHAR(100),
    nombre                VARCHAR(255) NOT NULL,
    apellido              VARCHAR(255),
    nombre_comercial      VARCHAR(255),
    email                 VARCHAR(255),
    telefono              VARCHAR(50),
    telefono_alternativo  VARCHAR(50),
    fecha_nacimiento      DATE,
    direccion             TEXT,
    ciudad                VARCHAR(100),
    codigo_postal         VARCHAR(20),
    pais                  VARCHAR(2),
    genero                VARCHAR(20),
    permite_marketing     BOOLEAN NOT NULL DEFAULT false,
    notas                 TEXT,
    limite_credito        DECIMAL(12,2),
    descuento_porcentaje  DECIMAL(5,2) NOT NULL DEFAULT 0,
    puntos_fidelidad      INTEGER NOT NULL DEFAULT 0,
    fecha_registro        TIMESTAMPTZ DEFAULT now(),
    ultima_compra         TIMESTAMPTZ,
    total_compras         DECIMAL(12,2) NOT NULL DEFAULT 0,
    cantidad_compras      INTEGER NOT NULL DEFAULT 0,
    estado                VARCHAR(20) NOT NULL DEFAULT 'activo',
    created_at            TIMESTAMPTZ DEFAULT now(),
    updated_at            TIMESTAMPTZ DEFAULT now(),
    created_by            UUID,
    updated_by            UUID,

    CONSTRAINT fk_clientes_empresa
        FOREIGN KEY (empresa_id) REFERENCES public.empresas(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_clientes_tipo
        CHECK (tipo_cliente IN ('final','frecuente','corporativo','mayorista')),

    CONSTRAINT chk_clientes_tipo_identificacion
        CHECK (tipo_identificacion IN ('DNI','RUC','Pasaporte','Cedula')),

    CONSTRAINT chk_clientes_genero
        CHECK (genero IN ('M','F','Otro','No especifica')),

    CONSTRAINT chk_clientes_estado
        CHECK (estado IN ('activo','inactivo','bloqueado')),

    CONSTRAINT chk_clientes_descuento
        CHECK (descuento_porcentaje >= 0 AND descuento_porcentaje <= 100),

    CONSTRAINT chk_clientes_puntos
        CHECK (puntos_fidelidad >= 0),

    CONSTRAINT chk_clientes_totales
        CHECK (total_compras >= 0 AND cantidad_compras >= 0),

    -- Identificación única por empresa cuando está presente
    CONSTRAINT uq_clientes_identificacion_empresa
        UNIQUE (empresa_id, identificacion)
);

CREATE INDEX idx_clientes_empresa        ON public.clientes (empresa_id);
CREATE INDEX idx_clientes_identificacion ON public.clientes (identificacion);
CREATE INDEX idx_clientes_email          ON public.clientes (email);
CREATE INDEX idx_clientes_telefono       ON public.clientes (telefono);
CREATE INDEX idx_clientes_tipo           ON public.clientes (tipo_cliente);
CREATE INDEX idx_clientes_estado         ON public.clientes (estado);

ALTER TABLE public.clientes DISABLE ROW LEVEL SECURITY;