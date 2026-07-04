import 'package:flutter/material.dart';
import '../../../common/models/materia_prima_models.dart';
import '../../../common/widgets/app_data_table.dart';
import '../../../common/widgets/search_filter_bar.dart';
import '../../../common/widgets/status_badge.dart';
import 'inventory_provider.dart';
import 'widgets/add_inventory_modal.dart';
import 'widgets/edit_inventory_modal.dart';

/// Pantalla de Inventario — Materias Primas por Sucursal.
class InventoryPage extends StatefulWidget {
  final InventoryProvider provider;
  final String sucursalId;

  const InventoryPage({
    super.key,
    required this.provider,
    required this.sucursalId,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'Todas';
  bool _soloBajoMinimo = false;

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

  void _showEditDialog(MateriaPrimaSucursalRead item) {
    showDialog(
      context: context,
      builder: (_) => EditInventoryModal(
        item: item,
        onSuccess: () => widget.provider.load(widget.sucursalId, refresh: true),
      ),
    );
}

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final filtered = provider.filtrar(
      query: _searchQuery,
      categoria: _categoryFilter,
      soloBajoMinimo: _soloBajoMinimo,
    );

    final columns = [
      AppTableColumn(
        label: 'Producto',
        key: '_ref',
        flex: 3,
        cellBuilder: (value, row) {
          final item = value as MateriaPrimaSucursalRead;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.nombre ?? '—',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827))),
              if (item.codigo != null)
                Text(item.codigo!,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          );
        },
      ),
      const AppTableColumn(label: 'Categoría', key: 'categoria', flex: 2),
      AppTableColumn(
        label: 'Stock Actual',
        key: '_ref',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) {
          final item = value as MateriaPrimaSucursalRead;
          return Text(
            '${item.stockActual} ${item.unidadMedida ?? ''}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: item.isBajoMinimo
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF111827),
            ),
          );
        },
      ),
      AppTableColumn(
        label: 'Stock Mínimo',
        key: '_ref',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) {
          final item = value as MateriaPrimaSucursalRead;
          return Text(
            '${item.stockMinimo} ${item.unidadMedida ?? ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF6B7280)),
          );
        },
      ),
      AppTableColumn(
        label: 'Costo Prom.',
        key: 'costoPromedio',
        flex: 2,
        align: TextAlign.right,
        cellBuilder: (value, row) => Text(
          '₡${(value as double).toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827)),
        ),
      ),
      AppTableColumn(
        label: 'Estado',
        key: 'estado',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) => Center(
          child: value == 'low'
              ? StatusBadge.low()
              : StatusBadge.available(),
        ),
      ),
      AppTableColumn(
        label: 'Acciones',
        key: '_ref',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) {
          final item = value as MateriaPrimaSucursalRead;
          return Center(
            child: GestureDetector(
              onTap: () => _showEditDialog(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
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

    final rows = filtered.map((item) => item.toTableRow()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: () => provider.load(widget.sucursalId, refresh: true),
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
                      const Text('Inventario',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text(
                        '${provider.total} materias primas'
                        '${provider.totalBajoMinimo > 0 ? ' · ${provider.totalBajoMinimo} bajo mínimo' : ''}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Botón agregar
                      GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AddInventoryModal(
                            onSuccess: () => provider.load(
                                widget.sucursalId,
                                refresh: true),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add,
                                  size: 15, color: Colors.white),
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
                      const SizedBox(width: 12),
                      // Toggle bajo mínimo
                      GestureDetector(
                        onTap: () => setState(
                            () => _soloBajoMinimo = !_soloBajoMinimo),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _soloBajoMinimo
                                ? const Color(0xFFFEE2E2)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _soloBajoMinimo
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFD1D5DB),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_outlined,
                                  size: 15,
                                  color: _soloBajoMinimo
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF6B7280)),
                              const SizedBox(width: 6),
                              Text(
                                'Bajo mínimo',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _soloBajoMinimo
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Búsqueda + categorías dinámicas desde el BE
              SearchFilterBar(
                controller: _searchCtrl,
                placeholder: 'Buscar por nombre, código o categoría...',
                filterOptions: provider.categorias,
                selectedFilter: _categoryFilter,
                onFilterChanged: (v) =>
                    setState(() => _categoryFilter = v),
              ),
              const SizedBox(height: 16),

              // Tabla
              AppDataTable(
                columns: columns,
                rows: rows,
                emptyMessage: _soloBajoMinimo
                    ? '¡Todo el stock está sobre el mínimo!'
                    : 'No se encontraron materias primas',
              ),
            ],
          ),
        ),
      ),
    );
  }
}