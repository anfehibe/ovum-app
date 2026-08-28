import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const _trackOrder = [
  'Plenaria',
  'Nutrición',
  'Sanidad',
  'Genética',
  'Mercados',
  'Bienestar',
  'Sostenibilidad',
  'Tecnología',
  'Social',
  'General',
];

/// Color estable asignado a un track temático.
Color trackColor(BuildContext context, String track) {
  final colors = context.ovum.categoryColors;
  final index = _trackOrder.indexOf(track);
  return colors[(index < 0 ? track.hashCode.abs() : index) % colors.length];
}

/// Etiqueta tipo pill coloreada por categoría/track.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? trackColor(context, label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
