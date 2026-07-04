import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../employees_provider.dart';
import 'employee_field.dart';

class EmployeeDetailModal extends StatefulWidget {
  final PerfilPublicRead perfil;

  const EmployeeDetailModal({super.key, required this.perfil});

  @override
  State<EmployeeDetailModal> createState() => _EmployeeDetailModalState();
}

class _EmployeeDetailModalState extends State<EmployeeDetailModal> {
  bool _isLoadingRol = false;
  bool _isLoadingEstado = false;
  String? _error;

  Future<void> _cambiarRol(String nuevoRol) async {
    setState(() {
      _isLoadingRol = true;
      _error = null;
    });

    final provider = context.read<EmployeesProvider>();
    final ok = await provider.cambiarRol(widget.perfil.id, nuevoRol);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = provider.error;
        _isLoadingRol = false;
      });
    }
  }

  Future<void> _cambiarEstado(String nuevoEstado) async {
    setState(() {
      _isLoadingEstado = true;
      _error = null;
    });

    final provider = context.read<EmployeesProvider>();
    final ok = await provider.cambiarEstado(widget.perfil.id, nuevoEstado);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = provider.error;
        _isLoadingEstado = false;
      });
    }
  }

  Future<void> _confirmarEliminar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desactivar empleado',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
            '¿Desactivar a "${widget.perfil.nombreCompleto}"? '
            'Sus sesiones activas seran cerradas.',
            style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<EmployeesProvider>();
    final ok = await provider.eliminarEmpleado(widget.perfil.id);
    if (mounted && ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.perfil;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con avatar inicial
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: Text(
                      p.nombreCompleto.isNotEmpty
                          ? p.nombreCompleto[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nombreCompleto,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        Text(p.email,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Badges
              Row(
                children: [
                  RolBadge(rol: p.rolGlobal),
                  const SizedBox(width: 8),
                  EstadoBadge(estado: p.estado),
                ],
              ),
              const SizedBox(height: 20),

              if (_error != null) ...[
                EmployeeErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],

              const Divider(height: 1),
              const SizedBox(height: 16),

              // Acciones rapidas — Cambiar Rol
              const Text('Cambiar Rol',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['admin_empresa', 'empleado']
                    .where((r) => r != p.rolGlobal)
                    .map((r) => OutlinedButton(
                          onPressed:
                              _isLoadingRol ? null : () => _cambiarRol(r),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          child: _isLoadingRol
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : Text(
                                  r == 'admin_empresa'
                                      ? 'Hacer Admin'
                                      : 'Hacer Empleado',
                                  style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              // Acciones — Cambiar Estado
              const Text('Cambiar Estado',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['activo', 'suspendido', 'inactivo']
                    .where((e) => e != p.estado)
                    .map((e) {
                  final color = switch (e) {
                    'activo' => const Color(0xFF16A34A),
                    'suspendido' => const Color(0xFFF97316),
                    _ => const Color(0xFF6B7280),
                  };
                  return OutlinedButton(
                    onPressed: _isLoadingEstado
                        ? null
                        : () => _cambiarEstado(e),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color.withOpacity(0.4)),
                      foregroundColor: color,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: _isLoadingEstado
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: color))
                        : Text(
                            e == 'activo'
                                ? 'Reactivar'
                                : e == 'suspendido'
                                    ? 'Suspender'
                                    : 'Desactivar',
                            style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Zona peligrosa
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Zona de riesgo',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF))),
                  TextButton.icon(
                    onPressed: _confirmarEliminar,
                    icon: const Icon(Icons.person_off_outlined,
                        size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Desactivar cuenta',
                        style: TextStyle(
                            color: Color(0xFFEF4444), fontSize: 13)),
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