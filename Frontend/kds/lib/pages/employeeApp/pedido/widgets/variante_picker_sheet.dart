import 'package:flutter/material.dart';
import '../../../../common/models/producto_models.dart';

class VariantePickerResult {
  final List<VarianteRead> variantes;
  final String? notas;
  const VariantePickerResult({required this.variantes, this.notas});
}

/// Selector de modificadores (variantes de producto) + notas libres,
/// mostrado antes de agregar un producto con variantes al carrito.
Future<VariantePickerResult?> showVariantePicker(
  BuildContext context, {
  required String nombreProducto,
  required List<VarianteRead> variantes,
}) {
  final seleccionadas = <VarianteRead>{};
  final notasCtrl = TextEditingController();

  return showModalBottomSheet<VariantePickerResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombreProducto,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827))),
            const SizedBox(height: 4),
            const Text('Elige modificadores (opcional)',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            if (variantes.isNotEmpty)
              ...variantes.map((v) => CheckboxListTile(
                    value: seleccionadas.contains(v),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        seleccionadas.add(v);
                      } else {
                        seleccionadas.remove(v);
                      }
                    }),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(v.nombre, style: const TextStyle(fontSize: 14)),
                    subtitle: v.precioAdicional > 0
                        ? Text('+ ₡${v.precioAdicional.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280)))
                        : null,
                  )),
            const SizedBox(height: 8),
            TextField(
              controller: notasCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Notas (ej: sin cebolla, término medio...)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      VariantePickerResult(
                        variantes: seleccionadas.toList(),
                        notas: notasCtrl.text,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Agregar'),
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
