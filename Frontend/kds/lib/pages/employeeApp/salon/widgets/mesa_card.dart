import 'package:flutter/material.dart';
import '../../../../common/models/mesa_models.dart';
import '../../../../common/widgets/status_badge.dart';

class _MesaConfig {
  final Color borderColor;
  final Widget badge;
  const _MesaConfig({required this.borderColor, required this.badge});

  factory _MesaConfig.from(MesaRead mesa) {
    switch (mesa.estado) {
      case 'ocupada':
        return _MesaConfig(
            borderColor: const Color(0xFFFCA5A5),
            badge: StatusBadge.mesaEstado(mesa.estado));
      case 'reservada':
        return _MesaConfig(
            borderColor: const Color(0xFFFDE68A),
            badge: StatusBadge.mesaEstado(mesa.estado));
      case 'fuera_de_servicio':
        return _MesaConfig(
            borderColor: const Color(0xFFE5E7EB),
            badge: StatusBadge.mesaEstado(mesa.estado));
      default:
        return _MesaConfig(
            borderColor: const Color(0xFFBBF7D0),
            badge: StatusBadge.mesaEstado(mesa.estado));
    }
  }
}

class MesaCard extends StatelessWidget {
  final MesaRead mesa;
  final VoidCallback? onTap;

  const MesaCard({super.key, required this.mesa, this.onTap});

  @override
  Widget build(BuildContext context) {
    final config = _MesaConfig.from(mesa);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: config.borderColor, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mesa ${mesa.numero}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827))),
                config.badge,
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline,
                        size: 20, color: Colors.grey.shade400),
                    const SizedBox(height: 4),
                    Text('${mesa.capacidad} personas',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                    if (mesa.zona != null) ...[
                      const SizedBox(height: 2),
                      Text(mesa.zona!,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
