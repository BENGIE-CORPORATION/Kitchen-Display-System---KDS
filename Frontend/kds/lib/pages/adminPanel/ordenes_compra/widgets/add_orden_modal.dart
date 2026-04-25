import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../common/providers/auth_provider.dart';
import '../../../../../common/models/proveedor_models.dart';
import '../../../../../common/models/materia_prima_models.dart';
import '../../../../../common/services/api_service.dart';
import '../ordenes_compra_provider.dart';

class AddOrdenModal extends StatefulWidget {
  final VoidCallback onSuccess;
  const AddOrdenModal({super.key, required this.onSuccess});

  @override
  State<AddOrdenModal> createState() => _AddOrdenModalState();
}

class _AddOrdenModalState extends State<AddOrdenModal> {
  bool _isLoading = false;
  bool _loadingDatos = true;
  String? _error;

  final _numeroOrdenCtrl = TextEditingController();
  final _notasCtrl       = TextEditingController();
  String _condicionPago  = 'contado';
  DateTime? _fechaEntregaEsperada;
  ProveedorRead? _proveedorSeleccionado;

  List<ProveedorRead> _proveedores = [];
  List<MateriaPrimaSucursalRead> _materiasPrimas = [];
  final List<_ItemOrden> _items = [];

  static const _condPago = [
    'contado', 'credito_15', 'credito_30', 'credito_60', 'credito_90'
  ];
  static const _labelsPago = {
    'contado': 'Contado',
    'credito_15': 'Crédito 15d',
    'credito_30': 'Crédito 30d',
    'credito_60': 'Crédito 60d',
    'credito_90': 'Crédito 90d',
  };
  static const _unidades = [
    'kg', 'g', 'l', 'ml', 'unidades', 'm', 'm2', 'm3'
  ];

  @override
  void initState() {
    super.initState();
    _loadDatos();
  }

  @override
  void dispose() {
    _numeroOrdenCtrl.dispose();
    _notasCtrl.dispose();
    for (final i in _items) { i.dispose(); }
    super.dispose();
  }

