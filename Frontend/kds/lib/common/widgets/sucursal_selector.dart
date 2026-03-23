import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/sucursal_models.dart';

/// Selector de sucursal para super_admin.
/// Se coloca en el sidebar o header del AdminLayout.
/// Solo se muestra si el usuario es super_admin.
class SucursalSelector extends StatelessWidget {
  const SucursalSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isSuperAdmin || auth.todasLasSucursales.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SucursalRead>(
          value: auth.sucursalSeleccionada,
          hint: const Text('Seleccionar sucursal',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          icon: const Icon(Icons.store_outlined,
              size: 16, color: Color(0xFF6B7280)),
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w500),
          items: auth.todasLasSucursales
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: s.estado == 'activo'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF9CA3AF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          '${s.nombre} · ${s.codigo}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (sucursal) {
            if (sucursal != null) {
              auth.seleccionarSucursal(sucursal);
            }
          },
        ),
      ),
    );
  }
}