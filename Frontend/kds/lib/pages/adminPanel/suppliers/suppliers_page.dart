import 'package:flutter/material.dart';
import '../../../common/models/proveedor_models.dart';
import '../../../common/widgets/app_data_table.dart';
import '../../../common/widgets/search_filter_bar.dart';
import '../../../common/widgets/status_badge.dart';
import 'suppliers_provider.dart';
import 'widgets/add_supplier_modal.dart';
import 'widgets/edit_supplier_modal.dart';
import '../../../common/services/api_service.dart';

class SuppliersPage extends StatefulWidget {
  final SuppliersProvider provider;

  const SuppliersPage({super.key, required this.provider});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _tipoFilter = 'Todos';
  String _pagoFilter = 'Todas';

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
      builder: (_) => AddSupplierModal(
        onSuccess: widget.provider.reload,
      ),
    );
  }

  void _showEditModal(ProveedorRead item) {
    showDialog(
      context: context,
      builder: (_) => EditSupplierModal(
        item: item,
        onSuccess: widget.provider.reload,
      ),
    );
  }

  Future<void> _confirmDelete(ProveedorRead item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Desactivar proveedor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Deseas desactivar a "${item.nombreLegal}"? '
          'Podrás reactivarlo posteriormente.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Desactivar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SuppliersService.deleteProveedor(item.id);
        widget.provider.reload();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final filtered = provider.filtrar(
      query: _searchQuery,
      tipoProveedor: _tipoFilter,
      condicionPago: _pagoFilter,
    );

    final columns = [
      AppTableColumn(
        label: 'Proveedor',
        key: '_ref',
        flex: 3,
        cellBuilder: (value, row) {
          final item = value as ProveedorRead;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.nombreLegal,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827),
                ),
              ),
              if (item.nombreComercial != null)
                Text(
                  item.nombreComercial!,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
            ],
          );
        },
      ),
      const AppTableColumn(
          label: 'Identificación', key: 'identificacion', flex: 2),
      AppTableColumn(
        label: 'Tipo',
        key: 'tipoProveedor',
        flex: 2,
        cellBuilder: (value, row) => Text(
          _labelTipo(value as String),
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
      ),
      AppTableColumn(
        label: 'Condición pago',
        key: 'condicionPago',
        flex: 2,
        cellBuilder: (value, row) => Text(
          _labelPago(value as String),
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
      ),
      const AppTableColumn(label: 'Teléfono', key: 'telefono', flex: 2),
      const AppTableColumn(label: 'Ciudad', key: 'ciudad', flex: 2),
      AppTableColumn(
        label: 'Estado',
        key: 'estado',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) => Center(
          child: _estadoBadge(value as String),
        ),
      ),
      AppTableColumn(
        label: 'Acciones',
        key: '_ref',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) {
          final item = value as ProveedorRead;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(
                icon: Icons.edit_outlined,
                label: 'Editar',
                onTap: () => _showEditModal(item),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.block_outlined,
                label: 'Desactivar',
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEE2E2),
                onTap: () => _confirmDelete(item),
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Proveedores',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${provider.total} proveedores registrados',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280)),
                      ),
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
                          Text(
                            'Agregar Proveedor',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SearchFilterBar(
                controller: _searchCtrl,
                placeholder:
                    'Buscar por nombre, identificación o email...',
                filterOptions: provider.tiposProveedor,
                selectedFilter: _tipoFilter,
                onFilterChanged: (v) =>
                    setState(() => _tipoFilter = v),
              ),
              const SizedBox(height: 16),

              AppDataTable(
                columns: columns,
                rows: rows,
                emptyMessage: 'No se encontraron proveedores',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _labelTipo(String tipo) => const {
        'productos': 'Productos',
        'servicios': 'Servicios',
        'materias_primas': 'Materias Primas',
        'mixto': 'Mixto',
      }[tipo] ??
      tipo;

  String _labelPago(String pago) => const {
        'contado': 'Contado',
        'credito_15': 'Crédito 15d',
        'credito_30': 'Crédito 30d',
        'credito_60': 'Crédito 60d',
        'credito_90': 'Crédito 90d',
      }[pago] ??
      pago;

  Widget _estadoBadge(String estado) => switch (estado) {
        'activo' => StatusBadge.available(),
        'bloqueado' => StatusBadge.low(),
        _ => StatusBadge.low(),
      };
}

// ── Botón de acción reutilizable en la tabla ───────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color bgColor;

  const _ActionButton({
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
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}