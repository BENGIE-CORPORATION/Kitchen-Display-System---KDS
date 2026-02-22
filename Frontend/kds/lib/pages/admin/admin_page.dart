import 'package:flutter/material.dart';
import '../../routes/routes.dart';
import 'widgets/sidebar/sidebar.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [

          // 🔹 SIDEBAR FIJO
          TSidebar(
            currentRoute: TRoutes.dashboard,
          ),

          // 🔹 CONTENIDO
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    const Text(
                      "ADMIN PANEL",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, TRoutes.home);
                      },
                      child: const Text("Volver a Home"),
                    ),

                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          TRoutes.login,
                          (route) => false,
                        );
                      },
                      child: const Text("Cerrar sesión"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}