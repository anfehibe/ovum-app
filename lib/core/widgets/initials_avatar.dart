import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'fullscreen_image_viewer.dart';

/// Avatar con foto (si existe) o iniciales sobre un color derivado del nombre.
///
/// Con [zoomable] en `true`, y solo cuando hay foto, al tocarlo se abre la
/// imagen a pantalla completa con pinch-zoom. Se deja en `false` por defecto
/// para no robarle el gesto a las filas de lista, que ya navegan al tocarlas;
/// se activa en las fotos de perfil destacadas (cabeceras de detalle).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
    this.zoomable = false,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool zoomable;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imageUrl != null && imageUrl!.isNotEmpty;
    if (!hasPhoto) return _fallback(context);

    final avatar = ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => _fallback(context),
        errorWidget: (_, _, _) => _fallback(context),
      ),
    );

    if (!zoomable) return avatar;

    // Solo las fotos reales se amplían (no las iniciales). Semantics describe el
    // gesto para lectores de pantalla.
    return Semantics(
      button: true,
      label: context.l10n.zoomPhoto,
      child: GestureDetector(
        onTap: () => showFullscreenImage(context, imageUrl!),
        child: avatar,
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final colors = context.ovum.categoryColors;
    final color = colors[name.hashCode.abs() % colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
