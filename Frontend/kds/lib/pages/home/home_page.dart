import 'package:flutter/material.dart';
import '../../routes/routes.dart';

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
              padding: const EdgeInsets.all(40),
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

                      _moduleCard(
                        title: "App de Empleados",
                        description: "Gestión de mesas, pedidos y pagos",
                        color: Colors.blue,
                        icon: Icons.tablet,
                        onPressed: () {
                          Navigator.pushNamed(
                              context, TRoutes.employee);
                        },
                      ),

                      _moduleCard(
                        title: "Kitchen Display",
                        description: "Sistema para cocina",
                        color: Colors.orange,
                        icon: Icons.restaurant,
                        onPressed: () {
                          Navigator.pushNamed(
                              context, TRoutes.kitchendisplay);
                        },
                      ),

                      _moduleCard(
                        title: "Administración",
                        description:
                            "Dashboard, inventario y configuración",
                        color: Colors.purple,
                        icon: Icons.dashboard,
                        onPressed: () {
                          Navigator.pushNamed(
                              context, TRoutes.admin);
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

  Widget _moduleCard({
    required String title,
    required String description,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: color.withValues(),
              child: Icon(
                icon,
                size: 40,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              description,
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: onPressed,
              child: const Text("Abrir Módulo"),
            )
          ],
        ),
      ),
    );
  }
}