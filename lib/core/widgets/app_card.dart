import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tarjeta con estética OVUM: borde fino, esquinas suaves, sin sombra pesada.
/// Opcionalmente tappable.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final radius = BorderRadius.circular(20);
    return Material(
      color: color ?? scheme.surfaceContainerLow,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
