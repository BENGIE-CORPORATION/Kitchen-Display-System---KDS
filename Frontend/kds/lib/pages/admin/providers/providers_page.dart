import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class ProvidersPage extends StatelessWidget {
  const ProvidersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Hola, estás en Providers",
        style: TextStyle(fontSize: TSizes.fontSizeLg),
      ),
    );
  }
}