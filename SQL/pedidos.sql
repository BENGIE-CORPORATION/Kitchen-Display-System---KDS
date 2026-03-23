-- ============================================================
-- TABLAS: pedidos + detalle_pedidos
-- Ejecutar en Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE public.pedidos (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id                UUID NOT NULL,
    sucursal_id               UUID NOT NULL,
    numero_pedido             VARCHAR(50) NOT NULL,
    numero_factura            VARCHAR(50),
    tipo_pedido               VARCHAR(30) NOT NULL,
    tipo_venta                VARCHAR(30) NOT NULL DEFAULT 'contado',
    canal_venta               VARCHAR(30) NOT NULL DEFAULT 'presencial',
    mesa_id                   UUID,
    cliente_id                UUID,
    nombre_cliente            VARCHAR(255),
    telefono_cliente          VARCHAR(50),
    direccion_entrega         TEXT,
    cantidad_comensales       INTEGER,
    mesero_id                 UUID,
    subtotal                  DECIMAL(12,2) NOT NULL DEFAULT 0,
    descuento_porcentaje      DECIMAL(5,2) NOT NULL DEFAULT 0,
    descuento_monto           DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_iva                 DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_servicio            DECIMAL(12,2) NOT NULL DEFAULT 0,
    propina                   DECIMAL(12,2) NOT NULL DEFAULT 0,
    total                     DECIMAL(12,2) NOT NULL DEFAULT 0,
    estado                    VARCHAR(30) NOT NULL DEFAULT 'borrador',
    estado_pago               VARCHAR(30) NOT NULL DEFAULT 'pendiente',
    estado_cocina             VARCHAR(30) DEFAULT 'pendiente',
    prioridad                 VARCHAR(20) NOT NULL DEFAULT 'normal',
    tiempo_estimado_minutos   INTEGER,
    motivo_cancelacion        TEXT,
    sesion_caja_id            UUID,
    fecha_pedido              TIMESTAMPTZ DEFAULT now(),
    fecha_facturacion         TIMESTAMPTZ,
    fecha_entrega             TIMESTAMPTZ,
    created_at                TIMESTAMPTZ DEFAULT now(),
    updated_at                TIMESTAMPTZ DEFAULT now(),
    created_by                UUID NOT NULL,
    updated_by                UUID,

    CONSTRAINT fk_pedidos_empresa
        FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE RESTRICT,
    CONSTRAINT fk_pedidos_sucursal
        FOREIGN KEY (sucursal_id) REFERENCES public.sucursales(id) ON DELETE RESTRICT,
    CONSTRAINT fk_pedidos_cliente
        FOREIGN KEY (cliente_id) REFERENCES public.clientes(id) ON DELETE SET NULL,
    CONSTRAINT fk_pedidos_sesion_caja
        FOREIGN KEY (sesion_caja_id) REFERENCES public.sesiones_caja(id) ON DELETE SET NULL,

    CONSTRAINT chk_pedidos_tipo
        CHECK (tipo_pedido IN ('mesa','para_llevar','domicilio','mostrador')),
    CONSTRAINT chk_pedidos_tipo_venta
        CHECK (tipo_venta IN ('contado','credito')),
    CONSTRAINT chk_pedidos_canal
        CHECK (canal_venta IN ('presencial','telefono','web','app','whatsapp')),
    CONSTRAINT chk_pedidos_estado
        CHECK (estado IN ('borrador','abierto','en_preparacion','listo','en_entrega','entregado','facturado','cancelado')),
    CONSTRAINT chk_pedidos_estado_pago
        CHECK (estado_pago IN ('pendiente','pagado','pago_parcial','credito')),
    CONSTRAINT chk_pedidos_estado_cocina
        CHECK (estado_cocina IN ('pendiente','en_preparacion','listo','entregado')),
    CONSTRAINT chk_pedidos_prioridad
        CHECK (prioridad IN ('baja','normal','alta','urgente')),
    CONSTRAINT chk_pedidos_domicilio
        CHECK (tipo_pedido != 'domicilio' OR direccion_entrega IS NOT NULL),

    CONSTRAINT uq_pedidos_numero_sucursal
        UNIQUE (sucursal_id, numero_pedido)
);

