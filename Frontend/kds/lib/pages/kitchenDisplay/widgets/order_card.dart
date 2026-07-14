import 'package:flutter/material.dart';
import '../../../common/models/pedido_models.dart';
import '../../../common/models/mesa_models.dart';
import '../../../common/services/producto_catalog_service.dart';
import '../../../common/widgets/status_badge.dart';

const _kUmbralAlertaMinutos = 20;

const _labelsTipoPedido = {
  'mesa': 'Mesa',
  'mostrador': 'Mostrador',
  'para_llevar': 'Para llevar',
  'domicilio': 'Domicilio',
};

class OrderCard extends StatelessWidget {
  final PedidoReadDetalle pedido;
  final MesaRead? mesa;
  final ProductoNombreResolver? resolver;
  final String? nextActionLabel;
  final VoidCallback? onAction;

  const OrderCard({
    super.key,
    required this.pedido,
    this.mesa,
    this.resolver,
    this.nextActionLabel,
    this.onAction,
  });

  Duration get _transcurrido =>
      DateTime.now().difference(pedido.fechaPedido ?? DateTime.now());

  bool get _enAlerta => _transcurrido.inMinutes >= _kUmbralAlertaMinutos;

  String get _titulo => mesa != null
      ? 'Mesa ${mesa!.numero}'
      : (_labelsTipoPedido[pedido.tipoPedido] ?? pedido.tipoPedido);

  @override
  Widget build(BuildContext context) {
    final items = pedido.items.where((i) => !i.cancelado).toList();
    final alertColor = const Color(0xFFDC2626);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _enAlerta ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(_titulo,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                    const SizedBox(width: 8),
                    StatusBadge.pedidoEstado(pedido.estado),
                  ],
                ),
              ),
              Row(
                children: [
                  if (_enAlerta)
                    Icon(Icons.error_outline, size: 16, color: alertColor),
                  if (_enAlerta) const SizedBox(width: 2),
                  Icon(Icons.access_time,
                      size: 16,
                      color: _enAlerta ? alertColor : const Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text('${_transcurrido.inMinutes} min',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _enAlerta ? alertColor : const Color(0xFF6B7280))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Pedido #${pedido.numeroPedido}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 12),

          ...items.map((item) => _ItemRow(item: item, resolver: resolver)),

          const SizedBox(height: 12),
          if (onAction != null && nextActionLabel != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pedido.estado == 'listo'
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFF111827),
                  foregroundColor: pedido.estado == 'listo'
                      ? const Color(0xFF111827)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(nextActionLabel!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final DetallePedidoRead item;
  final ProductoNombreResolver? resolver;

  const _ItemRow({required this.item, this.resolver});

  @override
  Widget build(BuildContext context) {
    final nombre = resolver?.nombreDe(item.productoId) ?? 'Producto';
    final cantidad = item.cantidad % 1 == 0
        ? item.cantidad.toInt().toString()
        : item.cantidad.toString();
    final modificadores = <String>[
      ...?item.variantesSeleccionadas?.values.map((v) => v.toString()),
      if (item.notas != null && item.notas!.trim().isNotEmpty) item.notas!.trim(),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('$cantidad× $nombre',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827))),
              ),
              Text('×$cantidad',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7280))),
            ],
          ),
          for (final mod in modificadores)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    width: 2,
                    height: 14,
                    color: const Color(0xFFD1D5DB),
                    margin: const EdgeInsets.only(right: 8),
                  ),
                  Text('+ $mod',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
