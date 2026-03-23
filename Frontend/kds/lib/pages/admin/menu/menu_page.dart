import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Hola, estás en Menu",
        style: TextStyle(fontSize: TSizes.fontSizeLg),
      ),
    );
  }
}