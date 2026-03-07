import 'package:flutter/material.dart';
import '../../../common/models/models.dart';
import '../../../common/widgets/app_data_table.dart';
import 'widgets/sales_search_bar.dart';
import 'widgets/sale_quantity_cell.dart';
import 'widgets/sale_footer.dart';

/// Pantalla de Punto de Venta.
/// Los [initialItems] y [products] vienen del backend/controlador.
class SalesPage extends StatefulWidget {
  final List<SaleItem> initialItems;
  final List<Product> products;

  const SalesPage({
    super.key,
    this.initialItems = const [],
    this.products = const [],
  });

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late List<SaleItem> _items;
  final TextEditingController _searchCtrl = TextEditingController();
  String _cliente = '';
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredProducts = q.isEmpty
          ? []
          : widget.products
              .where((p) =>
                  p.nombre.toLowerCase().contains(q) ||
                  p.clave.contains(q))
              .toList();
    });
  }

  void _addProduct(Product product) {
    setState(() {
      final idx = _items.indexWhere((i) => i.clave == product.clave);
      if (idx >= 0) {
        _items[idx].cantidad++;
      } else {
        _items.add(SaleItem(
          id: UniqueKey().toString(),
          clave: product.clave,
          nombre: product.nombre,
          cantidad: 1,
          precio: product.precio,
        ));
      }
      _filteredProducts = [];
      _searchCtrl.clear();
    });
  }

  void _changeQty(String id, int delta) {
    setState(() {
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx >= 0) {
        final newQty = _items[idx].cantidad + delta;
        if (newQty < 1) return;
        _items[idx].cantidad = newQty;
      }
    });
  }

  void _removeItem(String id) {
    setState(() => _items.removeWhere((i) => i.id == id));
  }

  void _clearSale() {
    setState(() {
      _items.clear();
      _cliente = '';
      _searchCtrl.clear();
    });
  }

  double get _total =>
      _items.fold(0, (sum, i) => sum + i.total);

  int get _totalItems =>
      _items.fold(0, (sum, i) => sum + i.cantidad);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Construir rows para AppDataTable
    final rows = _items
        .map((item) => {
              'clave': item.clave,
              'nombre': item.nombre,
              'cantidad': item,    // objeto completo para el widget de cantidad
              'precio': item.precio,
              'total': item.total,
              '_id': item.id,
            })
        .toList();

    final columns = [
      const AppTableColumn(label: 'Clave', key: 'clave', flex: 1),
      const AppTableColumn(label: 'Nombre', key: 'nombre', flex: 3),
      AppTableColumn(
        label: 'Cantidad',
        key: 'cantidad',
        flex: 2,
        align: TextAlign.center,
        cellBuilder: (value, row) {
          final item = value as SaleItem;
          return SaleQuantityCell(
            cantidad: item.cantidad,
            onDecrement: () => _changeQty(item.id, -1),
            onIncrement: () => _changeQty(item.id, 1),
          );
        },
      ),
      AppTableColumn(
        label: 'Precio',
        key: 'precio',
        flex: 2,
        align: TextAlign.right,
        cellBuilder: (value, row) => Text(
          '₡${(value as double).toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
        ),
      ),
      AppTableColumn(
        label: 'Total',
        key: 'total',
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
        key: '_id',
        flex: 1,
        align: TextAlign.center,
        cellBuilder: (value, row) => IconButton(
          icon: const Icon(Icons.delete_outline,
              color: Color(0xFFDC2626), size: 18),
          onPressed: () => _removeItem(value as String),
        ),
      ),
    ];

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
                const Text(
                  'Punto de Venta',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total Productos',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    Text(
                      '$_totalItems',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Búsqueda de productos
            SalesSearchBar(
              controller: _searchCtrl,
              filteredProducts: _filteredProducts,
              onProductSelected: _addProduct,
            ),
            const SizedBox(height: 16),

            // Tabla de items
            AppDataTable(
              columns: columns,
              rows: rows,
              emptyMessage: 'No hay productos en la venta actual',
            ),
            const SizedBox(height: 16),

            // Footer (cliente + cobrar)
            SaleFooter(
              cliente: _cliente,
              total: _total,
              hasItems: _items.isNotEmpty,
              onClienteChanged: (v) => setState(() => _cliente = v),
              onCancelar: _clearSale,
              onCobrar: _items.isNotEmpty
                  ? () {
                      // TODO: integrar con backend
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}