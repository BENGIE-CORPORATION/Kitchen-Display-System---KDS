import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Hola, estás en Sales",
        style: TextStyle(fontSize: TSizes.fontSizeLg),
      ),
    );
  }
}