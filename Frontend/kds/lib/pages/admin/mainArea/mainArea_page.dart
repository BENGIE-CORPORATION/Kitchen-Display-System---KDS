import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class MainAreaPage extends StatelessWidget {
  const MainAreaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Hola, estás en MainArea",
        style: TextStyle(fontSize: TSizes.fontSizeLg),
      ),
    );
  }
}