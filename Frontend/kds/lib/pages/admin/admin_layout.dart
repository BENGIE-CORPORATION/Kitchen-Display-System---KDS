import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/sidebar/sidebar.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;

  const AdminLayout({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {

    // Ruta actual desde GoRouter
    final String currentRoute = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: Row(
        children: [

          /// SIDEBAR
          TSidebar(
            currentRoute: currentRoute,
          ),

          /// CONTENIDO DINÁMICO
          Expanded(
            child: Container(
              // key: ValueKey(GoRouterState.of(context).uri.toString()), // se intentó estos dos cosos para evitar que se vea el traslape/lag entre cambio de paginas del sidebar
              // color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}