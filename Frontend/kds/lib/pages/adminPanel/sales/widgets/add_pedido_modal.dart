import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../common/providers/auth_provider.dart';
import '../../../../../common/models/producto_models.dart';
import '../../../../../common/services/api_service.dart';
import '../sales_provider.dart';

class AddPedidoModal extends StatefulWidget {
  final String sesionCajaId;
  final VoidCallback onSuccess;

  const AddPedidoModal({
    super.key,
    required this.sesionCajaId,
    required this.onSuccess,
  });

  @override
  State<AddPedidoModal> createState() => _AddPedidoModalState();
}

class _AddPedidoModalState extends State<AddPedidoModal> {
  bool _isLoading = false;
  bool _loadingProductos = true;
  String? _error;

  // Cabecera del pedido
  final _numeroPedidoCtrl  = TextEditingController();
  final _nombreClienteCtrl = TextEditingController();
  final _telefonoCtrl      = TextEditingController();
  final _notasCtrl         = TextEditingController();
  String _tipoPedido  = 'mostrador';
  String _canalVenta  = 'presencial';
  String _prioridad   = 'normal';

  // Catálogo
  List<ProductoSucursalRead> _productos = [];
  List<CategoriaRead> _categorias = [];
  String _categoriaFilter = 'Todas';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // Carrito
  final List<_ItemCarrito> _carrito = [];

  static const _tiposPedido = ['mesa', 'para_llevar', 'domicilio', 'mostrador'];
  static const _labelsTipo  = {
    'mesa': 'Mesa', 'para_llevar': 'Para llevar',
    'domicilio': 'Domicilio', 'mostrador': 'Mostrador',
  };
  static const _prioridades = ['baja', 'normal', 'alta', 'urgente'];

  @override
  void initState() {
    super.initState();
    _numeroPedidoCtrl.text =
        'PED-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()));
    _loadCatalogo();
  }

  @override
  void dispose() {
    _numeroPedidoCtrl.dispose();
    _nombreClienteCtrl.dispose();
    _telefonoCtrl.dispose();
    _notasCtrl.dispose();
    _searchCtrl.dispose();
    for (final i in _carrito) { i.dispose(); }
    super.dispose();
  }

