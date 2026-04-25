import 'package:flutter/material.dart';
import '../../../common/models/pedido_models.dart';
import '../../../common/services/api_service.dart';
import '../../../common/widgets/app_data_table.dart';
import '../../../common/widgets/search_filter_bar.dart';
import 'sales_provider.dart';
import 'widgets/pedido_detalle_modal.dart';

class SalesPage extends StatefulWidget {
  final SalesProvider provider;

  const SalesPage({super.key, required this.provider});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const _estados = [
    'Todos', 'borrador', 'abierto', 'en_preparacion',
    'listo', 'en_entrega', 'entregado', 'facturado', 'cancelado',
  ];

  static const _labelsEstado = {
    'borrador': 'Borrador',
    'abierto': 'Abierto',
    'en_preparacion': 'En preparación',
    'listo': 'Listo',
    'en_entrega': 'En entrega',
    'entregado': 'Entregado',
    'facturado': 'Facturado',
    'cancelado': 'Cancelado',
  };

  static const _labelsEstadoPago = {
    'pendiente': 'Pendiente',
    'pagado': 'Pagado',
    'pago_parcial': 'Parcial',
    'credito': 'Crédito',
  };

  static const _labelsTipo = {
    'mesa': 'Mesa',
    'para_llevar': 'Para llevar',
    'domicilio': 'Domicilio',
    'mostrador': 'Mostrador',
  };

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showDetalleModal(PedidoRead pedido) {
    showDialog(
      context: context,
      builder: (_) => PedidoDetalleModal(
        pedido: pedido,
        onSuccess: widget.provider.reload,
      ),
    );
  }

