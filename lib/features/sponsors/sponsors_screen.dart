import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/sponsor_logo.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';

/// Color representativo de cada nivel de patrocinio.
Color sponsorTierColor(SponsorTier tier) => switch (tier) {
      SponsorTier.diamante => const Color(0xFF25B0C4),
      SponsorTier.oro => const Color(0xFFE0A80D),
      SponsorTier.plata => const Color(0xFF98A2AD),
      SponsorTier.bronce => const Color(0xFFB5793B),
    };

class SponsorsScreen extends ConsumerWidget {
  const SponsorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sponsorsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sponsors)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (sponsors) {
          final byTier = <SponsorTier, List<Sponsor>>{};
          for (final s in sponsors) {
            byTier.putIfAbsent(s.tier, () => []).add(s);
          }
          final tiers = byTier.keys.toList()..sort((a, b) => a.order.compareTo(b.order));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              for (final tier in tiers) ...[
                _TierHeader(tier: tier, count: byTier[tier]!.length),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: tier == SponsorTier.diamante ? 2 : 3,
                  childAspectRatio: tier == SponsorTier.diamante ? 1.4 : 0.82,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    for (final s in byTier[tier]!)
                      _SponsorCard(sponsor: s, big: tier == SponsorTier.diamante),
                  ],
                ),
                const SizedBox(height: 22),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TierHeader extends StatelessWidget {
  const _TierHeader({required this.tier, required this.count});
  final SponsorTier tier;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = sponsorTierColor(tier);
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(tier.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 6),
        Text('($count)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _SponsorCard extends StatelessWidget {
  const _SponsorCard({required this.sponsor, required this.big});
  final Sponsor sponsor;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final color = sponsorTierColor(sponsor.tier);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(R.sponsor(sponsor.id)),
        child: Container(
          padding: EdgeInsets.all(big ? 12 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              // El logo ocupa el espacio flexible: nunca desborda el card y se
              // muestra completo (BoxFit.contain) en una tarjeta blanca.
              Expanded(
                child: SponsorLogo(
                  name: sponsor.name,
                  logoUrl: sponsor.logoUrl,
                  radius: big ? 14 : 12,
                  padding: big ? 12 : 9,
                ),
              ),
              SizedBox(height: big ? 10 : 8),
              Text(
                sponsor.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: (big
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.labelMedium)
                    ?.copyWith(fontWeight: FontWeight.w600, height: 1.15),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