  Future<void> _loadCatalogo() async {
    final auth = context.read<AuthProvider>();
    final sucursalId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.id
        : auth.sucursalId;
    final empresaId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.empresaId ?? auth.empresaId
        : auth.empresaId;

    if (sucursalId == null || empresaId == null) {
      setState(() => _loadingProductos = false);
      return;
    }

    try {
      final results = await Future.wait([
        ApiService.get(
            '/api/v1/productos/sucursal/$sucursalId?items_per_page=200&disponible_venta=true'),
        ApiService.get(
            '/api/v1/categorias/?empresa_id=$empresaId&items_per_page=100&estado=activo'),
      ]);

      if (!mounted) return;
      setState(() {
        _productos = PaginatedProductosSucursal.fromJson(results[0]).items;
        final catList =
            (results[1]['data'] ?? results[1]['items']) as List<dynamic>;
        _categorias = catList
            .map((i) => CategoriaRead.fromJson(i as Map<String, dynamic>))
            .toList();
        _loadingProductos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProductos = false);
    }
  }

  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  List<ProductoSucursalRead> get _productosFiltrados {
    return _productos.where((p) {
      final matchCat = _categoriaFilter == 'Todas';
      final matchSearch = _searchQuery.isEmpty ||
          (p.nombre?.toLowerCase().contains(_searchQuery) ?? false) ||
          (p.codigoInterno?.toLowerCase().contains(_searchQuery) ?? false);
      return matchCat && matchSearch && p.disponibleVenta;
    }).toList();
  }

  void _agregarAlCarrito(ProductoSucursalRead producto) {
    // Si ya existe en el carrito, incrementar cantidad
    final existente = _carrito.where((i) => i.producto.id == producto.id);
    if (existente.isNotEmpty) {
      setState(() {
        final item = existente.first;
        final current = double.tryParse(item.cantidadCtrl.text) ?? 1;
        item.cantidadCtrl.text = (current + 1).toString();
      });
      return;
    }
    setState(() => _carrito.add(_ItemCarrito(producto: producto)));
  }

  void _removeDelCarrito(int index) {
    setState(() {
      _carrito[index].dispose();
      _carrito.removeAt(index);
    });
  }

  double get _subtotal =>
      _carrito.fold(0, (s, i) => s + i.subtotal);
  double get _totalIva =>
      _carrito.fold(0, (s, i) => s + i.montoIva);
  double get _totalServicio =>
      _carrito.fold(0, (s, i) => s + i.montoServicio);
  double get _total => _subtotal + _totalIva + _totalServicio;

  Future<void> _crearPedido() async {
    if (_numeroPedidoCtrl.text.trim().isEmpty)
      return setState(() => _error = 'El número de pedido es requerido');
    if (_carrito.isEmpty)
      return setState(() => _error = 'Agrega al menos un producto al pedido');

    final auth = context.read<AuthProvider>();
    final sucursalId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.id
        : auth.sucursalId;
    final empresaId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.empresaId ?? auth.empresaId
        : auth.empresaId;

    if (sucursalId == null || empresaId == null)
      return setState(() => _error = 'No se pudo determinar la sucursal');

    setState(() { _isLoading = true; _error = null; });

    try {
      await SalesService.createPedido({
        'empresa_id': empresaId,
        'sucursal_id': sucursalId,
        'numero_pedido': _numeroPedidoCtrl.text.trim(),
        'tipo_pedido': _tipoPedido,
        'canal_venta': _canalVenta,
        'prioridad': _prioridad,
        if (_nombreClienteCtrl.text.trim().isNotEmpty)
          'nombre_cliente': _nombreClienteCtrl.text.trim(),
        if (_telefonoCtrl.text.trim().isNotEmpty)
          'telefono_cliente': _telefonoCtrl.text.trim(),
        'items': _carrito.map((i) => i.toJson()).toList(),
      });
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al crear el pedido'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sw > 900 ? 860 : sw - 48,
          maxHeight: sh * 0.94,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Expanded(
                    child: Text('Nuevo Pedido',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : _close,
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFFDC2626))),
                      ),
                    ],
                  ),
                ),

              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Panel izquierdo: catálogo ──────────────────────────
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabecera del pedido
                          _sectionLabel('Datos del pedido'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  label: 'Número *',
                                  ctrl: _numeroPedidoCtrl,
                                  hint: 'PED-001',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _label('Tipo'),
                                    const SizedBox(height: 6),
                                    _dropdown(
                                      child: DropdownButton<String>(
                                        key: const ValueKey('dd_tipo'),
                                        value: _tipoPedido,
                                        isExpanded: true,
                                        underline: const SizedBox.shrink(),
                                        items: _tiposPedido
                                            .map((t) => DropdownMenuItem(
                                                  value: t,
                                                  child: Text(
                                                      _labelsTipo[t] ?? t,
                                                      style: const TextStyle(
                                                          fontSize: 12)),
                                                ))
                                            .toList(),
                                        onChanged: (v) => setState(
                                            () => _tipoPedido =
                                                v ?? 'mostrador'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _label('Prioridad'),
                                    const SizedBox(height: 6),
                                    _dropdown(
                                      child: DropdownButton<String>(
                                        key: const ValueKey('dd_prior'),
                                        value: _prioridad,
                                        isExpanded: true,
                                        underline: const SizedBox.shrink(),
                                        items: _prioridades
                                            .map((p) => DropdownMenuItem(
                                                  value: p,
                                                  child: Text(
                                                      p[0].toUpperCase() +
                                                          p.substring(1),
                                                      style: const TextStyle(
                                                          fontSize: 12)),
                                                ))
                                            .toList(),
                                        onChanged: (v) => setState(
                                            () =>
                                                _prioridad = v ?? 'normal'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _Field(
                                  label: 'Cliente',
                                  ctrl: _nombreClienteCtrl,
                                  hint: 'Nombre opcional',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Field(
                                  label: 'Teléfono',
                                  ctrl: _telefonoCtrl,
                                  hint: 'Opcional',
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFFE5E7EB)),
                          const SizedBox(height: 12),

                          // Catálogo de productos
                          _sectionLabel('Catálogo'),
                          const SizedBox(height: 10),

                          TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Buscar producto...',
                              hintStyle: const TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 13),
                              prefixIcon: const Icon(Icons.search,
                                  size: 18, color: Color(0xFF9CA3AF)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD1D5DB))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD1D5DB))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2563EB), width: 2)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (_loadingProductos)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(
                                    color: Color(0xFF2563EB)),
                              ),
                            )
                          else
                            Expanded(
                              child: GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 2.2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: _productosFiltrados.length,
                                itemBuilder: (_, i) {
                                  final p = _productosFiltrados[i];
                                  return _ProductoCard(
                                    producto: p,
                                    onTap: () => _agregarAlCarrito(p),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),
                    const VerticalDivider(color: Color(0xFFE5E7EB)),
                    const SizedBox(width: 16),

                    // ── Panel derecho: carrito ──────────────────────────────
                    SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(
                              'Carrito (${_carrito.length})'),
                          const SizedBox(height: 10),

                          if (_carrito.isEmpty)
                            const Expanded(
                              child: Center(
                                child: Text(
                                  'Selecciona productos del catálogo',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF9CA3AF)),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.separated(
                                itemCount: _carrito.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(
                                        color: Color(0xFFE5E7EB),
                                        height: 8),
                                itemBuilder: (_, i) => _CarritoItem(
                                  item: _carrito[i],
                                  onRemove: () => _removeDelCarrito(i),
                                  onChanged: () => setState(() {}),
                                ),
                              ),
                            ),

                          // Totales
                          if (_carrito.isNotEmpty) ...[
                            const Divider(color: Color(0xFFE5E7EB)),
                            _TotalRow('Subtotal', _subtotal),
                            _TotalRow('IVA', _totalIva),
                            _TotalRow('Servicio', _totalServicio),
                            const Divider(color: Color(0xFFE5E7EB)),
                            _TotalRow('Total', _total, bold: true, large: true),
                            const SizedBox(height: 16),
                          ],

                          // Botones
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _close,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Cancelar',
                                      style:
                                          TextStyle(fontSize: 13)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _crearPedido,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Text('Crear pedido',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151)));

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF374151)));

  Widget _dropdown({required Widget child}) => Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );
}

