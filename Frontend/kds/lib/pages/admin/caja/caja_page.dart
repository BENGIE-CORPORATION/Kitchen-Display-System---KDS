import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class CajaPage extends StatelessWidget {
  const CajaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Hola, estás en Caja",
        style: TextStyle(fontSize: TSizes.fontSizeLg),
      ),
    );
  }
}