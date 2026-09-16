import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../data/models/networking_card.dart';
import '../../data/providers/networking_provider.dart';

/// Fila de un asistente en el directorio / favoritos de networking.
class NetworkingCardTile extends ConsumerWidget {
  const NetworkingCardTile({
    super.key,
    required this.card,
    this.onTap,
    this.showFavorite = true,
  });

  final NetworkingCard card;
  final VoidCallback? onTap;
  final bool showFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final sectors = card.sectors.take(2).toList();

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(name: card.name, imageUrl: card.photoUrl, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (card.subtitle.isNotEmpty)
                      Text(
                        card.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    if (sectors.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in sectors)
                            CategoryChip(label: s, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (showFavorite) _FavoriteHeart(card: card),
            ],
          ),
        ),
      ),
    );
  }
}

/// Corazón con toggle optimista: se invierte al instante y revierte si el
/// servidor falla.
class _FavoriteHeart extends ConsumerWidget {
  const _FavoriteHeart({required this.card});

  final NetworkingCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isNetworkingFavoriteProvider(card));
    final scheme = context.scheme;
    return IconButton(
      tooltip: isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
      icon: Icon(
        isFavorite ? PhosphorIconsFill.heart : PhosphorIconsRegular.heart,
        color: isFavorite ? scheme.error : scheme.onSurfaceVariant,
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref
              .read(networkingFavoritesProvider.notifier)
              .toggle(card.id, isFavorite);
        } catch (_) {
          messenger.showSnackBar(
            const SnackBar(content: Text('No se pudo actualizar el favorito.')),
          );
        }
      },
    );
  }
}