  Future<void> _cambiarEstado(PedidoRead pedido, String nuevoEstado) async {
    if (nuevoEstado == 'cancelado') {
      await _confirmarCancelacion(pedido);
      return;
    }

    try {
      await SalesService.cambiarEstado(pedido.id, nuevoEstado);
      widget.provider.reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmarCancelacion(PedidoRead pedido) async {
    final motivoCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cancelar pedido',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Cancelar el pedido "${pedido.numeroPedido}"?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            const Text('Motivo *',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: motivoCtrl,
              decoration: InputDecoration(
                hintText: 'Ej: Error en el pedido',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Volver',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Cancelar pedido',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && motivoCtrl.text.trim().isNotEmpty) {
      try {
        await SalesService.cambiarEstado(
          pedido.id,
          'cancelado',
          motivoCancelacion: motivoCtrl.text.trim(),
        );
        widget.provider.reload();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final filtered = provider.filtrar(query: _searchQuery);

    final columns = [
      AppTableColumn(
        label: 'Pedido',
        key: '_ref',
        flex: 2,
        cellBuilder: (value, row) {
          final p = value as PedidoRead;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                p.numeroPedido,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827)),
              ),
              Text(
                _labelsTipo[p.tipoPedido] ?? p.tipoPedido,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          );
        },
      ),
      AppTableColumn(
        label: 'Cliente',
        key: '_ref',
        flex: 2,
        cellBuilder: (value, row) {
          final p = value as PedidoRead;
          return Text(
            p.nombreCliente ?? '—',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF374151)),
          );
        },
      ),
      AppTableColumn(
        label: 'Estado',
        key: 'estado',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) =>
            Center(child: _estadoBadge(value as String)),
      ),
      AppTableColumn(
        label: 'Pago',
        key: 'estadoPago',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) =>
            Center(child: _pagoBadge(value as String)),
      ),
      AppTableColumn(
        label: 'Total',
        key: 'total',
        flex: 2,
        align: TextAlign.right,
        cellBuilder: (value, row) => Text(
          '₡${_formatMoney(value as double)}',
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827)),
        ),
      ),
      AppTableColumn(
        label: 'Fecha',
        key: 'fechaPedido',
        flex: 2,
        cellBuilder: (value, row) => Text(
          value != null ? _formatDateTime(value as DateTime) : '—',
          style: const TextStyle(
              fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ),
      AppTableColumn(
        label: 'Acciones',
        key: '_ref',
        flex: 3,
        align: TextAlign.center,
        cellBuilder: (value, row) {
          final pedido = value as PedidoRead;
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _ActionBtn(
                icon: Icons.visibility_outlined,
                label: 'Ver',
                onTap: () => _showDetalleModal(pedido),
              ),
              // Transiciones de estado disponibles — admin puede gestionar
              for (final estado in pedido.transicionesPermitidas)
                if (estado != 'cancelado')
                  _ActionBtn(
                    icon: _iconEstado(estado),
                    label: _labelsEstado[estado] ?? estado,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                    onTap: () => _cambiarEstado(pedido, estado),
                  ),
              if (pedido.transicionesPermitidas.contains('cancelado'))
                _ActionBtn(
                  icon: Icons.cancel_outlined,
                  label: 'Cancelar',
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEE2E2),
                  onTap: () => _cambiarEstado(pedido, 'cancelado'),
                ),
            ],
          );
        },
      ),
    ];

    final rows = filtered.map((p) => p.toTableRow()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: provider.reload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — solo monitoreo, sin acciones operativas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ventas',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${provider.total} pedidos · '
                        '${provider.totalActivos} activos · '
                        'Facturado: ₡${_formatMoney(provider.totalVentasHoy)}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: provider.reload,
                    icon: const Icon(Icons.refresh_outlined,
                        color: Color(0xFF6B7280)),
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SearchFilterBar(
                controller: _searchCtrl,
                placeholder: 'Buscar por número o cliente...',
                filterOptions: _estados,
                selectedFilter: provider.estadoFilter,
                onFilterChanged: provider.setEstadoFilter,
              ),
              const SizedBox(height: 16),

              AppDataTable(
                columns: columns,
                rows: rows,
                emptyMessage: 'No se encontraron pedidos',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoBadge(String estado) {
    final colors = const {
      'borrador': (Color(0xFF6B7280), Color(0xFFF3F4F6)),
      'abierto': (Color(0xFF2563EB), Color(0xFFEFF6FF)),
      'en_preparacion': (Color(0xFFD97706), Color(0xFFFFFBEB)),
      'listo': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
      'en_entrega': (Color(0xFF7C3AED), Color(0xFFF5F3FF)),
      'entregado': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
      'facturado': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
      'cancelado': (Color(0xFFDC2626), Color(0xFFFEE2E2)),
    };
    final c = colors[estado] ??
        (const Color(0xFF6B7280), const Color(0xFFF3F4F6));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.$2, borderRadius: BorderRadius.circular(12)),
      child: Text(
        _labelsEstado[estado] ?? estado,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: c.$1),
      ),
    );
  }

  Widget _pagoBadge(String estado) {
    final colors = const {
      'pendiente': (Color(0xFFD97706), Color(0xFFFFFBEB)),
      'pagado': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
      'pago_parcial': (Color(0xFF2563EB), Color(0xFFEFF6FF)),
      'credito': (Color(0xFF7C3AED), Color(0xFFF5F3FF)),
    };
    final c = colors[estado] ??
        (const Color(0xFF6B7280), const Color(0xFFF3F4F6));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.$2, borderRadius: BorderRadius.circular(12)),
      child: Text(
        _labelsEstadoPago[estado] ?? estado,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: c.$1),
      ),
    );
  }

  IconData _iconEstado(String estado) => const {
        'abierto': Icons.lock_open_outlined,
        'en_preparacion': Icons.restaurant_outlined,
        'listo': Icons.check_circle_outline,
        'en_entrega': Icons.delivery_dining_outlined,
        'entregado': Icons.done_all_outlined,
        'facturado': Icons.receipt_long_outlined,
      }[estado] ??
      Icons.arrow_forward_outlined;

  String _formatMoney(double v) => v
      .toStringAsFixed(2)
      .replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Botón de acción ────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color bgColor;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF374151),
    this.bgColor = const Color(0xFFF3F4F6),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}