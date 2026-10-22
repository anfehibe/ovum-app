import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../data/providers/favorites_provider.dart';

/// Botón de favorito (corazón) que sincroniza con [favoritesProvider].
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.kind,
    required this.id,
    this.onSurface = false,
  });

  final FavKind kind;
  final String id;

  /// true cuando va sobre una imagen/hero (usa fondo translúcido).
  final bool onSurface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(isFavoriteProvider((kind: kind, id: id)));
    const favColor = Color(0xFFE23A57);

    final icon = Icon(
      isFav ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
      color: isFav ? favColor : (onSurface ? Colors.white : null),
    );

    final button = IconButton(
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(kind, id),
      tooltip: isFav ? context.l10n.widgetRemoveFavorite : context.l10n.widgetAddFavorite,
      icon: icon,
    );

    if (!onSurface) return button;
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: button,
    );
  }
}
