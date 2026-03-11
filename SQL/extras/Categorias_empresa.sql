-- Reemplaza este UUID con el id real de tu empresa
DO $$
DECLARE
    v_empresa_id UUID := 'b666f17c-0710-4b10-97cf-c3e2a28545ed';
    v_alimentos  UUID;
    v_bebidas    UUID;
    v_productos  UUID;
    v_servicios  UUID;
BEGIN

-- ── Categorías raíz ──────────────────────────────────────────────────────────

INSERT INTO public.categorias (empresa_id, nombre, tipo, codigo, orden, estado)
VALUES (v_empresa_id, 'Alimentos', 'alimento', 'ALI', 1, 'activo')
RETURNING id INTO v_alimentos;

INSERT INTO public.categorias (empresa_id, nombre, tipo, codigo, orden, estado)
VALUES (v_empresa_id, 'Bebidas', 'bebida', 'BEB', 2, 'activo')
RETURNING id INTO v_bebidas;

INSERT INTO public.categorias (empresa_id, nombre, tipo, codigo, orden, estado)
VALUES (v_empresa_id, 'Productos', 'producto', 'PROD', 3, 'activo')
RETURNING id INTO v_productos;

INSERT INTO public.categorias (empresa_id, nombre, tipo, codigo, orden, estado)
VALUES (v_empresa_id, 'Servicios', 'servicio', 'SERV', 4, 'activo')
RETURNING id INTO v_servicios;

-- ── Subcategorías de Alimentos ───────────────────────────────────────────────

INSERT INTO public.categorias (empresa_id, nombre, tipo, codigo, categoria_padre_id, orden, estado)
VALUES
    (v_empresa_id, 'Entradas',   'alimento', 'ALI-ENT', v_alimentos, 1, 'activo'),
    (v_empresa_id, 'Platos Fuertes', 'alimento', 'ALI-PF', v_alimentos, 2, 'activo'),
    (v_empresa_id, 'Postres',    'alimento', 'ALI-POS', v_alimentos, 3, 'activo');

-- ── Subcategorías de Bebidas ─────────────────────────────────────────────────

INSERT INTO public.categorias (empresa_id, nombre, tipo, codigo, categoria_padre_id, orden, estado)
VALUES
    (v_empresa_id, 'Bebidas Calientes', 'bebida', 'BEB-CAL', v_bebidas, 1, 'activo'),
    (v_empresa_id, 'Bebidas Frías',     'bebida', 'BEB-FRI', v_bebidas, 2, 'activo'),
    (v_empresa_id, 'Bebidas Alcohólicas', 'bebida', 'BEB-ALC', v_bebidas, 3, 'activo');

RAISE NOTICE 'Categorías creadas correctamente';
RAISE NOTICE 'ID Alimentos: %', v_alimentos;
RAISE NOTICE 'ID Bebidas:   %', v_bebidas;
RAISE NOTICE 'ID Productos: %', v_productos;
RAISE NOTICE 'ID Servicios: %', v_servicios;

END $$;