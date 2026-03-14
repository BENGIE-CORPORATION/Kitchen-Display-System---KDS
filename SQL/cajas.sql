-- ============================================================
-- TABLAS: cajas + sesiones_caja + movimientos_caja
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.cajas (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sucursal_id           UUID NOT NULL,
    codigo                VARCHAR(50) NOT NULL,
    nombre                VARCHAR(100) NOT NULL,
    tipo                  VARCHAR(30) NOT NULL DEFAULT 'principal',
    descripcion           TEXT,
    numero_serie_fiscal   VARCHAR(100),
    estado                VARCHAR(20) NOT NULL DEFAULT 'activo',
    created_at            TIMESTAMPTZ DEFAULT now(),
    updated_at            TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT fk_cajas_sucursal
        FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_cajas_tipo
        CHECK (tipo IN ('principal','secundaria','express')),

    CONSTRAINT chk_cajas_estado
        CHECK (estado IN ('activo','inactivo','mantenimiento')),

    CONSTRAINT uq_cajas_codigo_sucursal
        UNIQUE (sucursal_id, codigo)
);

CREATE INDEX idx_cajas_sucursal ON public.cajas (sucursal_id);
CREATE INDEX idx_cajas_estado   ON public.cajas (estado);


-- ── sesiones_caja ──────────────────────────────────────────

CREATE TABLE public.sesiones_caja (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caja_id                 UUID NOT NULL,
    usuario_id              UUID NOT NULL,
    numero_sesion           VARCHAR(50) NOT NULL,
    monto_apertura          DECIMAL(12,2) NOT NULL,
    monto_cierre            DECIMAL(12,2),
    monto_esperado          DECIMAL(12,2),
    diferencia              DECIMAL(12,2),
    total_ventas            DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_efectivo          DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_tarjeta_debito    DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_tarjeta_credito   DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_transferencia     DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_sinpe             DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_otros             DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_entradas          DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_salidas           DECIMAL(12,2) NOT NULL DEFAULT 0,
    cantidad_transacciones  INTEGER NOT NULL DEFAULT 0,
    estado                  VARCHAR(20) NOT NULL DEFAULT 'abierta',
    fecha_apertura          TIMESTAMPTZ DEFAULT now(),
    fecha_cierre            TIMESTAMPTZ,
    notas_apertura          TEXT,
    notas_cierre            TEXT,
    created_at              TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT fk_sesiones_caja
        FOREIGN KEY (caja_id) REFERENCES public.cajas(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_sesiones_estado
        CHECK (estado IN ('abierta','cerrada','auditada')),

    CONSTRAINT chk_sesiones_monto_apertura
        CHECK (monto_apertura >= 0),

    -- Solo una sesión abierta por caja a la vez
    CONSTRAINT uq_sesiones_caja_abierta
        EXCLUDE USING btree (caja_id WITH =)
        WHERE (estado = 'abierta')
);

CREATE INDEX idx_sesiones_caja    ON public.sesiones_caja (caja_id);
CREATE INDEX idx_sesiones_usuario ON public.sesiones_caja (usuario_id);
CREATE INDEX idx_sesiones_estado  ON public.sesiones_caja (estado);
CREATE INDEX idx_sesiones_fecha   ON public.sesiones_caja (fecha_apertura DESC);
CREATE INDEX idx_sesiones_numero  ON public.sesiones_caja (caja_id, numero_sesion);


-- ── movimientos_caja ───────────────────────────────────────

CREATE TABLE public.movimientos_caja (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sesion_caja_id  UUID NOT NULL,
    tipo            VARCHAR(20) NOT NULL,
    concepto        VARCHAR(255) NOT NULL,
    monto           DECIMAL(12,2) NOT NULL,
    metodo_pago     VARCHAR(30),
    comprobante     VARCHAR(255),
    documento_url   TEXT,
    beneficiario    VARCHAR(255),
    notas           TEXT,
    created_at      TIMESTAMPTZ DEFAULT now(),
    created_by      UUID NOT NULL,

    CONSTRAINT fk_mov_caja_sesion
        FOREIGN KEY (sesion_caja_id) REFERENCES public.sesiones_caja(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_mov_caja_tipo
        CHECK (tipo IN ('entrada','salida')),

    CONSTRAINT chk_mov_caja_metodo
        CHECK (metodo_pago IN ('efectivo','tarjeta_debito','tarjeta_credito',
                               'transferencia','sinpe','otros')),

    CONSTRAINT chk_mov_caja_monto
        CHECK (monto > 0)
);

CREATE INDEX idx_mov_caja_sesion ON public.movimientos_caja (sesion_caja_id);
CREATE INDEX idx_mov_caja_tipo   ON public.movimientos_caja (tipo);
CREATE INDEX idx_mov_caja_fecha  ON public.movimientos_caja (created_at DESC);

ALTER TABLE public.cajas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.sesiones_caja DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos_caja DISABLE ROW LEVEL SECURITY;