-- ============================================================
-- TABLA: mesas
-- Ejecutar en Supabase Dashboard → SQL Editor
--
-- NOTA: Si ya existe la tabla pedidos, ejecutar también el
-- ALTER TABLE al final para agregar la FK de mesa_id.
-- ============================================================

CREATE TABLE public.mesas (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id    UUID         NOT NULL,
    sucursal_id   UUID         NOT NULL,
    numero        VARCHAR(20)  NOT NULL,
    nombre        VARCHAR(100),
    capacidad     INTEGER      NOT NULL DEFAULT 2,
    zona          VARCHAR(100),
    notas         TEXT,
    estado        VARCHAR(30)  NOT NULL DEFAULT 'libre',
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  DEFAULT now(),
    updated_at    TIMESTAMPTZ  DEFAULT now(),
    created_by    UUID,
    updated_by    UUID,

    CONSTRAINT fk_mesas_empresa
        FOREIGN KEY (empresa_id)  REFERENCES public.empresas(id)   ON DELETE CASCADE,

    CONSTRAINT fk_mesas_sucursal
        FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id) ON DELETE CASCADE,

    CONSTRAINT chk_mesas_estado
        CHECK (estado IN ('libre', 'ocupada', 'reservada', 'fuera_de_servicio')),

    CONSTRAINT chk_mesas_capacidad
        CHECK (capacidad > 0),

    -- El número de mesa debe ser único por sucursal
    CONSTRAINT uq_mesas_numero_sucursal
        UNIQUE (sucursal_id, numero)
);

CREATE INDEX idx_mesas_sucursal  ON public.mesas (sucursal_id);
CREATE INDEX idx_mesas_empresa   ON public.mesas (empresa_id);
CREATE INDEX idx_mesas_estado    ON public.mesas (estado);
CREATE INDEX idx_mesas_zona      ON public.mesas (zona);
CREATE INDEX idx_mesas_is_active ON public.mesas (is_active);

ALTER TABLE public.mesas DISABLE ROW LEVEL SECURITY;


-- ── FK desde pedidos → mesas ───────────────────────────────
-- Ejecutar solo si la tabla pedidos ya existe.
-- Vincula pedidos.mesa_id con el catálogo de mesas.

ALTER TABLE public.pedidos
    ADD CONSTRAINT fk_pedidos_mesa
    FOREIGN KEY (mesa_id) REFERENCES public.mesas(id)
    ON DELETE SET NULL;
