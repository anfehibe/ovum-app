import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/favorite_button.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/favorites_provider.dart';
import '../widgets/social_row.dart';

class AttendeeDetailScreen extends ConsumerWidget {
  const AttendeeDetailScreen({super.key, required this.attendeeId});
  final String attendeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendee = ref.watch(attendeeByIdProvider(attendeeId));
    if (attendee == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(message: 'Asistente no encontrado'));
    }
    final scheme = context.scheme;
    final location =
        [attendee.city, attendee.country].where((s) => s.isNotEmpty).join(', ');

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 4, 12, 26),
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
                    FavoriteButton(kind: FavKind.attendee, id: attendee.id, onSurface: true),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: InitialsAvatar(name: attendee.name, imageUrl: attendee.photoUrl, size: 96),
                ),
                const SizedBox(height: 12),
                Text(attendee.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                Text('${attendee.position} · ${attendee.company}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _actionsRow(context),
                const SizedBox(height: 20),
                if (attendee.sector.isNotEmpty)
                  _metaRow(context, PhosphorIconsRegular.briefcase, attendee.sector),
                if (location.isNotEmpty)
                  _metaRow(context, PhosphorIconsRegular.mapPin, location),
                if (attendee.bio.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Biografía', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(attendee.bio, style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (attendee.interests.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Intereses', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _chips(context, attendee.interests, scheme.primary),
                ],
                if (attendee.services.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Servicios que ofrece', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _chips(context, attendee.services, scheme.tertiary),
                ],
                if (attendee.socials.hasAny) ...[
                  const SizedBox(height: 20),
                  SocialRow(socials: attendee.socials),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(R.chatWith(attendeeId)),
            icon: const Icon(PhosphorIconsRegular.chatCircleText, size: 18),
            label: const Text(AppStrings.message),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(R.meetingWith(attendeeId)),
            icon: const Icon(PhosphorIconsRegular.handshake, size: 18),
            label: const Text(AppStrings.meeting),
          ),
        ),
      ],
    );
  }

  Widget _metaRow(BuildContext context, IconData icon, String text) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _chips(BuildContext context, List<String> items, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(item,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}
