import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../ui/app_icons.dart';

/// Abre una imagen a pantalla completa con pinch-zoom y un botón para cerrar.
///
/// Patrón compartido por el visor de planos de Sedes y por el zoom de las fotos
/// de perfil (ver [InitialsAvatar] con `zoomable: true`).
void showFullscreenImage(BuildContext context, String imageUrl) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (ctx) => Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(ctx).top + 8,
          right: 8,
          child: IconButton(
            tooltip: ctx.l10n.close,
            onPressed: () => Navigator.of(ctx).pop(),
            icon: const Icon(PhosphorIconsRegular.x, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
          ),
        ),
      ],
    ),
  );
}