  Future<void> _loadDatos() async {
    final auth = context.read<AuthProvider>();
    final empresaId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.empresaId ?? auth.empresaId
        : auth.empresaId;
    final sucursalId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.id
        : auth.sucursalId;

    if (empresaId == null || sucursalId == null) {
      setState(() => _loadingDatos = false);
      return;
    }

    try {
      // Carga proveedores y materias primas en paralelo
      final results = await Future.wait([
        ApiService.get(
            '/api/v1/proveedores/?empresa_id=$empresaId&items_per_page=100&estado=activo'),
        ApiService.get(
            '/api/v1/materias-primas/sucursal/$sucursalId?items_per_page=100'),
      ]);

      if (!mounted) return;
      setState(() {
        _proveedores =
            PaginatedProveedores.fromJson(results[0]).items;
        _materiasPrimas =
            PaginatedMateriaPrimas.fromJson(results[1]).items;
        _loadingDatos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDatos = false);
    }
  }

  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  void _addItem() => setState(() => _items.add(_ItemOrden()));
  void _removeItem(int i) => setState(() {
        _items[i].dispose();
        _items.removeAt(i);
      });

  double get _total => _items.fold(0, (s, i) => s + i.subtotal);

  Future<void> _guardar() async {
    if (_numeroOrdenCtrl.text.trim().isEmpty)
      return setState(() => _error = 'El número de orden es requerido');
    if (_proveedorSeleccionado == null)
      return setState(() => _error = 'Selecciona un proveedor');
    if (_items.isEmpty)
      return setState(() => _error = 'Agrega al menos un ítem');
    for (final item in _items) {
      if (item.materiaPrima == null)
        return setState(
            () => _error = 'Selecciona una materia prima en todos los ítems');
      if (item.cantidad <= 0)
        return setState(() => _error = 'La cantidad debe ser mayor a 0');
      if (item.precio < 0)
        return setState(() => _error = 'El precio no puede ser negativo');
    }

    final auth = context.read<AuthProvider>();
    final sucursalId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.id
        : auth.sucursalId;
    final empresaId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.empresaId ?? auth.empresaId
        : auth.empresaId;

    if (sucursalId == null || empresaId == null)
      return setState(
          () => _error = 'No se pudo determinar sucursal o empresa');

    setState(() { _isLoading = true; _error = null; });

    try {
      await OrdenesCompraService.createOrden({
        'empresa_id': empresaId,
        'sucursal_id': sucursalId,
        'proveedor_id': _proveedorSeleccionado!.id,
        'numero_orden': _numeroOrdenCtrl.text.trim(),
        'condicion_pago': _condicionPago,
        if (_notasCtrl.text.trim().isNotEmpty)
          'notas': _notasCtrl.text.trim(),
        if (_fechaEntregaEsperada != null)
          'fecha_entrega_esperada':
              _fechaEntregaEsperada!.toIso8601String(),
        'items': _items.map((i) => i.toJson()).toList(),
      });
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al crear la orden'; _isLoading = false; });
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
          maxWidth: sw > 700 ? 660 : sw - 48,
          maxHeight: sh * 0.92,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Nueva Orden de Compra',
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
              const SizedBox(height: 20),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
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

              _loadingDatos
                  ? const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF2563EB)),
                      ),
                    )
                  : Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Datos de la orden'),
                            const SizedBox(height: 12),

                            // Proveedor
                            _label('Proveedor *'),
                            const SizedBox(height: 6),
                            _dropdown(
                              child: DropdownButton<ProveedorRead>(
                                key: const ValueKey('dd_proveedor'),
                                value: _proveedorSeleccionado,
                                isExpanded: true,
                                underline: const SizedBox.shrink(),
                                hint: const Text('Selecciona un proveedor',
                                    style: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 13)),
                                items: _proveedores
                                    .map((p) => DropdownMenuItem(
                                          value: p,
                                          child: Text(p.nombreLegal,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(
                                    () => _proveedorSeleccionado = v),
                              ),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _Field(
                                    label: 'Número de orden *',
                                    ctrl: _numeroOrdenCtrl,
                                    hint: 'Ej: OC-2024-001',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _label('Condición de pago'),
                                      const SizedBox(height: 6),
                                      _dropdown(
                                        child: DropdownButton<String>(
                                          key: const ValueKey('dd_cond'),
                                          value: _condicionPago,
                                          isExpanded: true,
                                          underline:
                                              const SizedBox.shrink(),
                                          items: _condPago
                                              .map((c) => DropdownMenuItem(
                                                    value: c,
                                                    child: Text(
                                                        _labelsPago[c] ??
                                                            c,
                                                        style: const TextStyle(
                                                            fontSize: 13)),
                                                  ))
                                              .toList(),
                                          onChanged: (v) => setState(() =>
                                              _condicionPago =
                                                  v ?? 'contado'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            _label('Fecha de entrega esperada'),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final fecha = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now()
                                      .add(const Duration(days: 7)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (fecha != null) {
                                  setState(
                                      () => _fechaEntregaEsperada = fecha);
                                }
                              },
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFD1D5DB)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 16,
                                        color: Color(0xFF6B7280)),
                                    const SizedBox(width: 8),
                                    Text(
                                      _fechaEntregaEsperada != null
                                          ? '${_fechaEntregaEsperada!.day}/${_fechaEntregaEsperada!.month}/${_fechaEntregaEsperada!.year}'
                                          : 'Seleccionar fecha (opcional)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _fechaEntregaEsperada != null
                                            ? const Color(0xFF111827)
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            _Field(
                              label: 'Notas',
                              ctrl: _notasCtrl,
                              hint: 'Observaciones opcionales',
                              maxLines: 2,
                            ),

                            const SizedBox(height: 20),
                            const Divider(color: Color(0xFFE5E7EB)),
                            const SizedBox(height: 16),

                            // ── Ítems ──────────────────────────────────────
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                _sectionLabel(
                                    'Ítems (${_items.length})'),
                                TextButton.icon(
                                  onPressed: _addItem,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Agregar ítem'),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (_items.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFE5E7EB)),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Agrega al menos un ítem a la orden',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF9CA3AF)),
                                  ),
                                ),
                              )
                            else
                              for (int i = 0; i < _items.length; i++) ...[
                                _ItemOrdenWidget(
                                  item: _items[i],
                                  index: i,
                                  materiasPrimas: _materiasPrimas,
                                  unidades: _unidades,
                                  onRemove: () => _removeItem(i),
                                  onChanged: () => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                              ],

                            if (_items.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Text(
                                    'Total: ₡${_total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _close,
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text('Crear orden',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );
}

// ── Modelo local de ítem ───────────────────────────────────────────────────────
class _ItemOrden {
  MateriaPrimaSucursalRead? materiaPrima;
  final cantidadCtrl = TextEditingController(text: '1');
  final precioCtrl   = TextEditingController(text: '0');
  String unidad      = 'kg';

  double get cantidad => double.tryParse(cantidadCtrl.text) ?? 0;
  double get precio   => double.tryParse(precioCtrl.text) ?? 0;
  double get subtotal => cantidad * precio;

  // El backend requiere materia_prima_id o producto_id — nunca ambos null.
  // Aquí siempre usamos materia_prima_id derivado de la selección del usuario.
  Map<String, dynamic> toJson() => {
        'materia_prima_id': materiaPrima!.materiaPrimaId,
        'cantidad_solicitada': cantidad,
        'unidad_medida': unidad,
        'precio_unitario': precio,
        'descuento_porcentaje': 0,
        'descuento_monto': 0,
        'impuesto_porcentaje': 0,
        'impuesto_monto': 0,
        'subtotal': subtotal,
        'total': subtotal,
      };

  void dispose() {
    cantidadCtrl.dispose();
    precioCtrl.dispose();
  }
}

// ── Widget de un ítem ─────────────────────────────────────────────────────────
class _ItemOrdenWidget extends StatefulWidget {
  final _ItemOrden item;
  final int index;
  final List<MateriaPrimaSucursalRead> materiasPrimas;
  final List<String> unidades;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemOrdenWidget({
    required this.item,
    required this.index,
    required this.materiasPrimas,
    required this.unidades,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_ItemOrdenWidget> createState() => _ItemOrdenWidgetState();
}

class _ItemOrdenWidgetState extends State<_ItemOrdenWidget> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del ítem
          Row(
            children: [
              Text('Ítem ${widget.index + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const Spacer(),
              GestureDetector(
                onTap: widget.onRemove,
                child: const Icon(Icons.close,
                    size: 16, color: Color(0xFFDC2626)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Selector de materia prima
          const Text('Materia prima *',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151))),
          const SizedBox(height: 6),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<MateriaPrimaSucursalRead>(
              key: ValueKey('dd_mp_${widget.index}'),
              value: item.materiaPrima,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: const Text('Selecciona una materia prima',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 13)),
              items: widget.materiasPrimas
                  .map((mp) => DropdownMenuItem(
                        value: mp,
                        child: Text(
                          '${mp.nombre ?? '—'} (${mp.stockActual} ${mp.unidadMedida ?? ''})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                item.materiaPrima = v;
                // Auto-completar unidad desde la materia prima
                if (v?.unidadMedida != null) {
                  item.unidad = v!.unidadMedida!;
                }
                // Auto-completar precio promedio si existe
                if (v != null && v.costoPromedio > 0) {
                  item.precioCtrl.text =
                      v.costoPromedio.toStringAsFixed(2);
                }
                widget.onChanged();
              }),
            ),
          ),
          const SizedBox(height: 8),

          // Cantidad, unidad y precio
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'Cantidad',
                  ctrl: item.cantidadCtrl,
                  hint: '1',
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: widget.onChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unidad',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    Container(
                      height: 42,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        key: ValueKey('dd_unidad_${widget.index}'),
                        value: widget.unidades.contains(item.unidad)
                            ? item.unidad
                            : widget.unidades.first,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: widget.unidades
                            .map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u,
                                      style: const TextStyle(
                                          fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          item.unidad = v ?? 'kg';
                          widget.onChanged();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  label: 'Precio unit.',
                  ctrl: item.precioCtrl,
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  onChanged: widget.onChanged,
                ),
              ),
            ],
          ),

          // Subtotal del ítem
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Subtotal: ₡${item.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151)),
            ),
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
  final VoidCallback? onChanged;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
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
          onChanged: onChanged != null ? (_) => onChanged!() : null,
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
                borderSide:
                    const BorderSide(color: Color(0xFF2563EB), width: 2)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}