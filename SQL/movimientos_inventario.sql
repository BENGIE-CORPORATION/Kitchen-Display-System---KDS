-- ============================================================
-- TABLAS: movimientos_inventario + detalle_movimientos_inventario
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.movimientos_inventario (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id          UUID NOT NULL,
    sucursal_id         UUID NOT NULL,
    sucursal_origen_id  UUID,
    sucursal_destino_id UUID,
    tipo_movimiento     VARCHAR(50) NOT NULL,
    numero_movimiento   VARCHAR(50) NOT NULL,
    fecha_movimiento    TIMESTAMPTZ DEFAULT now(),
    proveedor_id        UUID,
    orden_compra_id     UUID,
    pedido_id           UUID,
    usuario_responsable UUID NOT NULL,
    total_costo         DECIMAL(12,2) NOT NULL DEFAULT 0,
    motivo              TEXT,
    numero_factura      VARCHAR(100),
    documento_url       TEXT,
    estado              VARCHAR(20) NOT NULL DEFAULT 'borrador',
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now(),
    created_by          UUID NOT NULL,

    CONSTRAINT fk_mov_empresa
        FOREIGN KEY (empresa_id) REFERENCES public.empresas(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_mov_sucursal
        FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_mov_sucursal_origen
        FOREIGN KEY (sucursal_origen_id) REFERENCES public.sucursales(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_mov_sucursal_destino
        FOREIGN KEY (sucursal_destino_id) REFERENCES public.sucursales(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_mov_proveedor
        FOREIGN KEY (proveedor_id) REFERENCES public.proveedores(id)
        ON DELETE SET NULL,

    CONSTRAINT fk_mov_orden_compra
        FOREIGN KEY (orden_compra_id) REFERENCES public.ordenes_compra(id)
        ON DELETE SET NULL,

    CONSTRAINT chk_mov_tipo
        CHECK (tipo_movimiento IN (
            'entrada_compra','entrada_devolucion','entrada_ajuste','entrada_transferencia',
            'salida_venta','salida_merma','salida_devolucion','salida_transferencia',
            'ajuste_inventario'
        )),

    CONSTRAINT chk_mov_estado
        CHECK (estado IN ('borrador','completado','cancelado')),

    CONSTRAINT chk_mov_transferencia_sucursales
        CHECK (
            (tipo_movimiento NOT IN ('entrada_transferencia','salida_transferencia'))
            OR (sucursal_origen_id IS NOT NULL AND sucursal_destino_id IS NOT NULL
                AND sucursal_origen_id != sucursal_destino_id)
        ),

    CONSTRAINT uq_mov_numero_empresa
        UNIQUE (empresa_id, numero_movimiento)
);

CREATE INDEX idx_mov_inv_empresa    ON public.movimientos_inventario (empresa_id);
CREATE INDEX idx_mov_inv_sucursal   ON public.movimientos_inventario (sucursal_id);
CREATE INDEX idx_mov_inv_tipo       ON public.movimientos_inventario (tipo_movimiento);
CREATE INDEX idx_mov_inv_estado     ON public.movimientos_inventario (estado);
CREATE INDEX idx_mov_inv_fecha      ON public.movimientos_inventario (fecha_movimiento DESC);
CREATE INDEX idx_mov_inv_numero     ON public.movimientos_inventario (empresa_id, numero_movimiento);


-- ── detalle_movimientos_inventario ────────────────────────────────────────────

CREATE TABLE public.detalle_movimientos_inventario (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    movimiento_id       UUID NOT NULL,
    materia_prima_id    UUID,
    producto_id         UUID,
    lote_id             UUID,
    cantidad            DECIMAL(12,3) NOT NULL,
    unidad_medida       VARCHAR(30) NOT NULL,
    costo_unitario      DECIMAL(12,4),
    costo_total         DECIMAL(12,2),
    stock_anterior      DECIMAL(12,3) NOT NULL,
    stock_nuevo         DECIMAL(12,3) NOT NULL,
    notas               TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT fk_det_mov_movimiento
        FOREIGN KEY (movimiento_id) REFERENCES public.movimientos_inventario(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_det_mov_producto
        FOREIGN KEY (producto_id) REFERENCES public.productos(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_det_mov_referencia
        CHECK (
            (materia_prima_id IS NOT NULL AND producto_id IS NULL) OR
            (materia_prima_id IS NULL AND producto_id IS NOT NULL)
        ),

    CONSTRAINT chk_det_mov_cantidad_positiva
        CHECK (cantidad > 0),

    CONSTRAINT chk_det_mov_stock_positivo
        CHECK (stock_anterior >= 0 AND stock_nuevo >= 0)
);

CREATE INDEX idx_det_mov_movimiento ON public.detalle_movimientos_inventario (movimiento_id);
CREATE INDEX idx_det_mov_producto   ON public.detalle_movimientos_inventario (producto_id);
CREATE INDEX idx_det_mov_lote       ON public.detalle_movimientos_inventario (lote_id);

ALTER TABLE public.movimientos_inventario DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_movimientos_inventario DISABLE ROW LEVEL SECURITY;