import 'package:flutter/material.dart';
import '../../../../common/models/caja_models.dart';
import '../../../../common/services/api_service.dart';
import '../caja_provider.dart';
import 'caja_field.dart';

class SesionesPanel extends StatefulWidget {
  final CajaRead caja;

  const SesionesPanel({super.key, required this.caja});

  @override
  State<SesionesPanel> createState() => _SesionesPanelState();
}

class _SesionesPanelState extends State<SesionesPanel> {
  bool _isLoading = true;
  String? _error;
  List<SesionCajaRead> _sesiones = [];
  SesionCajaRead? _sesionSeleccionada;

  static const _labelsEstado = {
    'abierta': 'Abierta',
    'cerrada': 'Cerrada',
    'auditada': 'Auditada',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result =
          await CajaService.getSesiones(widget.caja.id);
      if (!mounted) return;
      setState(() {
        _sesiones = result.items;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar sesiones';
        _isLoading = false;
      });
    }
  }

  Future<void> _abrirSesion() async {
    showDialog(
      context: context,
      builder: (_) => _AbrirSesionModal(
        caja: widget.caja,
        onSuccess: _load,
      ),
    );
  }

  Future<void> _cerrarSesion(SesionCajaRead sesion) async {
    showDialog(
      context: context,
      builder: (_) => _CerrarSesionModal(
        sesion: sesion,
        onSuccess: _load,
      ),
    );
  }

  Future<void> _auditarSesion(SesionCajaRead sesion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Auditar sesión',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Marcar la sesión "${sesion.numeroSesion}" como auditada?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Auditar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CajaService.auditarSesion(sesion.id);
        _load();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del panel
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.caja.nombre,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827)),
                    ),
                    Text(
                      '${_sesiones.length} sesiones',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_outlined,
                          color: Color(0xFF6B7280), size: 20),
                      tooltip: 'Actualizar',
                    ),
                    if (widget.caja.activa &&
                        !_sesiones.any((s) => s.abierta))
                      GestureDetector(
                        onTap: _abrirSesion,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.play_arrow_outlined,
                                  size: 15, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Abrir sesión',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Contenido
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF2563EB))),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFDC2626))),
            )
          else if (_sesiones.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No hay sesiones registradas',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          else
            // Lista de sesiones
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sesiones.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (_, i) {
                final sesion = _sesiones[i];
                final seleccionada = _sesionSeleccionada?.id == sesion.id;

                return Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() =>
                          _sesionSeleccionada =
                              seleccionada ? null : sesion),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Estado badge
                            _estadoBadge(sesion.estado),
                            const SizedBox(width: 12),

                            // Info de la sesión
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sesion.numeroSesion,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827)),
                                  ),
                                  Text(
                                    sesion.fechaApertura != null
                                        ? _formatDateTime(
                                            sesion.fechaApertura!)
                                        : '—',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF)),
                                  ),
                                ],
                              ),
                            ),

                            // Total de ventas
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₡${_formatMoney(sesion.totalVentas)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827)),
                                ),
                                Text(
                                  '${sesion.cantidadTransacciones} transacciones',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF)),
                                ),
                              ],
                            ),

                            const SizedBox(width: 12),
                            Icon(
                              seleccionada
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Detalle expandible de la sesión
                    if (seleccionada)
                      _SesionDetalle(
                        sesion: sesion,
                        onCerrar: () => _cerrarSesion(sesion),
                        onAuditar: () => _auditarSesion(sesion),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _estadoBadge(String estado) {
    final data = switch (estado) {
      'abierta' => (const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
      'cerrada' => (const Color(0xFF6B7280), const Color(0xFFF3F4F6)),
      'auditada' => (const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
      _ => (const Color(0xFF6B7280), const Color(0xFFF3F4F6)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: data.$2, borderRadius: BorderRadius.circular(12)),
      child: Text(
        _labelsEstado[estado] ?? estado,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: data.$1),
      ),
    );
  }

  String _formatMoney(double v) => v
      .toStringAsFixed(2)
      .replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Detalle expandible de una sesión ──────────────────────────────────────────
class _SesionDetalle extends StatelessWidget {
  final SesionCajaRead sesion;
  final VoidCallback onCerrar;
  final VoidCallback onAuditar;

  const _SesionDetalle({
    required this.sesion,
    required this.onCerrar,
    required this.onAuditar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Desglose por método de pago
          const Text('Desglose de cobros',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 10),
          _MetodoRow('Efectivo', sesion.totalEfectivo),
          _MetodoRow('Tarjeta débito', sesion.totalTarjetaDebito),
          _MetodoRow('Tarjeta crédito', sesion.totalTarjetaCredito),
          _MetodoRow('SINPE', sesion.totalSinpe),
          _MetodoRow('Transferencia', sesion.totalTransferencia),
          _MetodoRow('Otros', sesion.totalOtros),
          const Divider(height: 16, color: Color(0xFFE5E7EB)),
          _MetodoRow('Total ventas', sesion.totalVentas, bold: true),
          _MetodoRow('Entradas', sesion.totalEntradas,
              color: const Color(0xFF16A34A)),
          _MetodoRow('Salidas', sesion.totalSalidas,
              color: const Color(0xFFDC2626)),

          if (sesion.montoCierre != null) ...[
            const Divider(height: 16, color: Color(0xFFE5E7EB)),
            _MetodoRow('Monto apertura', sesion.montoApertura),
            _MetodoRow('Monto cierre', sesion.montoCierre!),
            if (sesion.montoEsperado != null)
              _MetodoRow('Esperado', sesion.montoEsperado!),
            if (sesion.diferencia != null)
              _MetodoRow(
                'Diferencia',
                sesion.diferencia!,
                color: sesion.diferencia! < 0
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A),
                bold: true,
              ),
          ],

          const SizedBox(height: 16),

          // Acciones según estado
          Row(
            children: [
              if (sesion.abierta)
                _ActionBtn(
                  icon: Icons.stop_circle_outlined,
                  label: 'Cerrar sesión',
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEE2E2),
                  onTap: onCerrar,
                ),
              if (sesion.cerrada) ...[
                _ActionBtn(
                  icon: Icons.verified_outlined,
                  label: 'Auditar',
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  onTap: onAuditar,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetodoRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final Color? color;

  const _MetodoRow(this.label, this.value,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    if (value == 0) return const SizedBox.shrink();
    final c = color ?? const Color(0xFF374151);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                  fontWeight:
                      bold ? FontWeight.w600 : FontWeight.normal)),
          Text(
            '₡${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: c),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color bgColor;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Modal abrir sesión ────────────────────────────────────────────────────────
class _AbrirSesionModal extends StatefulWidget {
  final CajaRead caja;
  final VoidCallback onSuccess;

  const _AbrirSesionModal({required this.caja, required this.onSuccess});

  @override
  State<_AbrirSesionModal> createState() => _AbrirSesionModalState();
}

class _AbrirSesionModalState extends State<_AbrirSesionModal> {
  bool _isLoading = false;
  String? _error;
  final _numeroCtrl = TextEditingController();
  final _montoCtrl  = TextEditingController(text: '0');
  final _notasCtrl  = TextEditingController();

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  Future<void> _abrir() async {
    if (_numeroCtrl.text.trim().isEmpty)
      return setState(() => _error = 'El número de sesión es requerido');

    setState(() { _isLoading = true; _error = null; });

    try {
      await CajaService.abrirSesion(widget.caja.id, {
        'caja_id': widget.caja.id,
        'numero_sesion': _numeroCtrl.text.trim(),
        'monto_apertura': double.tryParse(_montoCtrl.text) ?? 0,
        if (_notasCtrl.text.trim().isNotEmpty)
          'notas_apertura': _notasCtrl.text.trim(),
      });
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al abrir sesión'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Abrir sesión de caja',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        Text(widget.caja.nombre,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFDC2626))),
                ),

              CajaField(
                  label: 'Número de sesión *',
                  ctrl: _numeroCtrl,
                  hint: 'Ej: S-001'),
              const SizedBox(height: 12),
              CajaField(
                label: 'Monto de apertura',
                ctrl: _montoCtrl,
                hint: '0.00',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              CajaField(
                  label: 'Notas',
                  ctrl: _notasCtrl,
                  hint: 'Opcional',
                  maxLines: 2),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                      onPressed: _isLoading ? null : _abrir,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Abrir sesión',
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
}

// ── Modal cerrar sesión ───────────────────────────────────────────────────────
class _CerrarSesionModal extends StatefulWidget {
  final SesionCajaRead sesion;
  final VoidCallback onSuccess;

  const _CerrarSesionModal({
    required this.sesion,
    required this.onSuccess,
  });

  @override
  State<_CerrarSesionModal> createState() => _CerrarSesionModalState();
}

class _CerrarSesionModalState extends State<_CerrarSesionModal> {
  bool _isLoading = false;
  String? _error;
  final _montoCtrl = TextEditingController(text: '0');
  final _notasCtrl = TextEditingController();

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  Future<void> _cerrar() async {
    final monto = double.tryParse(_montoCtrl.text);
    if (monto == null || monto < 0)
      return setState(() => _error = 'Ingresa un monto válido');

    setState(() { _isLoading = true; _error = null; });

    try {
      await CajaService.cerrarSesion(widget.sesion.id, {
        'monto_cierre': monto,
        if (_notasCtrl.text.trim().isNotEmpty)
          'notas_cierre': _notasCtrl.text.trim(),
      });
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cerrar sesión';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sesion;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cerrar sesión de caja',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        Text('Sesión ${s.numeroSesion}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Resumen rápido
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _ResumenRow('Total ventas', s.totalVentas, bold: true),
                    _ResumenRow('Efectivo', s.totalEfectivo),
                    _ResumenRow('Tarjeta', s.totalTarjetaDebito + s.totalTarjetaCredito),
                    _ResumenRow('SINPE', s.totalSinpe),
                    _ResumenRow('Monto apertura', s.montoApertura),
                    const Divider(height: 12),
                    Text(
                      '${s.cantidadTransacciones} transacciones',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFDC2626))),
                ),

              CajaField(
                label: 'Monto de cierre (conteo físico) *',
                ctrl: _montoCtrl,
                hint: '0.00',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              CajaField(
                  label: 'Notas de cierre',
                  ctrl: _notasCtrl,
                  hint: 'Opcional',
                  maxLines: 2),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                      onPressed: _isLoading ? null : _cerrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Cerrar sesión',
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
}

class _ResumenRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  const _ResumenRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    if (value == 0 && !bold) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                  fontWeight:
                      bold ? FontWeight.w600 : FontWeight.normal)),
          Text(
            '₡${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: const Color(0xFF111827)),
          ),
        ],
      ),
    );
  }
}