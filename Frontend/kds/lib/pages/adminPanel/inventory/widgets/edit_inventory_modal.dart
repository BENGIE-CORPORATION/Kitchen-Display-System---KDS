import 'package:flutter/material.dart';
import '../../../../../common/models/materia_prima_models.dart';
import '../../../../../common/services/api_service.dart';

class EditInventoryModal extends StatefulWidget {
  final MateriaPrimaSucursalRead item;
  final VoidCallback onSuccess;

  const EditInventoryModal({
    super.key,
    required this.item,
    required this.onSuccess,
  });

  @override
  State<EditInventoryModal> createState() => _EditInventoryModalState();
}

class _EditInventoryModalState extends State<EditInventoryModal> {
  bool _isLoading = false;
  String? _error;

  // Campos de materia prima — PATCH /materias-primas/{id}
  late final _nombreCtrl;
  late final _codigoCtrl;
  late final _categoriaCtrl;
  late final _descripcionCtrl;

  // Campos de stock — PATCH /materias-primas/sucursales/{mps_id}
  late final _stockActualCtrl;
  late final _stockMinCtrl;
  late final _costoCtrl;

  late String _unidad;

  static const _unidades = ['kg', 'g', 'l', 'ml', 'unidades', 'm', 'm2', 'm3'];

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _nombreCtrl     = TextEditingController(text: i.nombre ?? '');
    _codigoCtrl     = TextEditingController(text: i.codigo ?? '');
    _categoriaCtrl  = TextEditingController(text: i.categoria ?? '');
    _descripcionCtrl = TextEditingController(text: i.descripcion ?? '');
    _stockActualCtrl = TextEditingController(text: i.stockActual.toStringAsFixed(3));
    _stockMinCtrl    = TextEditingController(text: i.stockMinimo.toStringAsFixed(3));
    _costoCtrl       = TextEditingController(text: i.costoPromedio.toStringAsFixed(2));
    _unidad          = i.unidadMedida ?? 'kg';
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl, _codigoCtrl, _categoriaCtrl, _descripcionCtrl,
      _stockActualCtrl, _stockMinCtrl, _costoCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // Cierre seguro — siempre con guard de mounted
  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  Future<void> _guardar() async {

      // TEMP: logs de diagnóstico
    print('[Edit] materiaPrimaId: ${widget.item.materiaPrimaId}');
    print('[Edit] mps id: ${widget.item.id}');
    print('[Edit] nombre ctrl: ${_nombreCtrl.text.trim()}');
    print('[Edit] categoria ctrl: ${_categoriaCtrl.text.trim()}');

    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() => _error = 'El nombre es requerido');
      return;
    }

    final nuevoStock = double.tryParse(_stockActualCtrl.text);
    if (nuevoStock == null || nuevoStock < 0) {
      setState(() => _error = 'El stock actual debe ser un número mayor o igual a 0');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      // PATCH datos de la materia prima
      // Asunción: item.materiaPrimaId contiene el UUID de la materia prima.
      // Si el campo se llama distinto en tu modelo, ajusta aquí.
      await ApiService.patch(
        '/api/v1/materias-primas/${widget.item.materiaPrimaId}',
        {
          'nombre': _nombreCtrl.text.trim(),
          'unidad_medida': _unidad,
          if (_codigoCtrl.text.trim().isNotEmpty)
            'codigo': _codigoCtrl.text.trim(),
          if (_categoriaCtrl.text.trim().isNotEmpty)
            'categoria': _categoriaCtrl.text.trim(),
          if (_descripcionCtrl.text.trim().isNotEmpty)
            'descripcion': _descripcionCtrl.text.trim(),
        },
      );

      // PATCH stock en sucursal
      // item.id es el ID de la relación materias_primas_sucursales
      await ApiService.patch(
        '/api/v1/materias-primas/sucursales/${widget.item.id}',
        {
          'stock_actual': nuevoStock,
          'stock_minimo': double.tryParse(_stockMinCtrl.text) ?? 0,
          'costo_promedio': double.tryParse(_costoCtrl.text) ?? 0,
        },
      );

      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al guardar los cambios'; _isLoading = false; });
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
          maxWidth: sw > 568 ? 520 : sw - 48,
          maxHeight: sh * 0.90,
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
                    child: Text(
                      'Editar Materia Prima',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : _close,
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Error
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

              // Contenido con scroll
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Sección: datos del producto ──────────────────────
                      _sectionLabel('Datos del producto'),
                      const SizedBox(height: 12),

                      _Field(label: 'Nombre *', ctrl: _nombreCtrl, hint: 'Ej: Tomate'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Código',
                              ctrl: _codigoCtrl,
                              hint: 'Ej: TOM-001',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Unidad de medida'),
                                const SizedBox(height: 6),
                                _dropdown(
                                  child: DropdownButton<String>(
                                    key: const ValueKey('dd_unidad_edit'),
                                    value: _unidad,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    items: _unidades
                                        .map((u) => DropdownMenuItem(
                                              value: u,
                                              child: Text(u,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _unidad = v ?? 'kg'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _Field(
                          label: 'Categoría',
                          ctrl: _categoriaCtrl,
                          hint: 'Ej: Verduras'),
                      const SizedBox(height: 12),
                      _Field(
                          label: 'Descripción',
                          ctrl: _descripcionCtrl,
                          hint: 'Opcional',
                          maxLines: 2),

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 16),

                      // ── Sección: stock ───────────────────────────────────
                      _sectionLabel('Stock en sucursal'),
                      const SizedBox(height: 12),

                      _Field(
                        label: 'Stock actual',
                        sublabel: 'Cantidad en existencia ($_unidad)',
                        ctrl: _stockActualCtrl,
                        hint: '0',
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Stock mínimo',
                              sublabel: 'Alerta bajo este nivel',
                              ctrl: _stockMinCtrl,
                              hint: '0',
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              label: 'Costo promedio',
                              sublabel: 'Por $_unidad',
                              ctrl: _costoCtrl,
                              hint: '0.00',
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _close,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar cambios',
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

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
          letterSpacing: 0.3,
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151)),
      );

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

// ── Campo de texto reutilizable ────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final String? sublabel;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.sublabel,
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
        if (sublabel != null) ...[
          const SizedBox(height: 2),
          Text(sublabel!,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ],
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
                borderSide:
                    const BorderSide(color: Color(0xFF2563EB), width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}