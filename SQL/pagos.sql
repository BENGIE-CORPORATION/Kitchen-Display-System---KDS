-- ============================================================
-- TABLAS: pagos + divisiones_cuenta + detalle_divisiones
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.pagos (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id           UUID NOT NULL,
    sesion_caja_id      UUID NOT NULL,
    numero_pago         VARCHAR(50) NOT NULL,
    metodo_pago         VARCHAR(30) NOT NULL,
    monto               DECIMAL(12,2) NOT NULL,
    monto_recibido      DECIMAL(12,2),
    cambio              DECIMAL(12,2),
    referencia          VARCHAR(255),
    banco               VARCHAR(100),
    numero_cheque       VARCHAR(100),
    fecha_cheque        DATE,
    titular_tarjeta     VARCHAR(255),
    ultimos_4_digitos   VARCHAR(4),
    tipo_tarjeta        VARCHAR(20),
    cuotas              INTEGER NOT NULL DEFAULT 1,
    comprobante_url     TEXT,
    estado              VARCHAR(20) NOT NULL DEFAULT 'completado',
    notas               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    created_by          UUID NOT NULL,

    CONSTRAINT fk_pagos_pedido
        FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_pagos_sesion
        FOREIGN KEY (sesion_caja_id) REFERENCES public.sesiones_caja(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_pagos_metodo
        CHECK (metodo_pago IN ('efectivo','tarjeta_debito','tarjeta_credito',
                               'transferencia','sinpe','cheque','credito','otros')),
    CONSTRAINT chk_pagos_tipo_tarjeta
        CHECK (tipo_tarjeta IN ('visa','mastercard','amex')),
    CONSTRAINT chk_pagos_estado
        CHECK (estado IN ('completado','pendiente','rechazado','reversado')),
    CONSTRAINT chk_pagos_monto
        CHECK (monto > 0),
    CONSTRAINT chk_pagos_cuotas
        CHECK (cuotas >= 1),
    -- Efectivo requiere monto_recibido >= monto
    CONSTRAINT chk_pagos_efectivo
        CHECK (metodo_pago != 'efectivo' OR
               (monto_recibido IS NOT NULL AND monto_recibido >= monto))
);

CREATE INDEX idx_pagos_pedido   ON public.pagos (pedido_id);
CREATE INDEX idx_pagos_sesion   ON public.pagos (sesion_caja_id);
CREATE INDEX idx_pagos_metodo   ON public.pagos (metodo_pago);
CREATE INDEX idx_pagos_estado   ON public.pagos (estado);
CREATE INDEX idx_pagos_fecha    ON public.pagos (created_at DESC);


-- ── divisiones_cuenta ──────────────────────────────────────

CREATE TABLE public.divisiones_cuenta (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id        UUID NOT NULL,
    numero_division  INTEGER NOT NULL,
    tipo_division    VARCHAR(30) NOT NULL,
    porcentaje       DECIMAL(5,2),
    monto            DECIMAL(12,2),
    descripcion      VARCHAR(255),
    estado           VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    created_at       TIMESTAMPTZ DEFAULT now(),
    created_by       UUID,

    CONSTRAINT fk_divisiones_pedido
        FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_divisiones_tipo
        CHECK (tipo_division IN ('por_monto','por_porcentaje','por_productos','por_persona')),
    CONSTRAINT chk_divisiones_estado
        CHECK (estado IN ('pendiente','pagado')),
    CONSTRAINT chk_divisiones_porcentaje
        CHECK (porcentaje IS NULL OR (porcentaje >= 0 AND porcentaje <= 100)),
    CONSTRAINT chk_divisiones_por_porcentaje
        CHECK (tipo_division != 'por_porcentaje' OR porcentaje IS NOT NULL),
    CONSTRAINT chk_divisiones_por_monto
        CHECK (tipo_division != 'por_monto' OR monto IS NOT NULL)
);

CREATE INDEX idx_divisiones_pedido ON public.divisiones_cuenta (pedido_id);


-- ── detalle_divisiones ─────────────────────────────────────

CREATE TABLE public.detalle_divisiones (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    division_id         UUID NOT NULL,
    detalle_pedido_id   UUID NOT NULL,
    cantidad            DECIMAL(10,3),
    monto               DECIMAL(12,2) NOT NULL,
    created_at          TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT fk_det_divisiones_division
        FOREIGN KEY (division_id) REFERENCES public.divisiones_cuenta(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_det_divisiones_detalle
        FOREIGN KEY (detalle_pedido_id) REFERENCES public.detalle_pedidos(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_det_divisiones_monto
        CHECK (monto >= 0)
);

CREATE INDEX idx_det_divisiones_division ON public.detalle_divisiones (division_id);
CREATE INDEX idx_det_divisiones_detalle  ON public.detalle_divisiones (detalle_pedido_id);

ALTER TABLE public.pagos DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.divisiones_cuenta DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_divisiones DISABLE ROW LEVEL SECURITY;