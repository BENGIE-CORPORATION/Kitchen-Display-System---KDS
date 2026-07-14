import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/models/mesa_models.dart';
import '../../../common/widgets/sucursal_selector.dart';
import '../../../routes/routes.dart';
import 'salon_provider.dart';
import 'widgets/mesa_card.dart';

/// Vista de Salón — grid de mesas reales de la sucursal.
class SalonPage extends StatelessWidget {
  final SalonProvider provider;
  final ValueChanged<MesaRead> onMesaTap;

  const SalonPage({super.key, required this.provider, required this.onMesaTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: provider.reload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go(TRoutes.home),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('App de Empleados — Salón',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        Text(
                            '${provider.ocupadas} de ${provider.mesas.length} mesas ocupadas',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  const SucursalSelector(),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: provider.reload,
                    icon: const Icon(Icons.refresh, color: Color(0xFF374151)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(provider.error!,
                      style: const TextStyle(color: Color(0xFFDC2626))),
                ),
              if (provider.mesas.isEmpty && !provider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text('No hay mesas configuradas para esta sucursal',
                        style: TextStyle(color: Color(0xFF9CA3AF))),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 900
                        ? 4
                        : constraints.maxWidth > 600
                            ? 3
                            : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: provider.mesas.length,
                      itemBuilder: (_, i) {
                        final mesa = provider.mesas[i];
                        return MesaCard(
                          mesa: mesa,
                          onTap: () => onMesaTap(mesa),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