CREATE INDEX idx_pedidos_empresa     ON public.pedidos (empresa_id);
CREATE INDEX idx_pedidos_sucursal    ON public.pedidos (sucursal_id);
CREATE INDEX idx_pedidos_cliente     ON public.pedidos (cliente_id);
CREATE INDEX idx_pedidos_mesa        ON public.pedidos (mesa_id);
CREATE INDEX idx_pedidos_estado      ON public.pedidos (estado);
CREATE INDEX idx_pedidos_estado_pago ON public.pedidos (estado_pago);
CREATE INDEX idx_pedidos_fecha       ON public.pedidos (fecha_pedido DESC);
CREATE INDEX idx_pedidos_tipo        ON public.pedidos (tipo_pedido);
CREATE INDEX idx_pedidos_factura     ON public.pedidos (numero_factura);


-- ── detalle_pedidos ────────────────────────────────────────

CREATE TABLE public.detalle_pedidos (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id                 UUID NOT NULL,
    producto_id               UUID NOT NULL,
    lote_id                   UUID,
    cantidad                  DECIMAL(10,3) NOT NULL,
    unidad_medida             VARCHAR(30) NOT NULL DEFAULT 'unidad',
    precio_unitario           DECIMAL(12,2) NOT NULL,
    descuento_porcentaje      DECIMAL(5,2) NOT NULL DEFAULT 0,
    descuento_monto           DECIMAL(12,2) NOT NULL DEFAULT 0,
    subtotal                  DECIMAL(12,2) NOT NULL,
    iva                       DECIMAL(12,2) NOT NULL DEFAULT 0,
    servicio                  DECIMAL(12,2) NOT NULL DEFAULT 0,
    total                     DECIMAL(12,2) NOT NULL,
    costo_unitario            DECIMAL(12,4),
    costo_total               DECIMAL(12,2),
    utilidad                  DECIMAL(12,2),
    variantes_seleccionadas   JSONB,
    notas                     TEXT,
    estado                    VARCHAR(30) NOT NULL DEFAULT 'pendiente',
    motivo_cancelacion        TEXT,
    fecha_cancelacion         TIMESTAMPTZ,
    created_at                TIMESTAMPTZ DEFAULT now(),
    updated_at                TIMESTAMPTZ DEFAULT now(),
    created_by                UUID,
    updated_by                UUID,
    cancelado_por             UUID,

    CONSTRAINT fk_det_pedidos_pedido
        FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id) ON DELETE CASCADE,
    CONSTRAINT fk_det_pedidos_producto
        FOREIGN KEY (producto_id) REFERENCES public.productos(id) ON DELETE RESTRICT,
    CONSTRAINT fk_det_pedidos_lote
        FOREIGN KEY (lote_id) REFERENCES public.lotes_inventario(id) ON DELETE SET NULL,

    CONSTRAINT chk_det_pedidos_estado
        CHECK (estado IN ('pendiente','en_preparacion','listo','entregado','cancelado')),
    CONSTRAINT chk_det_pedidos_cantidad
        CHECK (cantidad > 0),
    CONSTRAINT chk_det_pedidos_precio
        CHECK (precio_unitario >= 0)
);

CREATE INDEX idx_det_pedidos_pedido   ON public.detalle_pedidos (pedido_id);
CREATE INDEX idx_det_pedidos_producto ON public.detalle_pedidos (producto_id);
CREATE INDEX idx_det_pedidos_estado   ON public.detalle_pedidos (estado);
CREATE INDEX idx_det_pedidos_lote     ON public.detalle_pedidos (lote_id);

ALTER TABLE public.pedidos DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_pedidos DISABLE ROW LEVEL SECURITY;