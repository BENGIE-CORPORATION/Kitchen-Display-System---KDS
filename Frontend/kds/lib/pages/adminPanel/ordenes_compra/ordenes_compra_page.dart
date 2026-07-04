import 'package:flutter/material.dart';
import '../../../common/models/orden_compra_models.dart';
import '../../../common/services/api_service.dart';
import '../../../common/widgets/app_data_table.dart';
import '../../../common/widgets/search_filter_bar.dart';
import '../../../common/widgets/status_badge.dart';
import 'ordenes_compra_provider.dart';
import 'widgets/add_orden_modal.dart';
import 'widgets/orden_detalle_modal.dart';

class OrdenesCompraPage extends StatefulWidget {
  final OrdenesCompraProvider provider;

  const OrdenesCompraPage({super.key, required this.provider});

  @override
  State<OrdenesCompraPage> createState() => _OrdenesCompraPageState();
}

class _OrdenesCompraPageState extends State<OrdenesCompraPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const _estados = [
    'Todos', 'borrador', 'enviada', 'confirmada', 'parcial', 'recibida', 'cancelada'
  ];

  static const _labelsEstado = {
    'borrador': 'Borrador',
    'enviada': 'Enviada',
    'confirmada': 'Confirmada',
    'parcial': 'Parcial',
    'recibida': 'Recibida',
    'cancelada': 'Cancelada',
  };

  static const _labelesPago = {
    'contado': 'Contado',
    'credito_15': 'Crédito 15d',
    'credito_30': 'Crédito 30d',
    'credito_60': 'Crédito 60d',
    'credito_90': 'Crédito 90d',
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

  void _showAddModal() {
    showDialog(
      context: context,
      builder: (_) => AddOrdenModal(onSuccess: widget.provider.reload),
    );
  }

  void _showDetalleModal(OrdenCompraRead orden) {
    showDialog(
      context: context,
      builder: (_) => OrdenDetalleModal(
        orden: orden,
        onSuccess: widget.provider.reload,
      ),
    );
  }

  Future<void> _cambiarEstado(OrdenCompraRead orden, String nuevoEstado) async {
    // Si pasa a recibida necesita fecha de entrega real
    String? fechaEntregaReal;
    if (nuevoEstado == 'recibida') {
      fechaEntregaReal = DateTime.now().toIso8601String();
    }

    try {
      await OrdenesCompraService.cambiarEstado(
        orden.id,
        nuevoEstado,
        fechaEntregaReal: fechaEntregaReal,
      );
      widget.provider.reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmarCancelacion(OrdenCompraRead orden) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cancelar orden',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Cancelar la orden "${orden.numeroOrden}"? Esta acción es irreversible.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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
            child: const Text('Cancelar orden',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await OrdenesCompraService.cancelarOrden(orden.id);
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
        label: 'Número',
        key: '_ref',
        flex: 2,
        cellBuilder: (value, row) {
          final o = value as OrdenCompraRead;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(o.numeroOrden,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              if (o.fechaOrden != null)
                Text(
                  _formatDate(o.fechaOrden!),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
            ],
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
        label: 'Cond. Pago',
        key: 'condicionPago',
        flex: 2,
        cellBuilder: (value, row) => Text(
          _labelesPago[value] ?? (value as String),
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
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
        label: 'Entrega esperada',
        key: 'fechaEntregaEsperada',
        flex: 2,
        cellBuilder: (value, row) => Text(
          value != null ? _formatDate(value as DateTime) : '—',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
      ),
      AppTableColumn(
        label: 'Acciones',
        key: '_ref',
        flex: 3,
        align: TextAlign.center,
        cellBuilder: (value, row) {
          final orden = value as OrdenCompraRead;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ver detalle siempre disponible
              _ActionBtn(
                icon: Icons.visibility_outlined,
                label: 'Ver',
                onTap: () => _showDetalleModal(orden),
              ),

              // Transiciones de estado disponibles
              for (final estado in orden.transicionesPermitidas)
                if (estado != 'cancelada') ...[
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: _iconEstado(estado),
                    label: _labelsEstado[estado] ?? estado,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                    onTap: () => _cambiarEstado(orden, estado),
                  ),
                ],

              // Cancelar siempre al final si aplica
              if (orden.transicionesPermitidas.contains('cancelada')) ...[
                const SizedBox(width: 6),
                _ActionBtn(
                  icon: Icons.cancel_outlined,
                  label: 'Cancelar',
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEE2E2),
                  onTap: () => _confirmarCancelacion(orden),
                ),
              ],
            ],
          );
        },
      ),
    ];

    final rows = filtered.map((o) => o.toTableRow()).toList();

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Órdenes de Compra',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text('${provider.total} órdenes',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showAddModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 15, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Nueva Orden',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SearchFilterBar(
                controller: _searchCtrl,
                placeholder: 'Buscar por número de orden...',
                filterOptions: _estados,
                selectedFilter: provider.estadoFilter == 'Todos'
                    ? 'Todos'
                    : provider.estadoFilter,
                onFilterChanged: (v) => provider.setEstadoFilter(v),
              ),
              const SizedBox(height: 16),

              AppDataTable(
                columns: columns,
                rows: rows,
                emptyMessage: 'No se encontraron órdenes de compra',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _formatMoney(double v) => v
      .toStringAsFixed(2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  IconData _iconEstado(String estado) => const {
        'enviada': Icons.send_outlined,
        'confirmada': Icons.check_circle_outline,
        'parcial': Icons.incomplete_circle_outlined,
        'recibida': Icons.inventory_2_outlined,
      }[estado] ??
      Icons.arrow_forward_outlined;

  Widget _estadoBadge(String estado) {
    final colors = const {
      'borrador': (Color(0xFF6B7280), Color(0xFFF3F4F6)),
      'enviada': (Color(0xFF2563EB), Color(0xFFEFF6FF)),
      'confirmada': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
      'parcial': (Color(0xFFD97706), Color(0xFFFFFBEB)),
      'recibida': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
      'cancelada': (Color(0xFFDC2626), Color(0xFFFEE2E2)),
    }[estado] ??
        (const Color(0xFF6B7280), const Color(0xFFF3F4F6));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _labelsEstado[estado] ?? estado,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.$1),
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

const _labelsEstado = {
  'borrador': 'Borrador',
  'enviada': 'Enviada',
  'confirmada': 'Confirmada',
  'parcial': 'Parcial',
  'recibida': 'Recibida',
  'cancelada': 'Cancelada',
};