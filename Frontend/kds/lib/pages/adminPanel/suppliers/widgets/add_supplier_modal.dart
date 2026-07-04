import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../common/providers/auth_provider.dart';
import '../../../../../common/services/api_service.dart';
import '../suppliers_provider.dart';

class AddSupplierModal extends StatefulWidget {
  final VoidCallback onSuccess;
  const AddSupplierModal({super.key, required this.onSuccess});

  @override
  State<AddSupplierModal> createState() => _AddSupplierModalState();
}

class _AddSupplierModalState extends State<AddSupplierModal> {
  bool _isLoading = false;
  String? _error;

  // Campos obligatorios
  final _identificacionCtrl = TextEditingController();
  final _nombreLegalCtrl    = TextEditingController();

  // Campos opcionales
  final _codigoCtrl          = TextEditingController();
  final _nombreComercialCtrl = TextEditingController();
  final _emailCtrl           = TextEditingController();
  final _telefonoCtrl        = TextEditingController();
  final _ciudadCtrl          = TextEditingController();
  final _notasCtrl           = TextEditingController();

  String _tipoIdentificacion = 'RUC';
  String _tipoProveedor      = 'productos';
  String _condicionPago      = 'contado';

  static const _tiposId    = ['RUC', 'CUIT', 'DNI', 'Pasaporte'];
  static const _tiposProv  = ['productos', 'servicios', 'materias_primas', 'mixto'];
  static const _condPago   = ['contado', 'credito_15', 'credito_30', 'credito_60', 'credito_90'];

  @override
  void dispose() {
    for (final c in [
      _identificacionCtrl, _nombreLegalCtrl, _codigoCtrl,
      _nombreComercialCtrl, _emailCtrl, _telefonoCtrl,
      _ciudadCtrl, _notasCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  Future<void> _guardar() async {
    if (_identificacionCtrl.text.trim().isEmpty)
      return setState(() => _error = 'La identificación es requerida');
    if (_nombreLegalCtrl.text.trim().isEmpty)
      return setState(() => _error = 'El nombre legal es requerido');

    final auth = context.read<AuthProvider>();
    final empresaId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.empresaId ?? auth.empresaId
        : auth.empresaId;

    if (empresaId == null)
      return setState(() => _error = 'No se pudo determinar la empresa');

    setState(() { _isLoading = true; _error = null; });

    try {
      await SuppliersService.createProveedor({
        'empresa_id': empresaId,
        'identificacion': _identificacionCtrl.text.trim(),
        'nombre_legal': _nombreLegalCtrl.text.trim(),
        'tipo_identificacion': _tipoIdentificacion,
        'tipo_proveedor': _tipoProveedor,
        'condicion_pago': _condicionPago,
        if (_codigoCtrl.text.trim().isNotEmpty)
          'codigo': _codigoCtrl.text.trim(),
        if (_nombreComercialCtrl.text.trim().isNotEmpty)
          'nombre_comercial': _nombreComercialCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty)
          'email': _emailCtrl.text.trim(),
        if (_telefonoCtrl.text.trim().isNotEmpty)
          'telefono': _telefonoCtrl.text.trim(),
        if (_ciudadCtrl.text.trim().isNotEmpty)
          'ciudad': _ciudadCtrl.text.trim(),
        if (_notasCtrl.text.trim().isNotEmpty)
          'notas': _notasCtrl.text.trim(),
      });
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al crear el proveedor'; _isLoading = false; });
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
              Row(
                children: [
                  const Expanded(
                    child: Text('Nuevo Proveedor',
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

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Datos de identificación'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Identificación *',
                              ctrl: _identificacionCtrl,
                              hint: 'Ej: 20-12345678-9',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Tipo'),
                                const SizedBox(height: 6),
                                _dropdown(
                                  child: DropdownButton<String>(
                                    key: const ValueKey('dd_tipo_id'),
                                    value: _tipoIdentificacion,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    items: _tiposId
                                        .map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _tipoIdentificacion = v ?? 'RUC'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _Field(
                          label: 'Nombre legal *',
                          ctrl: _nombreLegalCtrl,
                          hint: 'Ej: Distribuidora ABC S.A.'),
                      const SizedBox(height: 12),
                      _Field(
                          label: 'Nombre comercial',
                          ctrl: _nombreComercialCtrl,
                          hint: 'Ej: ABC Distribuciones'),
                      const SizedBox(height: 12),
                      _Field(
                          label: 'Código',
                          ctrl: _codigoCtrl,
                          hint: 'Ej: PROV-001'),

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 16),

                      _sectionLabel('Tipo y condición de pago'),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Tipo de proveedor'),
                                const SizedBox(height: 6),
                                _dropdown(
                                  child: DropdownButton<String>(
                                    key: const ValueKey('dd_tipo_prov'),
                                    value: _tipoProveedor,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    items: _tiposProv
                                        .map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(
                                                _labelTipo(t),
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _tipoProveedor = v ?? 'productos'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Condición de pago'),
                                const SizedBox(height: 6),
                                _dropdown(
                                  child: DropdownButton<String>(
                                    key: const ValueKey('dd_cond_pago'),
                                    value: _condicionPago,
                                    isExpanded: true,
                                    underline: const SizedBox.shrink(),
                                    items: _condPago
                                        .map((c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                _labelPago(c),
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(
                                        () => _condicionPago = v ?? 'contado'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 16),

                      _sectionLabel('Contacto'),
                      const SizedBox(height: 12),

                      _Field(
                          label: 'Email',
                          ctrl: _emailCtrl,
                          hint: 'proveedor@email.com',
                          keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      _Field(
                          label: 'Teléfono',
                          ctrl: _telefonoCtrl,
                          hint: 'Ej: +506 8888-8888',
                          keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      _Field(
                          label: 'Ciudad',
                          ctrl: _ciudadCtrl,
                          hint: 'Ej: San José'),
                      const SizedBox(height: 12),
                      _Field(
                          label: 'Notas',
                          ctrl: _notasCtrl,
                          hint: 'Observaciones opcionales',
                          maxLines: 3),
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
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Guardar',
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

  String _labelTipo(String t) => const {
        'productos': 'Productos',
        'servicios': 'Servicios',
        'materias_primas': 'Materias Primas',
        'mixto': 'Mixto',
      }[t] ?? t;

  String _labelPago(String p) => const {
        'contado': 'Contado',
        'credito_15': 'Crédito 15d',
        'credito_30': 'Crédito 30d',
        'credito_60': 'Crédito 60d',
        'credito_90': 'Crédito 90d',
      }[p] ?? p;

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