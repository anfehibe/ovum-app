import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marca "huevo" (óvalo con degradado cálido). Placeholder de identidad —
/// sustituir por el logo oficial de OVUM cuando esté disponible.
class OvumEggMark extends StatelessWidget {
  const OvumEggMark({super.key, this.size = 72, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6C453), BrandColors.yolk, BrandColors.sunrise],
        ),
        borderRadius: BorderRadius.all(Radius.elliptical(size, size * 1.28)),
        boxShadow: [
          BoxShadow(
            color: BrandColors.yolk.withValues(alpha: onDark ? 0.35 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.3, -0.4),
        child: Container(
          width: size * 0.26,
          height: size * 0.3,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.all(Radius.elliptical(size * 0.26, size * 0.3)),
          ),
        ),
      ),
    );
  }
}

/// Logo completo: marca + wordmark "OVUM 2026".
class OvumLogo extends StatelessWidget {
  const OvumLogo({super.key, this.markSize = 72, this.onDark = false});

  final double markSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : context.scheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OvumEggMark(size: markSize, onDark: onDark),
        const SizedBox(height: 16),
        Text(
          'OVUM',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
        ),
        Text(
          '2026',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: onDark ? Colors.white70 : context.scheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
        ),
      ],
    );
  }
}
