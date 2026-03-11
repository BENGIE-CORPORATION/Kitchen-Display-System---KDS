-- ============================================================
-- TABLA: combos
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.combos (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id             UUID NOT NULL,
    producto_componente_id  UUID NOT NULL,
    cantidad                DECIMAL(10,3) NOT NULL DEFAULT 1,
    es_opcional             BOOLEAN NOT NULL DEFAULT false,
    created_at              TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT fk_combos_producto
        FOREIGN KEY (producto_id) REFERENCES public.productos(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_combos_componente
        FOREIGN KEY (producto_componente_id) REFERENCES public.productos(id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_combos_unique
        UNIQUE (producto_id, producto_componente_id),

    CONSTRAINT chk_combos_no_self_ref
        CHECK (producto_id != producto_componente_id),

    CONSTRAINT chk_combos_cantidad_positiva
        CHECK (cantidad > 0)
);

CREATE INDEX idx_combos_producto    ON public.combos (producto_id);
CREATE INDEX idx_combos_componente  ON public.combos (producto_componente_id);

ALTER TABLE public.combos DISABLE ROW LEVEL SECURITY;