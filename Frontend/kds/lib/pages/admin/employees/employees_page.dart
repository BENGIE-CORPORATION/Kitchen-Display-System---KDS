import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Hola, estás en Employees",
        style: TextStyle(fontSize: TSizes.fontSizeLg),
      ),
    );
  }
}