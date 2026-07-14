import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/models/mesa_models.dart';
import '../../common/providers/auth_provider.dart';
import 'pedido/pedido_builder_page.dart';
import 'pedido/pedido_builder_provider.dart';
import 'salon/salon_page.dart';
import 'salon/salon_provider.dart';

/// Punto de entrada de la ruta /employee. Maneja la navegación interna
/// entre el Salón y el constructor de pedido de una mesa (sin sub-rutas,
/// como los diálogos del panel de admin).
class EmployeeAppPage extends StatefulWidget {
  const EmployeeAppPage({super.key});

  @override
  State<EmployeeAppPage> createState() => _EmployeeAppPageState();
}

class _EmployeeAppPageState extends State<EmployeeAppPage> {
  late final SalonProvider _salonProvider;
  PedidoBuilderProvider? _builderProvider;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final auth = context.read<AuthProvider>();
      _salonProvider = SalonProvider()
        ..init(auth)
        ..load();
    }
  }

  Future<void> _onMesaTap(MesaRead mesa) async {
    if (mesa.reservada) {
      _mensaje('Mesa reservada. Confírmala antes de tomar el pedido.');
      return;
    }
    if (mesa.fueraDeServicio) {
      _mensaje('Mesa fuera de servicio.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final builder = PedidoBuilderProvider(mesa: mesa);
    setState(() => _builderProvider = builder);
    await builder.cargar(auth);
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto)));
  }

  void _volverAlSalon() {
    setState(() => _builderProvider = null);
    _salonProvider.reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_builderProvider != null) {
      return PedidoBuilderPage(
        provider: _builderProvider!,
        onBack: _volverAlSalon,
        onFacturado: _volverAlSalon,
      );
    }

    return ChangeNotifierProvider.value(
      value: _salonProvider,
      child: Consumer<SalonProvider>(
        builder: (context, provider, _) => SalonPage(
          provider: provider,
          onMesaTap: _onMesaTap,
        ),
      ),
    );
  }
}
