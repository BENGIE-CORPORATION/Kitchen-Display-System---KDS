import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Hola, estás en Dashboard :)",
        style: TextStyle(fontSize: TSizes.fontSizeLg),
      ),
    );
  }
}