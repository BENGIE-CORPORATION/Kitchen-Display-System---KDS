import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../common/providers/auth_provider.dart';
import '../../../../../common/models/sucursal_models.dart';
import '../../../../../common/services/api_service.dart';

class AddInventoryModal extends StatefulWidget {
  final VoidCallback onSuccess;
  const AddInventoryModal({super.key, required this.onSuccess});

  @override
  State<AddInventoryModal> createState() => _AddInventoryModalState();
}

class _AddInventoryModalState extends State<AddInventoryModal> {
  int _step = 1;
  bool _isLoading = false;
  String? _error;

  final _nombreCtrl      = TextEditingController();
  final _codigoCtrl      = TextEditingController();
  final _categoriaCtrl   = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _diasVidaCtrl    = TextEditingController();
  final _cantidadCtrl    = TextEditingController(text: '0');
  final _stockMinCtrl    = TextEditingController(text: '0');
  final _costoCtrl       = TextEditingController(text: '0');

  String _unidad       = 'kg';
  bool _perecedero     = false;
  SucursalRead? _sucursal;
  String? _mpId;

  static const _unidades = ['kg', 'g', 'l', 'ml', 'unidades', 'm', 'm2', 'm3'];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isSuperAdmin) _sucursal = auth.sucursalSeleccionada;
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl, _codigoCtrl, _categoriaCtrl, _descripcionCtrl,
      _diasVidaCtrl, _cantidadCtrl, _stockMinCtrl, _costoCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  String? _empresaId(AuthProvider auth) =>
      auth.isSuperAdmin ? _sucursal?.empresaId : auth.empresaId;

  Future<void> _paso1() async {
    final auth = context.read<AuthProvider>();

    if (_nombreCtrl.text.trim().isEmpty)
      return setState(() => _error = 'El nombre es requerido');
    if (auth.isSuperAdmin && _sucursal == null)
      return setState(() => _error = 'Selecciona una sucursal');
    if (_perecedero && _diasVidaCtrl.text.trim().isEmpty)
      return setState(() => _error = 'Ingresa los días de vida útil');

    final empresaId = _empresaId(auth);
    if (empresaId == null)
      return setState(() => _error = 'No se pudo determinar la empresa');

    setState(() { _isLoading = true; _error = null; });

    try {
      final res = await ApiService.post('/api/v1/materias-primas/', {
        'nombre': _nombreCtrl.text.trim(),
        'empresa_id': empresaId,
        'unidad_medida': _unidad,
        'perecedero': _perecedero,
        if (_codigoCtrl.text.trim().isNotEmpty)    'codigo': _codigoCtrl.text.trim(),
        if (_categoriaCtrl.text.trim().isNotEmpty)  'categoria': _categoriaCtrl.text.trim(),
        if (_descripcionCtrl.text.trim().isNotEmpty) 'descripcion': _descripcionCtrl.text.trim(),
        if (_perecedero && _diasVidaCtrl.text.isNotEmpty)
          'dias_vida_util': int.tryParse(_diasVidaCtrl.text),
      });
      if (!mounted) return;
      _mpId = res['id'] as String?;
      setState(() { _step = 2; _isLoading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al crear la materia prima'; _isLoading = false; });
    }
  }

  Future<void> _paso2() async {
    final auth = context.read<AuthProvider>();
    final sucursalId = auth.isSuperAdmin ? _sucursal?.id : auth.sucursalId;

    if (sucursalId == null)
      return setState(() => _error = 'No se encontró la sucursal');
    if (_mpId == null)
      return setState(() => _error = 'Error interno: materia prima no registrada');

    final cantidad = double.tryParse(_cantidadCtrl.text) ?? 0;
    if (cantidad < 0)
      return setState(() => _error = 'La cantidad no puede ser negativa');

    setState(() { _isLoading = true; _error = null; });

    try {
      await ApiService.post('/api/v1/materias-primas/$_mpId/sucursales', {
        'materia_prima_id': _mpId,
        'sucursal_id': sucursalId,
        'stock_actual': cantidad,
        'stock_minimo': double.tryParse(_stockMinCtrl.text) ?? 0,
        'costo_promedio': double.tryParse(_costoCtrl.text) ?? 0,
      });
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al asignar la sucursal'; _isLoading = false; });
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _step == 1 ? 'Nueva Materia Prima' : 'Stock Inicial',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold,
                              color: Color(0xFF111827)),
                        ),
                        Text('Paso $_step de 2',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress
              LinearProgressIndicator(
                value: _step / 2,
                backgroundColor: const Color(0xFFE5E7EB),
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 20),

              // Error
              if (_error != null) ...[
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
              ],

              // Contenido del paso con scroll
              Flexible(
                child: SingleChildScrollView(
                  child: _step == 1 ? _buildStep1() : _buildStep2(),
                ),
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  if (_step == 2) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() { _step = 1; _error = null; }),
                        child: const Text('Atrás'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isLoading ? null : (_step == 1 ? _paso1 : _paso2),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _step == 1 ? 'Siguiente' : 'Guardar',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
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

  Widget _buildStep1() {
    final auth = context.watch<AuthProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sucursal — solo super_admin, en paso 1 para derivar empresa_id
        if (auth.isSuperAdmin) ...[
          _label('Sucursal *'),
          const SizedBox(height: 6),
          _dropdown(
            child: DropdownButton<SucursalRead>(
              key: const ValueKey('dd_sucursal'),
              value: _sucursal,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: const Text('Selecciona una sucursal',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
              items: auth.todasLasSucursales
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.nombre,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _sucursal = v),
            ),
          ),
          const SizedBox(height: 12),
        ],

        _Field(label: 'Nombre *', ctrl: _nombreCtrl, hint: 'Ej: Tomate', keyboardType: TextInputType.text),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _Field(label: 'Código', ctrl: _codigoCtrl, hint: 'Ej: TOM-001', keyboardType: TextInputType.text),
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
                      key: const ValueKey('dd_unidad'),
                      value: _unidad,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: _unidades
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u,
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _unidad = v ?? 'kg'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _Field(label: 'Categoría', ctrl: _categoriaCtrl, hint: 'Ej: Verduras', keyboardType: TextInputType.text),
        const SizedBox(height: 12),
        _Field(label: 'Descripción', ctrl: _descripcionCtrl,
            hint: 'Opcional', maxLines: 2, keyboardType: TextInputType.text),
        const SizedBox(height: 12),

        Row(
          children: [
            Switch(
              value: _perecedero,
              onChanged: (v) => setState(() {
                _perecedero = v;
                if (!v) _diasVidaCtrl.clear();
              }),
              activeColor: const Color(0xFF2563EB),
            ),
            const SizedBox(width: 8),
            const Text('Perecedero',
                style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
          ],
        ),
        if (_perecedero) ...[
          const SizedBox(height: 8),
          _Field(label: 'Días de vida útil', ctrl: _diasVidaCtrl,
              hint: 'Ej: 7', keyboardType: TextInputType.number),
        ],
      ],
    );
  }

  Widget _buildStep2() {
    final auth = context.watch<AuthProvider>();
    final sucursalNombre = auth.isSuperAdmin
        ? (_sucursal?.nombre ?? '')
        : (auth.sucursalNombre ?? 'Tu sucursal');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner de sucursal — informativo, ya fijada en paso 1
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.store_outlined,
                  color: Color(0xFF2563EB), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(sucursalNombre,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _Field(
          label: 'Cantidad a agregar *',
          sublabel: 'Stock inicial ($_unidad)',
          ctrl: _cantidadCtrl,
          hint: '0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label: 'Costo promedio',
                sublabel: 'Por $_unidad',
                ctrl: _costoCtrl,
                hint: '0.00',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helpers mínimos ────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151)),
      );

  // Contenedor visual para DropdownButton — evita DropdownButtonFormField
  // que genera GlobalKeys internas conflictivas cuando hay más de uno en el árbol.
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