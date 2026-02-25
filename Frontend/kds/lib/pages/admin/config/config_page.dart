import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Hola, estás en Config",
        style: TextStyle(fontSize: TSizes.fontSizeLg),
      ),
    );
  }
}