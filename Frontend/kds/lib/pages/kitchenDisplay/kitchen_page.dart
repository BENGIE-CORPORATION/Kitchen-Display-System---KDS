import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../common/providers/auth_provider.dart';
import '../../common/widgets/sucursal_selector.dart';
import '../../routes/routes.dart';
import 'kitchen_provider.dart';
import 'widgets/order_card.dart';

/// Punto de entrada de la ruta /kitchendisplay — crea e inicializa el
/// provider (con polling) y maneja los estados de carga/error.
class KitchenDisplayPage extends StatelessWidget {
  const KitchenDisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return ChangeNotifierProvider(
      create: (_) => KitchenProvider()
        ..init(auth)
        ..start(),
      child: const _KitchenBoard(),
    );
  }
}

const _filtros = [
  ('todos', 'Todos'),
  ('abierto', 'Nuevos'),
  ('en_preparacion', 'En preparación'),
  ('listo', 'Listos'),
];

class _KitchenBoard extends StatelessWidget {
  const _KitchenBoard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KitchenProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(provider: provider),
              const SizedBox(height: 16),
              _FilterRow(provider: provider),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 16),
              Expanded(child: _Board(provider: provider)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final KitchenProvider provider;
  const _Header({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => context.go(TRoutes.home),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.restaurant, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kitchen Display',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827))),
            Text('Sistema de cocina',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
        const Spacer(),
        _CountStat(value: provider.countNuevos, label: 'Nuevos'),
        const SizedBox(width: 24),
        _CountStat(value: provider.countEnPreparacion, label: 'En preparación'),
        const SizedBox(width: 24),
        _CountStat(value: provider.countListos, label: 'Listos'),
        const SizedBox(width: 24),
        const SucursalSelector(),
      ],
    );
  }
}

class _CountStat extends StatelessWidget {
  final int value;
  final String label;
  const _CountStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$value',
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827))),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  final KitchenProvider provider;
  const _FilterRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in _filtros) ...[
            _FilterChip(
              label: f.$1 == 'todos'
                  ? f.$2
                  : '${f.$2} (${_countFor(provider, f.$1)})',
              selected: provider.filtro == f.$1,
              onTap: () => provider.setFiltro(f.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  int _countFor(KitchenProvider p, String estado) {
    switch (estado) {
      case 'abierto':
        return p.countNuevos;
      case 'en_preparacion':
        return p.countEnPreparacion;
      case 'listo':
        return p.countListos;
      default:
        return p.pedidos.length;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? const Color(0xFF111827) : const Color(0xFFD1D5DB)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF374151))),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  final KitchenProvider provider;
  const _Board({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.pedidos.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }
    if (provider.error != null && provider.pedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 40),
            const SizedBox(height: 8),
            Text(provider.error!,
                style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: provider.refreshAhora,
                child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final pedidos = provider.pedidosFiltrados;
    if (pedidos.isEmpty) {
      return const Center(
        child: Text('No hay pedidos en este filtro',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 1200
          ? 3
          : constraints.maxWidth > 750
              ? 2
              : 1;
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.85,
        ),
        itemCount: pedidos.length,
        itemBuilder: (_, i) {
          final pedido = pedidos[i];
          final siguiente = provider.siguienteEstado(pedido.estado);
          return OrderCard(
            pedido: pedido,
            mesa: pedido.mesaId != null ? provider.mesasPorId[pedido.mesaId] : null,
            resolver: provider.resolver,
            nextActionLabel: switch (siguiente) {
              'en_preparacion' => 'Comenzar preparación',
              'listo' => 'Marcar Listo',
              'entregado' => 'Entregado',
              _ => null,
            },
            onAction:
                siguiente == null ? null : () => provider.avanzarEstado(pedido),
          );
        },
      );
    });
  }
}
