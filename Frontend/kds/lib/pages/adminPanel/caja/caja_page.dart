import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../common/models/caja_models.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';
import 'caja_provider.dart';
import 'widgets/add_caja_modal.dart';
import 'widgets/edit_caja_modal.dart';
import 'widgets/sesiones_panel.dart';

class CajaPage extends StatefulWidget {
  const CajaPage({super.key});

  @override
  State<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends State<CajaPage> {
  CajaRead? _cajaSeleccionada;

  static const _labelsTipo = {
    'principal': 'Principal',
    'secundaria': 'Secundaria',
    'express': 'Express',
  };

  static const _labelsEstado = {
    'activo': 'Activo',
    'inactivo': 'Inactivo',
    'mantenimiento': 'Mantenimiento',
  };

  void _showAddModal(CajaProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AddCajaModal(
        sucursalId: provider.sucursalId!,
        onSuccess: provider.reload,
      ),
    );
  }

  void _showEditModal(CajaRead caja, CajaProvider provider) {
    showDialog(
      context: context,
      builder: (_) => EditCajaModal(
        caja: caja,
        onSuccess: provider.reload,
      ),
    );
  }

  Future<void> _confirmarDesactivar(
      CajaRead caja, CajaProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Desactivar caja',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Desactivar la caja "${caja.nombre}"? '
          'No podrá usarse para nuevas sesiones.',
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
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Desactivar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CajaService.deleteCaja(caja.id);
        if (_cajaSeleccionada?.id == caja.id) {
          setState(() => _cajaSeleccionada = null);
        }
        provider.reload();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) {
        final auth = ctx.read<AuthProvider>();
        return CajaProvider()
          ..init(auth)
          ..load();
      },
      child: Consumer<CajaProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Scaffold(
              backgroundColor: Color(0xFFF9FAFB),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            );
          }

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cajas',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${provider.cajas.length} cajas · '
                            '${provider.cajas.where((c) => c.activa).length} activas',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      if (provider.sucursalId != null)
                        GestureDetector(
                          onTap: () => _showAddModal(provider),
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
                                Text('Nueva Caja',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (provider.error != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(provider.error!,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFDC2626))),
                    )
                  else if (provider.cajas.isEmpty)
                    _buildEmpty(provider)
                  else
                    // Layout de dos columnas — lista de cajas + panel de sesiones
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lista de cajas
                        SizedBox(
                          width: 320,
                          child: Column(
                            children: provider.cajas
                                .map((caja) => _CajaCard(
                                      caja: caja,
                                      seleccionada:
                                          _cajaSeleccionada?.id == caja.id,
                                      labelsTipo: _labelsTipo,
                                      labelsEstado: _labelsEstado,
                                      onTap: () => setState(
                                          () => _cajaSeleccionada = caja),
                                      onEdit: () =>
                                          _showEditModal(caja, provider),
                                      onDesactivar: () =>
                                          _confirmarDesactivar(caja, provider),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Panel de sesiones de la caja seleccionada
                        Expanded(
                          child: _cajaSeleccionada == null
                              ? _buildSeleccionaCaja()
                              : SesionesPanel(
                                  key: ValueKey(_cajaSeleccionada!.id),
                                  caja: _cajaSeleccionada!,
                                ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(CajaProvider provider) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.point_of_sale_outlined,
              size: 48, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          const Text('No hay cajas configuradas',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827))),
          const SizedBox(height: 4),
          const Text('Crea una caja para comenzar a operar',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 24),
          if (provider.sucursalId != null)
            ElevatedButton.icon(
              onPressed: () => _showAddModal(provider),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Crear primera caja'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeleccionaCaja() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined,
                size: 40, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'Selecciona una caja',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151)),
            ),
            SizedBox(height: 4),
            Text(
              'Haz clic en una caja para ver sus sesiones',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de caja ────────────────────────────────────────────────────────────
class _CajaCard extends StatelessWidget {
  final CajaRead caja;
  final bool seleccionada;
  final Map<String, String> labelsTipo;
  final Map<String, String> labelsEstado;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDesactivar;

  const _CajaCard({
    required this.caja,
    required this.seleccionada,
    required this.labelsTipo,
    required this.labelsEstado,
    required this.onTap,
    required this.onEdit,
    required this.onDesactivar,
  });

  @override
  Widget build(BuildContext context) {
    final estadoColor = switch (caja.estado) {
      'activo' => const Color(0xFF16A34A),
      'inactivo' => const Color(0xFF6B7280),
      'mantenimiento' => const Color(0xFFD97706),
      _ => const Color(0xFF6B7280),
    };

    final estadoBg = switch (caja.estado) {
      'activo' => const Color(0xFFF0FDF4),
      'inactivo' => const Color(0xFFF3F4F6),
      'mantenimiento' => const Color(0xFFFFFBEB),
      _ => const Color(0xFFF3F4F6),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionada
                ? const Color(0xFF2563EB)
                : const Color(0xFFE5E7EB),
            width: seleccionada ? 2 : 1,
          ),
          boxShadow: seleccionada
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: seleccionada
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.point_of_sale_outlined,
                    size: 20,
                    color: seleccionada
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caja.nombre,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827)),
                      ),
                      Text(
                        '${caja.codigo} · ${labelsTipo[caja.tipo] ?? caja.tipo}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: estadoBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    labelsEstado[caja.estado] ?? caja.estado,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: estadoColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionBtn(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                if (caja.activa)
                  _ActionBtn(
                    icon: Icons.block_outlined,
                    label: 'Desactivar',
                    color: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEE2E2),
                    onTap: onDesactivar,
                  ),
              ],
            ),
          ],
        ),
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
    this.color = const Color(0xFF374151),
    this.bgColor = const Color(0xFFF3F4F6),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}