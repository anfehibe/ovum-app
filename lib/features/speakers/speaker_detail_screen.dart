import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/favorite_button.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/favorites_provider.dart';
import '../widgets/session_tile.dart';
import '../widgets/social_row.dart';

class SpeakerDetailScreen extends ConsumerWidget {
  const SpeakerDetailScreen({super.key, required this.speakerId});
  final String speakerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speaker = ref.watch(speakerByIdProvider(speakerId));
    if (speaker == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(message: 'Conferencista no encontrado'));
    }
    final scheme = context.scheme;
    final sessions = ref.watch(sessionsForSpeakerProvider(speakerId));

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            name: speaker.name,
            role: speaker.role,
            company: speaker.company,
            photoUrl: speaker.photoUrl,
            isKeynote: speaker.isKeynote,
            favorite: FavoriteButton(kind: FavKind.speaker, id: speaker.id, onSurface: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (speaker.socials.hasAny) ...[
                  SocialRow(socials: speaker.socials),
                  const SizedBox(height: 20),
                ],
                if (speaker.bio.isNotEmpty) ...[
                  Text('Biografía', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(speaker.bio, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                ],
                if (sessions.isNotEmpty) ...[
                  Text('Sus sesiones', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final s in sessions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SessionTile(
                        session: s,
                        onTap: () => context.push(R.session(s.id)),
                      ),
                    ),
                ] else
                  Text(
                    'Este conferencista aún no tiene sesiones publicadas.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.role,
    required this.company,
    required this.photoUrl,
    required this.isKeynote,
    required this.favorite,
  });

  final String name;
  final String role;
  final String company;
  final String? photoUrl;
  final bool isKeynote;
  final Widget favorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 4, 12, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6C453), BrandColors.yolk, BrandColors.sunrise],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(PhosphorIconsRegular.caretLeft, color: Colors.white),
              ),
              const Spacer(),
              favorite,
            ],
          ),
          const SizedBox(height: 4),
          Container(
            decoration: const BoxDecoration(shape: BoxShape.circle),
            padding: const EdgeInsets.all(3),
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: InitialsAvatar(name: name, imageUrl: photoUrl, size: 104),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            role,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white),
          ),
          Text(
            company,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          if (isKeynote) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIconsFill.star, size: 13, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Conferencista magistral',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
