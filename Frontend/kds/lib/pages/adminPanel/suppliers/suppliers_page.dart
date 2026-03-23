import 'package:flutter/material.dart';
import '../../../common/models/models.dart';
import '../../../common/widgets/app_data_table.dart';
import '../../../common/widgets/kpi_card.dart';
import '../../../common/widgets/search_filter_bar.dart';
import '../../../common/widgets/status_badge.dart';

/// Pantalla de Gestión de Proveedores.
/// [suppliers] y [kpis] vienen del backend.
class ProvidersPage extends StatefulWidget {
  final List<Supplier> suppliers;
  final ValueChanged<Supplier>? onViewSupplier;
  final VoidCallback? onCreateOrder;
  final VoidCallback? onNewSupplier;

  const ProvidersPage({
    super.key,
    required this.suppliers,
    this.onViewSupplier,
    this.onCreateOrder,
    this.onNewSupplier,
  });

  @override
  State<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<ProvidersPage> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  String _categoryFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Supplier> get _filtered {
    return widget.suppliers.where((s) {
      final q = _searchQuery;
      final matchSearch = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.legalId.contains(q) ||
          s.email.toLowerCase().contains(q);
      final matchStatus = _statusFilter == 'all' ||
          (_statusFilter == 'active' && s.status == SupplierStatus.active) ||
          (_statusFilter == 'inactive' && s.status == SupplierStatus.inactive);
      final matchCat =
          _categoryFilter == 'all' || s.category == _categoryFilter;
      return matchSearch && matchStatus && matchCat;
    }).toList();
  }

  List<String> get _categories {
    final cats = widget.suppliers.map((s) => s.category).toSet().toList();
    return ['all', ...cats];
  }

  // KPIs calculados desde los datos del backend
  int get _activeCount =>
      widget.suppliers.where((s) => s.status == SupplierStatus.active).length;

  double get _totalMonthly => widget.suppliers
      .where((s) => s.status == SupplierStatus.active)
      .fold(0, (sum, s) => sum + s.monthlyTotal);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    final columns = [
      const AppTableColumn(label: 'Proveedor', key: 'name', flex: 3),
      const AppTableColumn(label: 'Cédula Jurídica', key: 'legalId', flex: 2),
      const AppTableColumn(label: 'Contacto', key: '_ref', flex: 2),
      const AppTableColumn(label: 'Categoría', key: 'category', flex: 2),
      AppTableColumn(
        label: 'Estado',
        key: 'status',
        flex: 1,
        align: TextAlign.center,
        cellBuilder: (value, row) => Center(
          child: value == 'active'
              ? StatusBadge.active()
              : StatusBadge.inactive(),
        ),
      ),
      AppTableColumn(
        label: 'Última Compra',
        key: 'lastPurchase',
        flex: 2,
        cellBuilder: (value, row) {
          final ref = row['_ref'] as Supplier;
          return Text(
            '${ref.lastPurchase.day.toString().padLeft(2, '0')} '
            '${_monthName(ref.lastPurchase.month)} '
            '${ref.lastPurchase.year}',
            style:
                const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          );
        },
      ),
      AppTableColumn(
        label: 'Total Mes',
        key: 'monthlyTotal',
        flex: 2,
        align: TextAlign.right,
        cellBuilder: (value, row) => Text(
          '₡${(value as double).toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827)),
        ),
      ),
      AppTableColumn(
        label: 'Acciones',
        key: '_ref',
        flex: 1,
        align: TextAlign.center,
        cellBuilder: (value, row) {
          final sup = value as Supplier;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined,
                    size: 16, color: Color(0xFF2563EB)),
                onPressed: () => widget.onViewSupplier?.call(sup),
                tooltip: 'Ver detalles',
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 16, color: Color(0xFF6B7280)),
                onPressed: () {},
                tooltip: 'Editar',
              ),
            ],
          );
        },
      ),
    ];

    final rows = filtered.map((s) => {
          'name': s.name,
          'legalId': s.legalId,
          '_ref': s,
          'category': s.category,
          'status': s.status.name,
          'lastPurchase': s.lastPurchase,
          'monthlyTotal': s.monthlyTotal,
        }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
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
                  children: const [
                    Text('Gestión de Proveedores',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                    SizedBox(height: 2),
                    Text('Control y seguimiento de proveedores',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
                Row(
                  children: [
                    _ActionBtn(
                      label: 'Nueva Orden de Compra',
                      icon: Icons.shopping_cart_outlined,
                      color: const Color(0xFF2563EB),
                      onTap: widget.onCreateOrder ?? () {},
                    ),
                    const SizedBox(width: 12),
                    _ActionBtn(
                      label: 'Nuevo Proveedor',
                      icon: Icons.add,
                      color: const Color(0xFF111827),
                      onTap: widget.onNewSupplier ?? () {},
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // KPI Cards dinámicas
            Row(
              children: [
                Expanded(
                  child: KpiCard(
                    icon: Icons.trending_up,
                    iconBgColor: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF16A34A),
                    title: 'Total Comprado (Mes)',
                    value:
                        '₡${(_totalMonthly / 1000000).toStringAsFixed(1)}M',
                    subtitle: 'Mes actual',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: KpiCard(
                    icon: Icons.people_outline,
                    iconBgColor: const Color(0xFFDBEAFE),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Proveedores Activos',
                    value: '$_activeCount',
                    subtitle: '${widget.suppliers.length} registrados',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: KpiCard(
                    icon: Icons.shopping_cart_outlined,
                    iconBgColor: const Color(0xFFF3E8FF),
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Órdenes Pendientes',
                    value: '—', // viene del backend
                    subtitle: 'Por recibir',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: KpiCard(
                    icon: Icons.warning_amber_outlined,
                    iconBgColor: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFD97706),
                    title: 'Monto Pendiente',
                    value: '—', // viene del backend
                    subtitle: 'Por pagar',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Búsqueda
            SearchFilterBar(
              controller: _searchCtrl,
              placeholder: 'Buscar por nombre, cédula jurídica o correo...',
            ),
            const SizedBox(height: 8),

            // Filtros de estado y categoría
            Row(
              children: [
                _DropdownFilter(
                  value: _statusFilter,
                  items: const {
                    'all': 'Todos los estados',
                    'active': 'Activos',
                    'inactive': 'Inactivos',
                  },
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
                const SizedBox(width: 12),
                _DropdownFilter(
                  value: _categoryFilter,
                  items: {
                    for (final c in _categories)
                      c: c == 'all' ? 'Todas las categorías' : c
                  },
                  onChanged: (v) => setState(() => _categoryFilter = v),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tabla
            AppDataTable(
              columns: columns,
              rows: rows,
              headerColor: const Color(0xFFF9FAFB),
              emptyMessage: 'No se encontraron proveedores',
            ),
            const SizedBox(height: 8),

            // Conteo
            Text(
              'Mostrando ${filtered.length} de ${widget.suppliers.length} proveedores',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return names[month];
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _DropdownFilter(
      {required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}