// ── Tarjeta de producto en el catálogo ────────────────────────────────────────
class _ProductoCard extends StatelessWidget {
  final ProductoSucursalRead producto;
  final VoidCallback onTap;

  const _ProductoCard({required this.producto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.fastfood_outlined,
                  size: 18, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    producto.nombre ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827)),
                  ),
                  Text(
                    '₡${producto.precioVenta.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline,
                size: 18, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }
}

// ── Ítem en el carrito ────────────────────────────────────────────────────────
class _ItemCarrito {
  final ProductoSucursalRead producto;
  final TextEditingController cantidadCtrl;

  _ItemCarrito({required this.producto})
      : cantidadCtrl = TextEditingController(text: '1');

  double get cantidad => double.tryParse(cantidadCtrl.text) ?? 1;
  double get subtotal => producto.precioVenta * cantidad;
  double get montoIva =>
      producto.aplicaIva ? subtotal * (producto.porcentajeIva / 100) : 0;
  double get montoServicio =>
      producto.aplicaServicio
          ? subtotal * (producto.porcentajeServicio / 100)
          : 0;
  double get total => subtotal + montoIva + montoServicio;

  Map<String, dynamic> toJson() => {
        'producto_id': producto.productoId,
        'cantidad': cantidad,
        'unidad_medida': producto.unidadMedida ?? 'unidad',
        'precio_unitario': producto.precioVenta,
        'descuento_porcentaje': 0,
        'descuento_monto': 0,
        'subtotal': subtotal,
        'iva': montoIva,
        'servicio': montoServicio,
        'total': total,
        if (producto.precioCosto != null)
          'costo_unitario': producto.precioCosto,
      };

  void dispose() => cantidadCtrl.dispose();
}

class _CarritoItem extends StatelessWidget {
  final _ItemCarrito item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _CarritoItem({
    required this.item,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.producto.nombre ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827)),
              ),
              Text(
                '₡${item.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Control de cantidad
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                final current = double.tryParse(item.cantidadCtrl.text) ?? 1;
                if (current <= 1) {
                  onRemove();
                } else {
                  item.cantidadCtrl.text = (current - 1).toString();
                  onChanged();
                }
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.remove, size: 14,
                    color: Color(0xFF374151)),
              ),
            ),
            SizedBox(
              width: 32,
              child: TextField(
                controller: item.cantidadCtrl,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => onChanged(),
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF111827)),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                final current = double.tryParse(item.cantidadCtrl.text) ?? 1;
                item.cantidadCtrl.text = (current + 1).toString();
                onChanged();
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.add, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final bool large;

  const _TotalRow(this.label, this.value,
      {this.bold = false, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: large ? 14 : 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: const Color(0xFF374151))),
          Text(
            '₡${value.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: large ? 14 : 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: const Color(0xFF111827)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF2563EB), width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}