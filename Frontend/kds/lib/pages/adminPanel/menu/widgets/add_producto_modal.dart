import 'package:flutter/material.dart';
import '../../../../common/models/producto_models.dart';
import '../../../../common/services/api_service.dart';
import '../menu_provider.dart';
import 'menu_field.dart';

class AddProductoModal extends StatefulWidget {
  final String empresaId;
  final List<CategoriaRead> categorias;
  final VoidCallback onSuccess;

  const AddProductoModal({
    super.key,
    required this.empresaId,
    required this.categorias,
    required this.onSuccess,
  });

  @override
  State<AddProductoModal> createState() => _AddProductoModalState();
}

class _AddProductoModalState extends State<AddProductoModal> {
  bool _isLoading = false;
  String? _error;

  final _nombreCtrl       = TextEditingController();
  final _codigoCtrl       = TextEditingController();
  final _descripcionCtrl  = TextEditingController();
  final _descripcionCorta = TextEditingController();
  final _marcaCtrl        = TextEditingController();

  String? _categoriaId;
  String _tipoProducto = 'simple';
  String _unidadMedida = 'unidad';
  bool _esVendible         = true;
  bool _esComprable        = true;
  bool _requiereInventario = true;
  bool _permiteDecimal     = false;

  static const _tipos = ['simple', 'compuesto', 'servicio', 'combo'];
  static const _unidades = [
    'unidad', 'kg', 'g', 'l', 'ml', 'm', 'pack'
  ];
  static const _labelsTipo = {
    'simple': 'Simple',
    'compuesto': 'Compuesto',
    'servicio': 'Servicio',
    'combo': 'Combo',
  };

  @override
  void initState() {
    super.initState();
    if (widget.categorias.isNotEmpty) {
      _categoriaId = widget.categorias.first.id;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _descripcionCtrl.dispose();
    _descripcionCorta.dispose();
    _marcaCtrl.dispose();
    super.dispose();
  }

  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty)
      return setState(() => _error = 'El nombre es requerido');
    if (_categoriaId == null)
      return setState(() => _error = 'Selecciona una categoría');

    setState(() { _isLoading = true; _error = null; });

    try {
      await MenuService.createProducto({
        'empresa_id': widget.empresaId,
        'nombre': _nombreCtrl.text.trim(),
        'categoria_id': _categoriaId,
        'tipo_producto': _tipoProducto,
        'unidad_medida': _unidadMedida,
        'es_vendible': _esVendible,
        'es_comprable': _esComprable,
        'requiere_inventario': _requiereInventario,
        'permite_decimal': _permiteDecimal,
        if (_codigoCtrl.text.trim().isNotEmpty)
          'codigo_interno': _codigoCtrl.text.trim(),
        if (_descripcionCorta.text.trim().isNotEmpty)
          'descripcion_corta': _descripcionCorta.text.trim(),
        if (_descripcionCtrl.text.trim().isNotEmpty)
          'descripcion': _descripcionCtrl.text.trim(),
        if (_marcaCtrl.text.trim().isNotEmpty)
          'marca': _marcaCtrl.text.trim(),
      });
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al crear el producto';
        _isLoading = false;
      });
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
          maxWidth: sw > 600 ? 560 : sw - 48,
          maxHeight: sh * 0.90,
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
                    child: Text('Nuevo Producto',
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

              if (_error != null) ErrorBanner(message: _error!),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sección identificación
                      _sectionLabel('Identificación'),
                      const SizedBox(height: 12),

                      MenuField(
                          label: 'Nombre *',
                          ctrl: _nombreCtrl,
                          hint: 'Ej: Hamburguesa Clásica'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: MenuField(
                                label: 'Código interno',
                                ctrl: _codigoCtrl,
                                hint: 'Ej: HAM-001'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MenuField(
                                label: 'Marca',
                                ctrl: _marcaCtrl,
                                hint: 'Opcional'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Categoría y tipo
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                menuLabel('Categoría *'),
                                const SizedBox(height: 6),
                                menuDropdown(
                                  child: DropdownButton<String>(
                                    key: const ValueKey('dd_cat'),
                                    value: _categoriaId,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    hint: const Text('Selecciona',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF9CA3AF))),
                                    items: widget.categorias
                                        .map((c) => DropdownMenuItem(
                                              value: c.id,
                                              child: Text(c.nombre,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _categoriaId = v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                menuLabel('Tipo *'),
                                const SizedBox(height: 6),
                                menuDropdown(
                                  child: DropdownButton<String>(
                                    key: const ValueKey('dd_tipo'),
                                    value: _tipoProducto,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    items: _tipos
                                        .map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(
                                                  _labelsTipo[t] ?? t,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() =>
                                        _tipoProducto = v ?? 'simple'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          menuLabel('Unidad de medida *'),
                          const SizedBox(height: 6),
                          menuDropdown(
                            child: DropdownButton<String>(
                              key: const ValueKey('dd_unidad'),
                              value: _unidadMedida,
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
                              onChanged: (v) => setState(
                                  () => _unidadMedida = v ?? 'unidad'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      MenuField(
                        label: 'Descripción corta',
                        ctrl: _descripcionCorta,
                        hint: 'Ej: Carne de res, queso, lechuga...',
                        sublabel: 'Se muestra en el menú del cliente',
                      ),
                      const SizedBox(height: 12),
                      MenuField(
                        label: 'Descripción completa',
                        ctrl: _descripcionCtrl,
                        hint: 'Opcional',
                        maxLines: 3,
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 16),

                      _sectionLabel('Configuración'),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          MenuSwitch(
                            label: 'Es vendible',
                            value: _esVendible,
                            onChanged: (v) =>
                                setState(() => _esVendible = v),
                          ),
                          MenuSwitch(
                            label: 'Es comprable',
                            value: _esComprable,
                            onChanged: (v) =>
                                setState(() => _esComprable = v),
                          ),
                          MenuSwitch(
                            label: 'Requiere inventario',
                            value: _requiereInventario,
                            onChanged: (v) =>
                                setState(() => _requiereInventario = v),
                          ),
                          MenuSwitch(
                            label: 'Permite decimal',
                            value: _permiteDecimal,
                            onChanged: (v) =>
                                setState(() => _permiteDecimal = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ModalActions(
                isLoading: _isLoading,
                onCancel: _close,
                onSave: _guardar,
                saveLabel: 'Crear producto',
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
}