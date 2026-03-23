-- ============================================================
-- TABLAS: materias_primas + materias_primas_sucursales
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.materias_primas (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id      UUID NOT NULL,
    codigo          VARCHAR(100),
    nombre          VARCHAR(255) NOT NULL,
    descripcion     TEXT,
    unidad_medida   VARCHAR(30) NOT NULL,
    categoria       VARCHAR(100),
    perecedero      BOOLEAN NOT NULL DEFAULT false,
    dias_vida_util  INTEGER,
    estado          VARCHAR(20) NOT NULL DEFAULT 'activo',
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now(),
    created_by      UUID,
    updated_by      UUID,

    CONSTRAINT fk_materias_empresa
        FOREIGN KEY (empresa_id) REFERENCES public.empresas(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_materias_unidad
        CHECK (unidad_medida IN ('kg','g','l','ml','unidades','m','m2','m3')),

    CONSTRAINT chk_materias_estado
        CHECK (estado IN ('activo','inactivo')),

    CONSTRAINT chk_materias_dias_vida_util
        CHECK (dias_vida_util IS NULL OR dias_vida_util > 0),

    -- Perecedero requiere dias_vida_util
    CONSTRAINT chk_materias_perecedero_dias
        CHECK (NOT perecedero OR dias_vida_util IS NOT NULL)
);

CREATE UNIQUE INDEX idx_materias_codigo
    ON public.materias_primas (empresa_id, codigo)
    WHERE codigo IS NOT NULL;

CREATE INDEX idx_materias_empresa ON public.materias_primas (empresa_id);
CREATE INDEX idx_materias_estado  ON public.materias_primas (estado);


-- ── materias_primas_sucursales ────────────────────────────────────────────────

CREATE TABLE public.materias_primas_sucursales (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    materia_prima_id UUID NOT NULL,
    sucursal_id      UUID NOT NULL,
    stock_actual     DECIMAL(12,3) NOT NULL DEFAULT 0,
    stock_minimo     DECIMAL(12,3) NOT NULL DEFAULT 0,
    stock_maximo     DECIMAL(12,3),
    costo_promedio   DECIMAL(12,4) NOT NULL DEFAULT 0,
    ultimo_costo     DECIMAL(12,4),
    ubicacion_fisica VARCHAR(100),
    created_at       TIMESTAMPTZ DEFAULT now(),
    updated_at       TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT fk_mp_suc_materia
        FOREIGN KEY (materia_prima_id) REFERENCES public.materias_primas(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_mp_suc_sucursal
        FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_mp_suc_unique
        UNIQUE (materia_prima_id, sucursal_id),

    CONSTRAINT chk_mp_suc_stock_positivo
        CHECK (stock_actual >= 0 AND stock_minimo >= 0),

    CONSTRAINT chk_mp_suc_stock_maximo
        CHECK (stock_maximo IS NULL OR stock_maximo >= stock_minimo)
);

CREATE INDEX idx_mp_suc_materia   ON public.materias_primas_sucursales (materia_prima_id);
CREATE INDEX idx_mp_suc_sucursal  ON public.materias_primas_sucursales (sucursal_id);

ALTER TABLE public.materias_primas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.materias_primas_sucursales DISABLE ROW LEVEL SECURITY;