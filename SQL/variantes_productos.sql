-- ============================================================
-- TABLA: variantes_producto
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.variantes_producto (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id UUID NOT NULL,
    nombre      VARCHAR(100) NOT NULL,
    opciones    JSONB NOT NULL,
    orden       INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT fk_variantes_producto
        FOREIGN KEY (producto_id) REFERENCES public.productos(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_variantes_opciones_not_empty
        CHECK (jsonb_array_length(opciones) > 0),

    -- Nombre único por producto
    CONSTRAINT uq_variantes_nombre_producto
        UNIQUE (producto_id, nombre)
);

CREATE INDEX idx_variantes_producto ON public.variantes_producto (producto_id);
CREATE INDEX idx_variantes_orden    ON public.variantes_producto (producto_id, orden);

ALTER TABLE public.variantes_producto DISABLE ROW LEVEL SECURITY;