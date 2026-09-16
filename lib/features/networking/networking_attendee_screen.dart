import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/models/networking_card.dart';
import '../../data/providers/networking_provider.dart';

/// Ficha de un asistente del networking (`/networking/attendee/:id`).
class NetworkingAttendeeScreen extends ConsumerWidget {
  const NetworkingAttendeeScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkingAttendeeProvider(userId));
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: _errorMessage(e)),
        data: (card) => _content(context, ref, card),
      ),
    );
  }

  String _errorMessage(Object e) {
    if (e is ApiException) {
      if (e.isNotFound) return 'Ese asistente ya no participa en el networking.';
      return e.message;
    }
    return 'No se pudo cargar la ficha.';
  }

  Widget _content(BuildContext context, WidgetRef ref, NetworkingCard card) {
    final scheme = context.scheme;
    final isFavorite = ref.watch(isNetworkingFavoriteProvider(card));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialsAvatar(name: card.name, imageUrl: card.photoUrl, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name, style: Theme.of(context).textTheme.titleLarge),
                  if (card.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  if (card.country.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(PhosphorIconsRegular.mapPin,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          card.country,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
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
                    const SnackBar(
                      content: Text('No se pudo actualizar el favorito.'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        if (card.bio.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('Sobre', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(card.bio, style: Theme.of(context).textTheme.bodyMedium),
        ],
        _chips(context, 'Sectores', card.sectors),
        _chips(context, 'Intereses', card.interests),
        _chips(context, 'Busca', card.seeking),
        _chips(context, 'Ofrece', card.solutions),
        _chips(context, 'Regiones', card.regions),
        const SizedBox(height: 26),
        FilledButton.icon(
          onPressed: () => context.push(R.chatWith(card.id)),
          icon: const Icon(PhosphorIconsRegular.chatCircleText, size: 18),
          label: const Text('Enviar mensaje'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.push(R.meetingWith(card.id)),
          icon: const Icon(PhosphorIconsRegular.calendarPlus, size: 18),
          label: const Text('Solicitar reunión'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
        if (card.linkedin != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => openUrl(card.linkedin!),
            icon: const Icon(PhosphorIconsFill.linkedinLogo, size: 18),
            label: const Text('LinkedIn'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ],
      ],
    );
  }

  Widget _chips(BuildContext context, String title, List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final v in values) CategoryChip(label: v)],
          ),
        ],
      ),
    );
  }
}
