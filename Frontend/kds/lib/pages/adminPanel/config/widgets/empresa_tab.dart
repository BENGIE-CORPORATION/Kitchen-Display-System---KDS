import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config_provider.dart';
import 'config_field.dart';

class EmpresaTab extends StatefulWidget {
  const EmpresaTab({super.key});

  @override
  State<EmpresaTab> createState() => _EmpresaTabState();
}

class _EmpresaTabState extends State<EmpresaTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreLegalCtrl;
  late final TextEditingController _nombreComercialCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _timezoneCtrl;

  String _tipoNegocio = 'restaurante';
  bool _isLoading = false;
  bool _dirty = false;
  String? _error;
  String? _success;

  static const _tiposNegocio = [
    MapEntry('restaurante', 'Restaurante'),
    MapEntry('supermercado', 'Supermercado'),
    MapEntry('retail', 'Retail'),
    MapEntry('mixto', 'Mixto'),
  ];

  @override
  void initState() {
    super.initState();
    final empresa = context.read<ConfigProvider>().empresa;
    _nombreLegalCtrl =
        TextEditingController(text: empresa?.nombreLegal ?? '');
    _nombreComercialCtrl =
        TextEditingController(text: empresa?.nombreComercial ?? '');
    _emailCtrl = TextEditingController(text: empresa?.email ?? '');
    _telefonoCtrl =
        TextEditingController(text: empresa?.telefono ?? '');
    _direccionCtrl =
        TextEditingController(text: empresa?.direccionFiscal ?? '');
    _timezoneCtrl =
        TextEditingController(text: empresa?.timezone ?? 'UTC');
    _tipoNegocio = empresa?.tipoNegocio ?? 'restaurante';

    for (final ctrl in [
      _nombreLegalCtrl,
      _nombreComercialCtrl,
      _emailCtrl,
      _telefonoCtrl,
      _direccionCtrl,
      _timezoneCtrl,
    ]) {
      ctrl.addListener(() => setState(() => _dirty = true));
    }
  }

  @override
  void dispose() {
    _nombreLegalCtrl.dispose();
    _nombreComercialCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _timezoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    final body = <String, dynamic>{};
    final empresa = context.read<ConfigProvider>().empresa;

    if (_nombreLegalCtrl.text.trim() != empresa?.nombreLegal)
      body['nombre_legal'] = _nombreLegalCtrl.text.trim();
    if (_nombreComercialCtrl.text.trim() != empresa?.nombreComercial)
      body['nombre_comercial'] = _nombreComercialCtrl.text.trim();
    if (_emailCtrl.text.trim() != empresa?.email)
      body['email'] = _emailCtrl.text.trim();
    if (_telefonoCtrl.text.trim() != (empresa?.telefono ?? ''))
      body['telefono'] = _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim();
    if (_direccionCtrl.text.trim() != (empresa?.direccionFiscal ?? ''))
      body['direccion_fiscal'] = _direccionCtrl.text.trim().isEmpty
          ? null
          : _direccionCtrl.text.trim();
    if (_tipoNegocio != empresa?.tipoNegocio)
      body['tipo_negocio'] = _tipoNegocio;
    if (_timezoneCtrl.text.trim() != empresa?.timezone)
      body['timezone'] = _timezoneCtrl.text.trim();

    if (body.isEmpty) {
      setState(() {
        _isLoading = false;
        _dirty = false;
        _success = 'Sin cambios que guardar';
      });
      return;
    }

    final provider = context.read<ConfigProvider>();
    final ok = await provider.updateEmpresa(body);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _dirty = false;
        _success = 'Empresa actualizada correctamente';
      } else {
        _error = provider.error ?? 'Error al actualizar';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final empresa = context.watch<ConfigProvider>().empresa;
    if (empresa == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de seccion
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business_outlined,
                      color: Color(0xFF6366F1), size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Datos de la Empresa',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(empresa.identificacion,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_error != null) ...[
              ConfigErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            if (_success != null) ...[
              ConfigSuccessBanner(message: _success!),
              const SizedBox(height: 16),
            ],

            // Informacion legal — readonly
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informacion fiscal (solo lectura)',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoItem(
                            label: 'Identificacion',
                            value: empresa.identificacion),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _InfoItem(
                            label: 'Pais', value: empresa.pais),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _InfoItem(
                            label: 'Moneda', value: empresa.moneda),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Nombre legal y comercial
            const ConfigSectionLabel(label: 'Identidad'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ConfigField(
                    label: 'Nombre legal *',
                    ctrl: _nombreLegalCtrl,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Minimo 2 caracteres'
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ConfigField(
                    label: 'Nombre comercial *',
                    ctrl: _nombreComercialCtrl,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Minimo 2 caracteres'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tipo de negocio
            ConfigDropdown(
              label: 'Tipo de negocio *',
              value: _tipoNegocio,
              opciones: _tiposNegocio,
              onChanged: (v) =>
                  setState(() {
                    _tipoNegocio = v ?? 'restaurante';
                    _dirty = true;
                  }),
            ),
            const SizedBox(height: 20),

            // Contacto
            const ConfigSectionLabel(label: 'Contacto'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ConfigField(
                    label: 'Email *',
                    ctrl: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (!v.contains('@')) return 'Email invalido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ConfigField(
                    label: 'Telefono',
                    ctrl: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    hint: '+593 999 000 000',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            ConfigField(
              label: 'Direccion fiscal',
              ctrl: _direccionCtrl,
              hint: 'Av. Principal 123, Ciudad',
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Configuracion regional
            const ConfigSectionLabel(label: 'Regional'),
            ConfigField(
              label: 'Zona horaria',
              ctrl: _timezoneCtrl,
              hint: 'America/Guayaquil',
            ),
            const SizedBox(height: 28),

            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_dirty)
                  TextButton(
                    onPressed: _isLoading ? null : _resetForm,
                    child: const Text('Descartar cambios',
                        style: TextStyle(color: Color(0xFF6B7280))),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed:
                      (_isLoading || !_dirty) ? null : _guardar,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Guardar cambios'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resetForm() {
    final empresa = context.read<ConfigProvider>().empresa;
    _nombreLegalCtrl.text = empresa?.nombreLegal ?? '';
    _nombreComercialCtrl.text = empresa?.nombreComercial ?? '';
    _emailCtrl.text = empresa?.email ?? '';
    _telefonoCtrl.text = empresa?.telefono ?? '';
    _direccionCtrl.text = empresa?.direccionFiscal ?? '';
    _timezoneCtrl.text = empresa?.timezone ?? 'UTC';
    setState(() {
      _tipoNegocio = empresa?.tipoNegocio ?? 'restaurante';
      _dirty = false;
      _error = null;
      _success = null;
    });
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
      ],
    );
  }
}