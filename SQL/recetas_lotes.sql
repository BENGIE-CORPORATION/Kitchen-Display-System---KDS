-- ============================================================
-- TABLAS: recetas + lotes_inventario
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

-- ── recetas ────────────────────────────────────────────────

CREATE TABLE public.recetas (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    producto_id      UUID NOT NULL,
    materia_prima_id UUID NOT NULL,
    cantidad         DECIMAL(12,4) NOT NULL,
    unidad_medida    VARCHAR(30) NOT NULL,
    notas            TEXT,
    created_at       TIMESTAMPTZ DEFAULT now(),
    updated_at       TIMESTAMPTZ DEFAULT now(),
    created_by       UUID,

    CONSTRAINT fk_recetas_producto
        FOREIGN KEY (producto_id) REFERENCES public.productos(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_recetas_materia_prima
        FOREIGN KEY (materia_prima_id) REFERENCES public.materias_primas(id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_recetas_producto_materia
        UNIQUE (producto_id, materia_prima_id),

    CONSTRAINT chk_recetas_cantidad_positiva
        CHECK (cantidad > 0),

    CONSTRAINT chk_recetas_unidad
        CHECK (unidad_medida IN ('kg','g','l','ml','unidades','m','m2','m3'))
);

CREATE INDEX idx_recetas_producto ON public.recetas (producto_id);
CREATE INDEX idx_recetas_materia  ON public.recetas (materia_prima_id);


-- ── lotes_inventario ───────────────────────────────────────

CREATE TABLE public.lotes_inventario (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sucursal_id       UUID NOT NULL,
    materia_prima_id  UUID,
    producto_id       UUID,
    numero_lote       VARCHAR(100) NOT NULL,
    cantidad_inicial  DECIMAL(12,3) NOT NULL,
    cantidad_actual   DECIMAL(12,3) NOT NULL,
    costo_unitario    DECIMAL(12,4) NOT NULL,
    fecha_ingreso     TIMESTAMPTZ DEFAULT now(),
    fecha_vencimiento TIMESTAMPTZ,
    proveedor_id      UUID,
    estado            VARCHAR(20) NOT NULL DEFAULT 'activo',
    created_at        TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT fk_lotes_sucursal
        FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_lotes_materia_prima
        FOREIGN KEY (materia_prima_id) REFERENCES public.materias_primas(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_lotes_producto
        FOREIGN KEY (producto_id) REFERENCES public.productos(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_lotes_proveedor
        FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id)
        ON DELETE SET NULL,

    CONSTRAINT chk_lotes_referencia
        CHECK (
            (materia_prima_id IS NOT NULL AND producto_id IS NULL) OR
            (materia_prima_id IS NULL AND producto_id IS NOT NULL)
        ),

    CONSTRAINT chk_lotes_estado
        CHECK (estado IN ('activo','vencido','agotado')),

    CONSTRAINT chk_lotes_cantidades
        CHECK (cantidad_inicial > 0 AND cantidad_actual >= 0
               AND cantidad_actual <= cantidad_inicial),

    CONSTRAINT chk_lotes_costo_positivo
        CHECK (costo_unitario >= 0)
);

CREATE INDEX idx_lotes_sucursal     ON public.lotes_inventario (sucursal_id);
CREATE INDEX idx_lotes_materia      ON public.lotes_inventario (materia_prima_id);
CREATE INDEX idx_lotes_producto     ON public.lotes_inventario (producto_id);
CREATE INDEX idx_lotes_numero       ON public.lotes_inventario (sucursal_id, numero_lote);
CREATE INDEX idx_lotes_vencimiento  ON public.lotes_inventario (fecha_vencimiento);
CREATE INDEX idx_lotes_estado       ON public.lotes_inventario (estado);

ALTER TABLE public.recetas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.lotes_inventario DISABLE ROW LEVEL SECURITY;