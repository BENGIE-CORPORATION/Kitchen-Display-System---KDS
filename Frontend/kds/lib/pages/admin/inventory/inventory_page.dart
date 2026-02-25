import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Hola, estás en Inventory",
        style: TextStyle(fontSize: TSizes.fontSizeLg),
      ),
    );
  }
}