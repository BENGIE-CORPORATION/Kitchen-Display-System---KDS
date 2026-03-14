-- ============================================================
-- TABLAS: ordenes_compra + detalle_ordenes_compra
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.ordenes_compra (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id              UUID NOT NULL,
    sucursal_id             UUID NOT NULL,
    proveedor_id            UUID NOT NULL,
    numero_orden            VARCHAR(50) NOT NULL,
    fecha_orden             TIMESTAMPTZ DEFAULT now(),
    fecha_entrega_esperada  TIMESTAMPTZ,
    fecha_entrega_real      TIMESTAMPTZ,
    subtotal                DECIMAL(12,2) NOT NULL DEFAULT 0,
    impuestos               DECIMAL(12,2) NOT NULL DEFAULT 0,
    descuentos              DECIMAL(12,2) NOT NULL DEFAULT 0,
    total                   DECIMAL(12,2) NOT NULL DEFAULT 0,
    condicion_pago          VARCHAR(30),
    estado                  VARCHAR(30) NOT NULL DEFAULT 'borrador',
    notas                   TEXT,
    created_at              TIMESTAMPTZ DEFAULT now(),
    updated_at              TIMESTAMPTZ DEFAULT now(),
    created_by              UUID NOT NULL,
    updated_by              UUID,

    CONSTRAINT fk_ordenes_empresa
        FOREIGN KEY (empresa_id) REFERENCES public.empresas(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_ordenes_sucursal
        FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_ordenes_proveedor
        FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_ordenes_estado
        CHECK (estado IN ('borrador','enviada','confirmada','parcial','recibida','cancelada')),

    CONSTRAINT chk_ordenes_condicion_pago
        CHECK (condicion_pago IN ('contado','credito_15','credito_30','credito_60','credito_90')),

    CONSTRAINT chk_ordenes_totales_positivos
        CHECK (subtotal >= 0 AND impuestos >= 0 AND descuentos >= 0 AND total >= 0),

    CONSTRAINT uq_ordenes_numero_sucursal
        UNIQUE (sucursal_id, numero_orden)
);

CREATE INDEX idx_ordenes_empresa    ON public.ordenes_compra (empresa_id);
CREATE INDEX idx_ordenes_sucursal   ON public.ordenes_compra (sucursal_id);
CREATE INDEX idx_ordenes_proveedor  ON public.ordenes_compra (proveedor_id);
CREATE INDEX idx_ordenes_estado     ON public.ordenes_compra (estado);
CREATE INDEX idx_ordenes_fecha      ON public.ordenes_compra (fecha_orden DESC);


-- ── detalle_ordenes_compra ─────────────────────────────────

CREATE TABLE public.detalle_ordenes_compra (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    orden_compra_id         UUID NOT NULL,
    materia_prima_id        UUID,
    producto_id             UUID,
    cantidad_solicitada     DECIMAL(12,3) NOT NULL,
    cantidad_recibida       DECIMAL(12,3) NOT NULL DEFAULT 0,
    unidad_medida           VARCHAR(30) NOT NULL,
    precio_unitario         DECIMAL(12,4) NOT NULL,
    descuento_porcentaje    DECIMAL(5,2) NOT NULL DEFAULT 0,
    descuento_monto         DECIMAL(12,2) NOT NULL DEFAULT 0,
    impuesto_porcentaje     DECIMAL(5,2) NOT NULL DEFAULT 0,
    impuesto_monto          DECIMAL(12,2) NOT NULL DEFAULT 0,
    subtotal                DECIMAL(12,2) NOT NULL,
    total                   DECIMAL(12,2) NOT NULL,
    notas                   TEXT,
    created_at              TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT fk_det_ordenes_orden
        FOREIGN KEY (orden_compra_id) REFERENCES public.ordenes_compra(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_det_ordenes_producto
        FOREIGN KEY (producto_id) REFERENCES public.productos(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_det_ordenes_referencia
        CHECK (
            (materia_prima_id IS NOT NULL AND producto_id IS NULL) OR
            (materia_prima_id IS NULL AND producto_id IS NOT NULL)
        ),

    CONSTRAINT chk_det_ordenes_cantidades
        CHECK (cantidad_solicitada > 0 AND cantidad_recibida >= 0),

    CONSTRAINT chk_det_ordenes_recibida_lte_solicitada
        CHECK (cantidad_recibida <= cantidad_solicitada)
);

CREATE INDEX idx_det_ordenes_orden    ON public.detalle_ordenes_compra (orden_compra_id);
CREATE INDEX idx_det_ordenes_producto ON public.detalle_ordenes_compra (producto_id);

ALTER TABLE public.ordenes_compra DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_ordenes_compra DISABLE ROW LEVEL SECURITY;