import 'package:flutter/material.dart';
import '../../../utils/constants/sizes.dart';

class ModuleCard extends StatelessWidget {
  final String title;
  final String description;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  const ModuleCard({
    super.key,
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TSizes.cardRadiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TSizes.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: color.withValues(),
              child: Icon(
                icon,
                size: TSizes.iconXl,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: TSizes.fontSizeXl,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              description,
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: onPressed,
              child: const Text("Abrir Módulo"),
            ),
          ],
        ),
      ),
    );
  }
}