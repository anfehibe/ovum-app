import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/ovum_event.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/favorite_button.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/favorites_provider.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionByIdProvider(sessionId));
    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(message: 'Sesión no encontrada'),
      );
    }
    final scheme = context.scheme;
    final color = trackColor(context, session.track);
    final speakers = ref.watch(speakersForSessionProvider(sessionId));
    // La entrada a encuestas es data-driven: el API de agenda no trae has_polls.
    final hasPolls = ref.watch(pollsForSessionProvider(sessionId)).isNotEmpty;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            color: color,
            track: session.track,
            title: session.title,
            time: '${session.startDate.fullDate} · ${timeRange(session.startDate, session.endDate)}',
            room: session.room,
            favorite: FavoriteButton(kind: FavKind.session, id: session.id, onSurface: true),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _actionRow(context, session),
                if (session.description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(session.description, style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (session.sponsorName != null) ...[
                  const SizedBox(height: 20),
                  _sponsorCard(context, session.sponsorName!),
                ],
                if (speakers.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(AppStrings.speakers, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final s in speakers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _speakerTile(context, s.id, s.name, s.role, s.photoUrl),
                    ),
                ],
                if (session.hasQuestions || hasPolls) ...[
                  const SizedBox(height: 24),
                  Text('Participa', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (session.hasQuestions)
                    _participateTile(
                      context,
                      icon: PhosphorIconsRegular.chatCircleText,
                      color: color,
                      title: AppStrings.liveQuestions,
                      subtitle: 'Envía tu pregunta al panel',
                      onTap: () => context.push(R.liveQuestionsFor(session.id)),
                    ),
                  if (hasPolls)
                    _participateTile(
                      context,
                      icon: PhosphorIconsRegular.chartBar,
                      color: scheme.tertiary,
                      title: AppStrings.polls,
                      subtitle: 'Responde la encuesta en vivo',
                      onTap: () => context.push(R.pollsFor(session.id)),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(BuildContext context, Session session) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => addToCalendar(
              title: session.title,
              description: session.description,
              location: session.room.isNotEmpty ? session.room : OvumEvent.mainVenue,
              start: session.startDate,
              end: session.endDate,
            ),
            icon: const Icon(PhosphorIconsRegular.calendarPlus, size: 18),
            label: const Text('Calendario'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => shareText('${session.title} · OVUM 2026'),
            icon: const Icon(PhosphorIconsRegular.shareNetwork, size: 18),
            label: const Text('Compartir'),
          ),
        ),
      ],
    );
  }

  Widget _sponsorCard(BuildContext context, String name) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          InitialsAvatar(name: name, size: 40),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patrocinado por',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              Text(name, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _speakerTile(BuildContext context, String id, String name, String role, String? photo) {
    final scheme = context.scheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(R.speaker(id)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              InitialsAvatar(name: name, imageUrl: photo, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    Text(role,
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
    );
  }

  Widget _participateTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      Text(subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(PhosphorIconsRegular.caretRight, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header degradado reutilizable para pantallas de detalle.
class _Header extends StatelessWidget {
  const _Header({
    required this.color,
    required this.track,
    required this.title,
    required this.time,
    required this.room,
    this.favorite,
  });

  final Color color;
  final String track;
  final String title;
  final String time;
  final String room;
  final Widget? favorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 4, 12, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.28)!],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(PhosphorIconsRegular.caretLeft, color: Colors.white),
              ),
              const Spacer(),
              ?favorite,
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(track.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          )),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _headerRow(context, PhosphorIconsRegular.clock, time),
                if (room.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _headerRow(context, PhosphorIconsRegular.mapPin, room),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
