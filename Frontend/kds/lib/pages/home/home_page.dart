import 'package:flutter/material.dart';
import '../../routes/routes.dart';
import 'widgets/module_card.dart';
import '../../utils/constants/sizes.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          int columns = constraints.maxWidth > 900 ? 3 : 1;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(TSizes.xxl),
              child: Column(
                children: [
                  const Text(
                    "Sistema POS para Restaurantes",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Seleccione el módulo que desea visualizar",
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 60),

                  GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: 0.8,
                    children: [
                      ModuleCard(
                        title: "App de Empleados",
                        description:
                            "Gestión de mesas, pedidos y pagos",
                        color: Colors.blue,
                        icon: Icons.tablet,
                        onPressed: () {
                          context.go(TRoutes.employee);
                        },
                      ),
                      ModuleCard(
                        title: "Kitchen Display",
                        description: "Sistema para cocina",
                        color: Colors.orange,
                        icon: Icons.restaurant,
                        onPressed: () {
                          context.go(TRoutes.kitchendisplay);
                          },
                      ),
                      ModuleCard(
                        title: "Administración",
                        description:
                            "Dashboard, inventario y configuración",
                        color: Colors.purple,
                        icon: Icons.dashboard,
                        onPressed: () {
                          context.go(TRoutes.admin);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}