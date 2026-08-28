import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/iterable_ext.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/favorite_button.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/favorites_provider.dart';
import '../widgets/contact_buttons.dart';

class ExhibitorDetailScreen extends ConsumerWidget {
  const ExhibitorDetailScreen({super.key, required this.exhibitorId});
  final String exhibitorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(exhibitorsProvider).valueOrNull ?? const [];
    final ex = list.firstWhereOrNull((e) => e.id == exhibitorId);
    if (ex == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(message: 'Expositor no encontrado'));
    }
    final scheme = context.scheme;

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
                    FavoriteButton(kind: FavKind.exhibitor, id: ex.id, onSurface: true),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: InitialsAvatar(name: ex.name, imageUrl: ex.logoUrl, size: 78),
                ),
                const SizedBox(height: 14),
                Text(
                  ex.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                if (ex.shortDescription.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(ex.shortDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (ex.category.isNotEmpty) CategoryChip(label: ex.category),
                    if (ex.booth.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsRegular.storefront, size: 16, color: scheme.primary),
                          const SizedBox(width: 4),
                          Text('Stand ${ex.booth}', style: Theme.of(context).textTheme.labelLarge),
                        ],
                      ),
                    ],
                  ],
                ),
                if (ex.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(ex.description, style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 22),
                ContactButtons(web: ex.web, email: ex.email, phone: ex.phone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
