import 'package:flutter/material.dart';
import '../../../common/models/models.dart';
import '../../../common/widgets/app_data_table.dart';
import '../../../common/widgets/search_filter_bar.dart';
import '../../../common/widgets/status_badge.dart';

/// Pantalla de Inventario.
/// [items] viene del backend; el grid de categorías es dinámico.
class InventoryPage extends StatefulWidget {
  final List<InventoryItem> items;
  final VoidCallback? onAddProduct;
  final ValueChanged<InventoryItem>? onAdjust;

  const InventoryPage({
    super.key,
    required this.items,
    this.onAddProduct,
    this.onAdjust,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'Todas';

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

  /// Categorías únicas extraídas dinámicamente de los items del backend
  List<String> get _categories {
    final cats = widget.items.map((i) => i.category).toSet().toList()..sort();
    return ['Todas', ...cats];
  }

  List<InventoryItem> get _filtered {
    return widget.items.where((item) {
      final matchSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery) ||
          item.category.toLowerCase().contains(_searchQuery);
      final matchCat =
          _categoryFilter == 'Todas' || item.category == _categoryFilter;
      return matchSearch && matchCat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    final columns = [
      AppTableColumn(
        label: 'Producto',
        key: 'name',
        flex: 3,
        cellBuilder: (value, row) {
          final item = row['_ref'] as InventoryItem;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.name,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827))),
              Text(item.unit,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          );
        },
      ),
      const AppTableColumn(label: 'Categoría', key: 'category', flex: 2),
      AppTableColumn(
        label: 'Stock Actual',
        key: 'currentStock',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) {
          final item = row['_ref'] as InventoryItem;
          return Text(
            '${item.currentStock}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: item.status == StockStatus.low
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF111827),
            ),
          );
        },
      ),
      AppTableColumn(
        label: 'Stock Mínimo',
        key: 'minStock',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) => Text(
          '${(value as double).toInt()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
      ),
      AppTableColumn(
        label: 'Costo/Unidad',
        key: 'unitCost',
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
        label: 'Estado',
        key: 'status',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) => Center(
          child: value == 'low' ? StatusBadge.low() : StatusBadge.available(),
        ),
      ),
      AppTableColumn(
        label: 'Acciones',
        key: '_ref',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) {
          final item = value as InventoryItem;
          return Center(
            child: GestureDetector(
              onTap: () => widget.onAdjust?.call(item),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 13, color: Color(0xFF374151)),
                    SizedBox(width: 4),
                    Text('Ajustar',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF374151))),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];

    final rows = filtered
        .map((item) => {
              'name': item.name,
              'category': item.category,
              'currentStock': item.currentStock,
              'minStock': item.minStock,
              'unitCost': item.unitCost,
              'status': item.status.name,
              '_ref': item,
            })
        .toList();

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
                    Text('Inventario',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                    SizedBox(height: 2),
                    Text('Gestión de stock y productos',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
                GestureDetector(
                  onTap: widget.onAddProduct,
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
                        Text('Agregar Producto',
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

            // Search + category pills (dinámicas desde backend)
            SearchFilterBar(
              controller: _searchCtrl,
              placeholder: 'Buscar productos...',
              filterOptions: _categories,
              selectedFilter: _categoryFilter,
              onFilterChanged: (v) => setState(() => _categoryFilter = v),
            ),
            const SizedBox(height: 16),

            // Tabla
            AppDataTable(
              columns: columns,
              rows: rows,
              emptyMessage: 'No se encontraron productos',
            ),
          ],
        ),
      ),
    );
  }
}