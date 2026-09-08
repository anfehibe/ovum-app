import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo de patrocinador sobre una tarjeta blanca redondeada.
///
/// A diferencia de un avatar circular, muestra el logotipo **completo**
/// (`BoxFit.contain`) con margen interno, de modo que los logos anchos no se
/// recorten. Si no hay logo (o falla la carga) cae a las iniciales del nombre.
class SponsorLogo extends StatelessWidget {
  const SponsorLogo({
    super.key,
    required this.name,
    this.logoUrl,
    this.radius = 14,
    this.padding = 10,
  });

  final String name;
  final String? logoUrl;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0x14000000)),
      ),
      padding: EdgeInsets.all(padding),
      alignment: Alignment.center,
      child: hasLogo
          ? CachedNetworkImage(
              imageUrl: logoUrl!,
              fit: BoxFit.contain,
              placeholder: (_, _) => _initials(context),
              errorWidget: (_, _, _) => _initials(context),
            )
          : _initials(context),
    );
  }

  Widget _initials(BuildContext context) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final String initials;
    if (parts.isEmpty) {
      initials = '?';
    } else if (parts.length == 1) {
      final p = parts.first;
      initials = (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    } else {
      initials =
          (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
    }
    final colors = context.ovum.categoryColors;
    final color = colors[name.hashCode.abs() % colors.length];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 28,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
