-- ============================================================
-- TABLAS: historial_estados_pedido + historial_estados_detalle + auditoria
-- Ejecutar en Supabase Dashboard → SQL Editor
-- Ejecutar DESPUÉS de pedidos.sql
-- ============================================================

-- ── historial_estados_pedido ───────────────────────────────

CREATE TABLE public.historial_estados_pedido (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id        UUID NOT NULL,
    estado_anterior  VARCHAR(30),
    estado_nuevo     VARCHAR(30) NOT NULL,
    campo_modificado VARCHAR(100),
    notas            TEXT,
    metadata         JSONB,
    ip_address       VARCHAR(100),
    created_at       TIMESTAMPTZ DEFAULT now(),
    created_by       UUID NOT NULL,

    CONSTRAINT fk_hist_pedido
        FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_hist_pedido_campo
        CHECK (campo_modificado IN ('estado', 'estado_pago', 'estado_cocina'))
);

CREATE INDEX idx_hist_pedido       ON public.historial_estados_pedido (pedido_id);
CREATE INDEX idx_hist_pedido_fecha ON public.historial_estados_pedido (created_at DESC);
CREATE INDEX idx_hist_pedido_estado ON public.historial_estados_pedido (estado_nuevo);


-- ── historial_estados_detalle ──────────────────────────────

CREATE TABLE public.historial_estados_detalle (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    detalle_pedido_id UUID NOT NULL,
    estado_anterior   VARCHAR(30),
    estado_nuevo      VARCHAR(30) NOT NULL,
    notas             TEXT,
    created_at        TIMESTAMPTZ DEFAULT now(),
    created_by        UUID NOT NULL,

    CONSTRAINT fk_hist_detalle
        FOREIGN KEY (detalle_pedido_id) REFERENCES public.detalle_pedidos(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_hist_detalle       ON public.historial_estados_detalle (detalle_pedido_id);
CREATE INDEX idx_hist_detalle_fecha ON public.historial_estados_detalle (created_at DESC);


-- ── auditoria ──────────────────────────────────────────────

CREATE TABLE public.auditoria (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id            UUID,
    sucursal_id           UUID,
    usuario_id            UUID NOT NULL,
    modulo                VARCHAR(50) NOT NULL,
    tabla                 VARCHAR(100) NOT NULL,
    registro_id           UUID,
    accion                VARCHAR(20) NOT NULL,
    datos_anteriores      JSONB,
    datos_nuevos          JSONB,
    cambios_especificos   JSONB,
    ip_address            VARCHAR(100),
    user_agent            TEXT,
    dispositivo           VARCHAR(50),
    ubicacion_geografica  JSONB,
    created_at            TIMESTAMPTZ DEFAULT now(),

    CONSTRAINT chk_auditoria_accion
        CHECK (accion IN ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT')),

    CONSTRAINT chk_auditoria_modulo
        CHECK (modulo IN ('ventas','inventario','productos','usuarios',
                          'cajas','clientes','proveedores','compras','sistema'))
);

-- Índices para consultas frecuentes de auditoría
CREATE INDEX idx_auditoria_empresa   ON public.auditoria (empresa_id);
CREATE INDEX idx_auditoria_tabla     ON public.auditoria (tabla);
CREATE INDEX idx_auditoria_modulo    ON public.auditoria (modulo);
CREATE INDEX idx_auditoria_usuario   ON public.auditoria (usuario_id);
CREATE INDEX idx_auditoria_accion    ON public.auditoria (accion);
CREATE INDEX idx_auditoria_fecha     ON public.auditoria (created_at DESC);
CREATE INDEX idx_auditoria_registro  ON public.auditoria (registro_id);

-- Índice compuesto para la consulta más común: registros de una empresa en rango de fechas
CREATE INDEX idx_auditoria_empresa_fecha
    ON public.auditoria (empresa_id, created_at DESC);

ALTER TABLE public.historial_estados_pedido DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.historial_estados_detalle DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria DISABLE ROW LEVEL SECURITY;