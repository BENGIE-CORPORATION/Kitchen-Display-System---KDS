import 'package:flutter/material.dart';

/// Badge de estado reutilizable.
/// Ejemplo: Activo/Inactivo, Disponible/Bajo, Ocupada/Disponible/Reservada
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? dotColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.dotColor,
  });

  /// Factories para estados comunes
  factory StatusBadge.active() => const StatusBadge(
        label: 'Activo',
        backgroundColor: Color(0xFFDCFCE7),
        textColor: Color(0xFF15803D),
        dotColor: Color(0xFF16A34A),
      );

  factory StatusBadge.inactive() => const StatusBadge(
        label: 'Inactivo',
        backgroundColor: Color(0xFFF3F4F6),
        textColor: Color(0xFF4B5563),
        dotColor: Color(0xFF6B7280),
      );

  factory StatusBadge.low() => const StatusBadge(
        label: 'Bajo',
        backgroundColor: Color(0xFFFEE2E2),
        textColor: Color(0xFFB91C1C),
      );

  factory StatusBadge.available() => const StatusBadge(
        label: 'Disponible',
        backgroundColor: Color(0xFFDCFCE7),
        textColor: Color(0xFF15803D),
      );

  factory StatusBadge.occupied() => const StatusBadge(
        label: 'Ocupada',
        backgroundColor: Color(0xFFFEE2E2),
        textColor: Color(0xFFB91C1C),
      );

  factory StatusBadge.reserved() => const StatusBadge(
        label: 'Reservada',
        backgroundColor: Color(0xFFFEF3C7),
        textColor: Color(0xFFB45309),
      );

  /// Estados reales de mesa (/mesas) — libre | ocupada | reservada | fuera_de_servicio
  factory StatusBadge.fueraDeServicio() => const StatusBadge(
        label: 'Fuera de servicio',
        backgroundColor: Color(0xFFF3F4F6),
        textColor: Color(0xFF4B5563),
      );

  /// Estados de pedido/cocina (/pedidos) — abierto | en_preparacion | listo | entregado
  factory StatusBadge.nuevo() => const StatusBadge(
        label: 'Nuevo',
        backgroundColor: Color(0xFFDBEAFE),
        textColor: Color(0xFF1D4ED8),
        dotColor: Color(0xFF2563EB),
      );

  factory StatusBadge.enPreparacion() => const StatusBadge(
        label: 'En preparación',
        backgroundColor: Color(0xFFFEF3C7),
        textColor: Color(0xFFB45309),
        dotColor: Color(0xFFD97706),
      );

  factory StatusBadge.listo() => const StatusBadge(
        label: 'Listo',
        backgroundColor: Color(0xFFDCFCE7),
        textColor: Color(0xFF15803D),
        dotColor: Color(0xFF16A34A),
      );

  factory StatusBadge.entregado() => const StatusBadge(
        label: 'Entregado',
        backgroundColor: Color(0xFFF3F4F6),
        textColor: Color(0xFF4B5563),
      );

  /// Mapea un estado textual de pedido a su badge correspondiente.
  factory StatusBadge.pedidoEstado(String estado) {
    switch (estado) {
      case 'abierto':
        return StatusBadge.nuevo();
      case 'en_preparacion':
        return StatusBadge.enPreparacion();
      case 'listo':
        return StatusBadge.listo();
      case 'entregado':
        return StatusBadge.entregado();
      default:
        return StatusBadge.inactive();
    }
  }

  /// Mapea un estado textual de mesa a su badge correspondiente.
  factory StatusBadge.mesaEstado(String estado) {
    switch (estado) {
      case 'libre':
        return StatusBadge.available();
      case 'ocupada':
        return StatusBadge.occupied();
      case 'reservada':
        return StatusBadge.reserved();
      case 'fuera_de_servicio':
        return StatusBadge.fueraDeServicio();
      default:
        return StatusBadge.inactive();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}