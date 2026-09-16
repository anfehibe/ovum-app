import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/router/route_paths.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/networking_provider.dart';
import '../widgets/networking_card_tile.dart';
import 'networking_tab_error.dart';

/// Asistentes guardados. Vive en el servidor, así que se comparte entre
/// dispositivos y con el web del congreso.
class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sube los favoritos locales de asistentes la primera vez (silenciosa).
    ref.watch(networkingFavoritesMigrationProvider);
    final async = ref.watch(serverFavoritesProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => NetworkingTabError(error: e),
      data: (cards) => RefreshIndicator(
        onRefresh: () => ref.refresh(serverFavoritesProvider.future),
        child: cards.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    message:
                        'Aún no has guardado a nadie.\nToca el corazón en el directorio.',
                    icon: PhosphorIconsRegular.heart,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => NetworkingCardTile(
                  card: cards[i],
                  onTap: () => context.push(R.networkingAttendee(cards[i].id)),
                ),
              ),
      ),
    );
  }
}
