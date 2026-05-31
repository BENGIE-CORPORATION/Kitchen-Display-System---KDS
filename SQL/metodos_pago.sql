-- ============================================================
-- TABLA: metodos_pago
-- Ejecutar en Supabase Dashboard → SQL Editor
--
-- Permite configurar qué métodos de pago acepta cada empresa.
-- Los tipos base coinciden con los valores ya usados en pagos
-- y movimientos_caja para mantener consistencia.
-- ============================================================

CREATE TABLE public.metodos_pago (
    id                   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id           UUID          NOT NULL,
    nombre               VARCHAR(100)  NOT NULL,
    codigo               VARCHAR(50)   NOT NULL,
    tipo                 VARCHAR(30)   NOT NULL DEFAULT 'efectivo',
    requiere_referencia  BOOLEAN       NOT NULL DEFAULT FALSE,
    requiere_tarjeta     BOOLEAN       NOT NULL DEFAULT FALSE,
    permite_vuelto       BOOLEAN       NOT NULL DEFAULT FALSE,
    comision_porcentaje  DECIMAL(5,4)  NOT NULL DEFAULT 0,
    instrucciones        TEXT,
    is_active            BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ   DEFAULT now(),
    updated_at           TIMESTAMPTZ   DEFAULT now(),
    created_by           UUID,
    updated_by           UUID,

    CONSTRAINT fk_metodos_pago_empresa
        FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE CASCADE,

    CONSTRAINT chk_metodos_pago_tipo
        CHECK (tipo IN (
            'efectivo', 'tarjeta_debito', 'tarjeta_credito',
            'transferencia', 'sinpe', 'cheque', 'credito',
            'qr', 'crypto', 'otros'
        )),

    CONSTRAINT chk_metodos_pago_comision
        CHECK (comision_porcentaje >= 0 AND comision_porcentaje < 1),

    -- El código debe ser único por empresa (ej: "efectivo", "visa_credito")
    CONSTRAINT uq_metodos_pago_codigo_empresa
        UNIQUE (empresa_id, codigo)
);

CREATE INDEX idx_metodos_pago_empresa  ON public.metodos_pago (empresa_id);
CREATE INDEX idx_metodos_pago_tipo     ON public.metodos_pago (tipo);
CREATE INDEX idx_metodos_pago_activo   ON public.metodos_pago (is_active);

ALTER TABLE public.metodos_pago DISABLE ROW LEVEL SECURITY;
