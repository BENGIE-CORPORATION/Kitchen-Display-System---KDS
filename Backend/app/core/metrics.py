"""
Métricas de negocio KDS — prometheus_client.

Todas usan el prefijo `kds_` para distinguirlas de las métricas HTTP
que genera prometheus-fastapi-instrumentator automáticamente.

Uso en un router:
    from app.core.metrics import pedidos_creados
    pedidos_creados.labels(tipo_pedido="mesa").inc()

Las métricas HTTP (latencia, requests/s, status codes) las genera el
instrumentator automáticamente — no hay que declararlas aquí.
"""

from prometheus_client import Counter, Gauge

# ── Auth ──────────────────────────────────────────────────────────────────────

auth_logins = Counter(
    "kds_auth_logins_total",
    "Intentos de login",
    ["resultado"],   # exitoso | fallido | bloqueado
)

auth_registros = Counter(
    "kds_auth_registros_total",
    "Registros de empresa completados",
    ["resultado"],   # exitoso | fallido
)

# ── Pedidos ───────────────────────────────────────────────────────────────────

pedidos_creados = Counter(
    "kds_pedidos_creados_total",
    "Pedidos creados",
    ["tipo_pedido"],  # mesa | para_llevar | delivery | barra | etc.
)

pedido_estado_cambios = Counter(
    "kds_pedido_estado_cambios_total",
    "Transiciones de estado de pedidos",
    ["de", "a"],     # estado anterior → estado nuevo
)

# ── Pagos ─────────────────────────────────────────────────────────────────────

pagos_registrados = Counter(
    "kds_pagos_registrados_total",
    "Pagos registrados",
    ["metodo_pago"],  # efectivo | tarjeta | transferencia | etc.
)

pagos_monto_acumulado = Counter(
    "kds_pagos_monto_acumulado_total",
    "Suma acumulada de montos pagados (en unidad monetaria base)",
)

pagos_reversados = Counter(
    "kds_pagos_reversados_total",
    "Pagos reversados o rechazados por estado",
    ["estado"],       # reversado | rechazado
)

# ── Cajas ─────────────────────────────────────────────────────────────────────

cajas_sesiones_abiertas = Gauge(
    "kds_cajas_sesiones_abiertas_actual",
    "Sesiones de caja abiertas en este momento",
)

cajas_aperturas = Counter(
    "kds_cajas_aperturas_total",
    "Total de aperturas de sesión de caja",
)

cajas_cierres = Counter(
    "kds_cajas_cierres_total",
    "Total de cierres de sesión de caja",
)
