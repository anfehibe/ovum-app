import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/content_providers.dart';

/// Muestra el banner del congreso (splash `order:2`) como header, a ancho completo
/// y con alto proporcional (la imagen tiene dimensiones variables). Si no hay banner
/// disponible (API vacío/error/aún cargando) muestra [fallback], sin romper la pantalla.
class EventHeaderBanner extends ConsumerWidget {
  const EventHeaderBanner({super.key, required this.fallback, this.borderRadius});

  final Widget fallback;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(headerBannerProvider);
    if (url == null || url.isEmpty) return fallback;

    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
