-- ============================================================
-- TABLA: categorias
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.categorias (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id          UUID NOT NULL,
    codigo              VARCHAR(50),
    nombre              VARCHAR(255) NOT NULL,
    tipo                VARCHAR(30)  NOT NULL,
    categoria_padre_id  UUID,
    descripcion         TEXT,
    imagen_url          TEXT,
    orden               INTEGER NOT NULL DEFAULT 0,
    estado              VARCHAR(20) NOT NULL DEFAULT 'activo',
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now(),
    created_by          UUID,
    updated_by          UUID,

    CONSTRAINT fk_categorias_empresa
        FOREIGN KEY (empresa_id) REFERENCES public.empresas(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_categorias_padre
        FOREIGN KEY (categoria_padre_id) REFERENCES public.categorias(id)
        ON DELETE SET NULL,

    CONSTRAINT chk_categorias_tipo
        CHECK (tipo IN ('alimento', 'bebida', 'producto', 'servicio')),

    CONSTRAINT chk_categorias_estado
        CHECK (estado IN ('activo', 'inactivo')),

    CONSTRAINT chk_categorias_no_self_ref
        CHECK (id != categoria_padre_id)
);

CREATE UNIQUE INDEX idx_categorias_emp_codigo
    ON public.categorias (empresa_id, codigo)
    WHERE codigo IS NOT NULL;

CREATE INDEX idx_categorias_empresa  ON public.categorias (empresa_id);
CREATE INDEX idx_categorias_padre    ON public.categorias (categoria_padre_id);
CREATE INDEX idx_categorias_tipo     ON public.categorias (tipo);
CREATE INDEX idx_categorias_estado   ON public.categorias (estado);
CREATE INDEX idx_categorias_orden    ON public.categorias (empresa_id, orden);

-- RLS deshabilitado para desarrollo
ALTER TABLE public.categorias DISABLE ROW LEVEL SECURITY;