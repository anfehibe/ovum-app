import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/iterable_ext.dart';
import '../../core/widgets/favorite_button.dart';
import '../../core/widgets/sponsor_logo.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/favorites_provider.dart';
import '../widgets/contact_buttons.dart';
import 'sponsors_screen.dart';

class SponsorDetailScreen extends ConsumerWidget {
  const SponsorDetailScreen({super.key, required this.sponsorId});
  final String sponsorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sponsors = ref.watch(sponsorsProvider).valueOrNull ?? const [];
    final sponsor = sponsors.firstWhereOrNull((s) => s.id == sponsorId);
    if (sponsor == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(message: 'Patrocinador no encontrado'));
    }
    final color = sponsorTierColor(sponsor.tier);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 4, 12, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, Color.lerp(color, Colors.black, 0.3)!],
              ),
              borderRadius: const BorderRadius.only(
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
                    FavoriteButton(kind: FavKind.sponsor, id: sponsor.id, onSurface: true),
                  ],
                ),
                SizedBox(
                  width: 150,
                  height: 104,
                  child: SponsorLogo(
                    name: sponsor.name,
                    logoUrl: sponsor.logoUrl,
                    radius: 20,
                    padding: 16,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  sponsor.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Patrocinador ${sponsor.tier.label}',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sponsor.booth != null && sponsor.booth!.isNotEmpty) ...[
                  _infoRow(context, PhosphorIconsRegular.storefront, 'Stand ${sponsor.booth}'),
                  const SizedBox(height: 16),
                ],
                if (sponsor.description.isNotEmpty) ...[
                  Text('Sobre el patrocinador', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(sponsor.description, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 22),
                ],
                ContactButtons(web: sponsor.web, email: sponsor.email, phone: sponsor.phone),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.scheme.primary),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
