import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/favorites_provider.dart';
import '../widgets/session_tile.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);

    final sessions = ref.watch(sessionsProvider).valueOrNull ?? const [];
    final speakers = ref.watch(speakersProvider).valueOrNull ?? const [];
    final sponsors = ref.watch(sponsorsProvider).valueOrNull ?? const [];
    final attendees = ref.watch(attendeesProvider).valueOrNull ?? const [];
    final exhibitors = ref.watch(exhibitorsProvider).valueOrNull ?? const [];

    bool has(FavKind k, String id) => favs.contains(favKey(k, id));

    final favSessions = sessions.where((s) => has(FavKind.session, s.id)).toList();
    final favSpeakers = speakers.where((s) => has(FavKind.speaker, s.id)).toList();
    final favSponsors = sponsors.where((s) => has(FavKind.sponsor, s.id)).toList();
    final favAttendees = attendees.where((a) => has(FavKind.attendee, a.id)).toList();
    final favExhibitors = exhibitors.where((e) => has(FavKind.exhibitor, e.id)).toList();

    final isEmpty = favs.isEmpty ||
        (favSessions.isEmpty &&
            favSpeakers.isEmpty &&
            favSponsors.isEmpty &&
            favAttendees.isEmpty &&
            favExhibitors.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.favorites)),
      body: isEmpty
          ? const EmptyState(
              message: 'Aún no tienes favoritos.\nToca el corazón para guardar lo que te interese.',
              icon: PhosphorIconsRegular.heart,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                if (favSessions.isNotEmpty) ...[
                  _header(context, 'Sesiones'),
                  for (final s in favSessions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SessionTile(session: s, onTap: () => context.push(R.session(s.id))),
                    ),
                ],
                if (favSpeakers.isNotEmpty) ...[
                  _header(context, AppStrings.speakers),
                  for (final s in favSpeakers)
                    _FavTile(
                      name: s.name,
                      subtitle: s.role,
                      photoUrl: s.photoUrl,
                      onTap: () => context.push(R.speaker(s.id)),
                    ),
                ],
                if (favSponsors.isNotEmpty) ...[
                  _header(context, AppStrings.sponsors),
                  for (final s in favSponsors)
                    _FavTile(
                      name: s.name,
                      subtitle: 'Patrocinador ${s.tier.label}',
                      photoUrl: s.logoUrl,
                      onTap: () => context.push(R.sponsor(s.id)),
                    ),
                ],
                if (favExhibitors.isNotEmpty) ...[
                  _header(context, AppStrings.exhibitors),
                  for (final e in favExhibitors)
                    _FavTile(
                      name: e.name,
                      subtitle: e.category,
                      photoUrl: e.logoUrl,
                      onTap: () => context.push(R.exhibitor(e.id)),
                    ),
                ],
                if (favAttendees.isNotEmpty) ...[
                  _header(context, AppStrings.attendees),
                  for (final a in favAttendees)
                    _FavTile(
                      name: a.name,
                      subtitle: '${a.position} · ${a.company}',
                      photoUrl: a.photoUrl,
                      onTap: () => context.push(R.attendee(a.id)),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _header(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _FavTile extends StatelessWidget {
  const _FavTile({
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.photoUrl,
  });
  final String name;
  final String subtitle;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                InitialsAvatar(name: name, imageUrl: photoUrl, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleSmall),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(PhosphorIconsRegular.caretRight, size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
