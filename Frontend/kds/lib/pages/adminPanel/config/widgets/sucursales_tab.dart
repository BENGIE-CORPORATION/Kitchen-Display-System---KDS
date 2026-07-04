import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config_provider.dart';
import 'config_field.dart';
import 'add_sucursal_modal.dart';
import 'edit_sucursal_modal.dart';

class SucursalesTab extends StatelessWidget {
  const SucursalesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConfigProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sucursales',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Gestion de ubicaciones de la empresa',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: provider,
                    child: const AddSucursalModal(),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nueva Sucursal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Tabla
        Expanded(
          child: provider.sucursales.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.store_outlined,
                          size: 48, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 12),
                      Text('No hay sucursales registradas',
                          style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280))),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Table(
                        columnWidths: const {
                          0: IntrinsicColumnWidth(), // Codigo
                          1: FlexColumnWidth(2),     // Nombre
                          2: FlexColumnWidth(1.5),   // Tipo
                          3: FlexColumnWidth(1.5),   // Ciudad
                          4: FlexColumnWidth(1.5),   // Estado
                          5: IntrinsicColumnWidth(),  // Acciones
                        },
                        children: [
                          // Header
                          TableRow(
                            decoration: const BoxDecoration(
                                color: Color(0xFFF9FAFB)),
                            children: [
                              _HeaderCell('Codigo'),
                              _HeaderCell('Nombre'),
                              _HeaderCell('Tipo'),
                              _HeaderCell('Ciudad'),
                              _HeaderCell('Estado'),
                              _HeaderCell(''),
                            ],
                          ),
                          // Rows
                          ...provider.sucursales.map((s) => TableRow(
                                decoration: const BoxDecoration(
                                  border: Border(
                                      top: BorderSide(
                                          color: Color(0xFFE5E7EB))),
                                ),
                                children: [
                                  // Codigo
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(s.codigo,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'monospace',
                                                color: Color(0xFF374151))),
                                      ),
                                    ),
                                  ),
                                  // Nombre
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(s.nombre,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500)),
                                    ),
                                  ),
                                  // Tipo
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(_labelTipo(s.tipo),
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF4B5563))),
                                    ),
                                  ),
                                  // Ciudad
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(s.ciudad ?? '—',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF6B7280))),
                                    ),
                                  ),
                                  // Estado
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: SucursalEstadoBadge(
                                          estado: s.estado),
                                    ),
                                  ),
                                  // Acciones
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _ActionBtn(
                                            icon: Icons.edit_outlined,
                                            tooltip: 'Editar',
                                            onTap: () => showDialog(
                                              context: context,
                                              builder: (_) =>
                                                  ChangeNotifierProvider
                                                      .value(
                                                value: provider,
                                                child: EditSucursalModal(
                                                    sucursal: s),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          _ActionBtn(
                                            icon: Icons.delete_outline,
                                            tooltip: 'Desactivar',
                                            color: const Color(0xFFEF4444),
                                            onTap: () =>
                                                _confirmarEliminar(
                                                    context, provider, s),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  String _labelTipo(String tipo) => switch (tipo) {
        'principal' => 'Principal',
        'sucursal' => 'Sucursal',
        'bodega' => 'Bodega',
        'punto_venta' => 'Punto de Venta',
        _ => tipo,
      };

  void _confirmarEliminar(
      BuildContext context, ConfigProvider provider, SucursalRead s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desactivar sucursal',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
            '¿Desactivar "${s.nombre}"? Los empleados asignados '
            'perderan acceso a esta sucursal.',
            style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await provider.deleteSucursal(s.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280))),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = const Color(0xFF374151),
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}