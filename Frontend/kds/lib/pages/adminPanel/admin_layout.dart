import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/sidebar/sidebar.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;

  const AdminLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          TSidebar(
            currentRoute: GoRouterState.of(context).uri.toString(),
          ),

          Expanded(
            child: Container(
              key: ValueKey(GoRouterState.of(context).uri.toString()),
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}