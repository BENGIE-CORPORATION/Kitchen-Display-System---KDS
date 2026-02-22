import 'package:flutter/material.dart';
import '../../routes/routes.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "LOGIN PAGE",
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, TRoutes.home);
              },
              child: const Text("Ir a Home"),
            ),
          ],
        ),
      ),
    );
  }
}