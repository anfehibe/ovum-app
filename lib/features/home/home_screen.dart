import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/ovum_event.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/sponsor_logo.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/user_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HeroHeader()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _QuickAccess()),
          SliverToBoxAdapter(child: _AgendaHighlights()),
          SliverToBoxAdapter(child: _KeynotesRow()),
          SliverToBoxAdapter(child: _SponsorsRow()),
          const SliverToBoxAdapter(child: _HomeFooter()),
        ],
      ),
    );
  }
}

class _HeroHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannerUrl = ref.watch(headerBannerProvider);
    final header = (bannerUrl != null && bannerUrl.isNotEmpty)
        ? _banner(context, ref, bannerUrl)
        : _hero(context, ref);
    return header.animate().fadeIn(duration: 350.ms);
  }

  /// Header con el banner del congreso (splash order:2) + fila de saludo/countdown.
  Widget _banner(BuildContext context, WidgetRef ref, String url) {
    final theme = Theme.of(context);
    final firstName = (ref.watch(currentUserProvider)?.name ?? '').split(' ').first;
    final daysLeft = OvumEvent.startDate.difference(DateTime.now()).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner a ancho completo, debajo de la status bar (franja de marca detrás).
        Container(
          color: BrandColors.yolk,
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          child: CachedNetworkImage(
            imageUrl: url,
            width: double.infinity,
            fit: BoxFit.fitWidth,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  firstName.isEmpty ? '${AppStrings.welcome} OVUM 2026' : '¡Hola, $firstName!',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (daysLeft > 0) _countdownChip(context, daysLeft),
            ],
          ),
        ),
      ],
    );
  }

  Widget _countdownChip(BuildContext context, int daysLeft) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsRegular.clockCountdown, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            'Faltan $daysLeft días',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Hero de marca (fallback cuando aún no hay banner del API). Sin campana.
  Widget _hero(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firstName = (ref.watch(currentUserProvider)?.name ?? '').split(' ').first;
    final daysLeft = OvumEvent.startDate.difference(DateTime.now()).inDays;

    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName.isEmpty ? '${AppStrings.welcome} OVUM 2026' : '¡Hola, $firstName!',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(
            OvumEvent.name,
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            OvumEvent.edition,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(
                icon: PhosphorIconsRegular.calendarBlank,
                label:
                    '${OvumEvent.startDate.monthDayShort} – ${OvumEvent.endDate.monthDay} 2026',
              ),
              _HeroPill(
                icon: PhosphorIconsRegular.mapPin,
                label: 'Ciudad de Guatemala',
              ),
              if (daysLeft > 0)
                _HeroPill(
                  icon: PhosphorIconsRegular.clockCountdown,
                  label: 'Faltan $daysLeft días',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  static const _items = [
    (PhosphorIconsRegular.microphoneStage, AppStrings.speakers, R.speakers),
    (PhosphorIconsRegular.storefront, AppStrings.exhibitors, R.exhibitors),
    (PhosphorIconsRegular.medal, AppStrings.sponsors, R.sponsors),
    (PhosphorIconsRegular.confetti, AppStrings.otherActivities, R.otherActivities),
    (PhosphorIconsRegular.mapTrifold, AppStrings.venue, R.venues),
    (PhosphorIconsRegular.bed, AppStrings.hotels, R.hotels),
    (PhosphorIconsRegular.info, AppStrings.generalInfo, R.info),
    (PhosphorIconsRegular.buildings, AppStrings.organizers, R.organizers),
  ];

  @override
  Widget build(BuildContext context) {
    final ovum = context.ovum;
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (icon, label, route) = _items[i];
          final color = ovum.categoryAt(i);
          return _QuickTile(icon: icon, label: label, color: color, route: route);
        },
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Material(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push(route),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Icon(icon, color: color, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontSize: 10.5, height: 1.1),
          ),
        ],
      ),
    );
  }
}

class _AgendaHighlights extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(agendaSessionsProvider);
    if (sessions.isEmpty) return const SizedBox.shrink();
    final highlights = sessions.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Agenda destacada',
          onAction: () => context.go(R.agenda),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: highlights.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final s = highlights[i];
              return _AgendaMiniCard(
                title: s.title,
                track: s.track,
                time: '${s.startDate.dayNameShort} · ${s.startDate.hm}',
                onTap: () => context.push(R.session(s.id)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AgendaMiniCard extends StatelessWidget {
  const _AgendaMiniCard({
    required this.title,
    required this.track,
    required this.time,
    required this.onTap,
  });
  final String title;
  final String track;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SizedBox(
      width: 240,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        )),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(PhosphorIconsRegular.clock, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(time, style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeynotesRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speakers = ref.watch(speakersProvider).valueOrNull ?? const [];
    final keynotes = speakers.where((s) => s.isKeynote).toList();
    if (keynotes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Conferencistas destacados',
          onAction: () => context.push(R.speakers),
        ),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: keynotes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final s = keynotes[i];
              return SizedBox(
                width: 90,
                child: Column(
                  children: [
                    InitialsAvatar(name: s.name, imageUrl: s.photoUrl, size: 68),
                    const SizedBox(height: 8),
                    Text(
                      s.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SponsorsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sponsors = ref.watch(sponsorsProvider).valueOrNull ?? const [];
    final top = sponsors.where((s) => s.tier.order <= 1).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppStrings.sponsors,
          onAction: () => context.push(R.sponsors),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: top.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final s = top[i];
              // Solo el logo (sin nombre) en una tarjeta blanca; toca → detalle.
              return SizedBox(
                width: 132,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(R.sponsor(s.id)),
                    child: SponsorLogo(
                      name: s.name,
                      logoUrl: s.logoUrl,
                      radius: 18,
                      padding: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HomeFooter extends StatelessWidget {
  const _HomeFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
          Text(
            'Organizan',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            OvumEvent.organizers,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Text(
            OvumEvent.mainVenue,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
