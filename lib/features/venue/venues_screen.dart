import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';

class VenuesScreen extends ConsumerWidget {
  const VenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(venuesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.venue)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (venues) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: venues.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, i) => _VenueCard(venue: venues[i]),
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue});
  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(PhosphorIconsRegular.mapPinLine, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(venue.name, style: Theme.of(context).textTheme.titleMedium),
                    if (venue.isPrimary)
                      Text('Sede principal',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          if (venue.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(venue.description, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (venue.address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIconsRegular.mapPin, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(venue.address,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => openUrl(_mapUrl(venue)),
            icon: const Icon(PhosphorIconsRegular.mapTrifold, size: 18),
            label: const Text('Ver en mapa'),
          ),
        ],
      ),
    );
  }

  String _mapUrl(Venue v) {
    if (v.lat != null && v.lng != null) {
      return 'https://www.google.com/maps/search/?api=1&query=${v.lat},${v.lng}';
    }
    final q = Uri.encodeComponent(v.address.isNotEmpty ? v.address : v.name);
    return 'https://www.google.com/maps/search/?api=1&query=$q';
  }
}
