-- ============================================================
-- TABLAS: productos + productos_sucursales
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

-- ── productos ──────────────────────────────────────────────

CREATE TABLE public.productos (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id              UUID NOT NULL,
    categoria_id            UUID NOT NULL,
    codigo_interno          VARCHAR(100),
    codigo_barras           VARCHAR(100),
    nombre                  VARCHAR(255) NOT NULL,
    descripcion             TEXT,
    descripcion_corta       VARCHAR(500),
    marca                   VARCHAR(100),
    modelo                  VARCHAR(100),
    unidad_medida           VARCHAR(30)  NOT NULL DEFAULT 'unidad',
    tipo_producto           VARCHAR(30)  NOT NULL,
    imagen_principal_url    TEXT,
    imagenes_adicionales    JSONB,
    es_vendible             BOOLEAN NOT NULL DEFAULT true,
    es_comprable            BOOLEAN NOT NULL DEFAULT true,
    requiere_inventario     BOOLEAN NOT NULL DEFAULT true,
    permite_decimal         BOOLEAN NOT NULL DEFAULT false,
    tags                    JSONB,
    estado                  VARCHAR(20)  NOT NULL DEFAULT 'activo',
    created_at              TIMESTAMPTZ DEFAULT now(),
    updated_at              TIMESTAMPTZ DEFAULT now(),
    created_by              UUID,
    updated_by              UUID,

    CONSTRAINT fk_productos_empresa
        FOREIGN KEY (empresa_id) REFERENCES public.empresas(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_productos_categoria
        FOREIGN KEY (categoria_id) REFERENCES public.categorias(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_productos_tipo
        CHECK (tipo_producto IN ('simple', 'compuesto', 'servicio', 'combo')),

    CONSTRAINT chk_productos_unidad
        CHECK (unidad_medida IN ('unidad', 'kg', 'g', 'l', 'ml', 'm', 'pack')),

    CONSTRAINT chk_productos_estado
        CHECK (estado IN ('activo', 'inactivo', 'descontinuado'))
);

CREATE UNIQUE INDEX idx_productos_codigo
    ON public.productos (empresa_id, codigo_interno)
    WHERE codigo_interno IS NOT NULL;

CREATE INDEX idx_productos_empresa    ON public.productos (empresa_id);
CREATE INDEX idx_productos_categoria  ON public.productos (categoria_id);
CREATE INDEX idx_productos_barras     ON public.productos (codigo_barras);
CREATE INDEX idx_productos_tipo       ON public.productos (tipo_producto);
CREATE INDEX idx_productos_estado     ON public.productos (estado);


-- ── productos_sucursales ───────────────────────────────────

CREATE TABLE public.productos_sucursales (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id         UUID NOT NULL,
    sucursal_id         UUID NOT NULL,
    precio_venta        DECIMAL(12,2) NOT NULL,
    precio_costo        DECIMAL(12,2),
    precio_mayoreo      DECIMAL(12,2),
    cantidad_mayoreo    INTEGER,
    aplica_iva          BOOLEAN NOT NULL DEFAULT true,
    aplica_servicio     BOOLEAN NOT NULL DEFAULT true,
    porcentaje_iva      DECIMAL(5,2) NOT NULL DEFAULT 13.00,
    porcentaje_servicio DECIMAL(5,2) NOT NULL DEFAULT 10.00,
    margen_utilidad     DECIMAL(5,2),
    stock_disponible    DECIMAL(12,3) NOT NULL DEFAULT 0,
    stock_minimo        DECIMAL(12,3) NOT NULL DEFAULT 0,
    stock_maximo        DECIMAL(12,3),
    punto_reorden       DECIMAL(12,3),
    ubicacion_fisica    VARCHAR(100),
    disponible_venta    BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT fk_ps_producto
        FOREIGN KEY (producto_id) REFERENCES public.productos(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_ps_sucursal
        FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_ps_precio_positivo
        CHECK (precio_venta >= 0),

    CONSTRAINT chk_ps_stock_positivo
        CHECK (stock_disponible >= 0)
);

CREATE UNIQUE INDEX idx_prod_suc_unique
    ON public.productos_sucursales (producto_id, sucursal_id);

CREATE INDEX idx_prod_suc_producto    ON public.productos_sucursales (producto_id);
CREATE INDEX idx_prod_suc_sucursal    ON public.productos_sucursales (sucursal_id);
CREATE INDEX idx_prod_suc_disponible  ON public.productos_sucursales (disponible_venta);

-- RLS deshabilitado para desarrollo
ALTER TABLE public.productos DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.productos_sucursales DISABLE ROW LEVEL SECURITY;