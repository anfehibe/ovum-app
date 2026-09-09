import 'package:cached_network_image/cached_network_image.dart';
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
          if (venue.plans.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Planos del recinto',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final plan in venue.plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlanThumb(plan: plan),
              ),
          ],
          if (venue.lat != null || venue.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => openUrl(_mapUrl(venue)),
              icon: const Icon(PhosphorIconsRegular.mapTrifold, size: 18),
              label: const Text('Ver en mapa'),
            ),
          ],
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

/// Miniatura de un plano del recinto; al tocarla abre el visor con zoom.
class _PlanThumb extends StatelessWidget {
  const _PlanThumb({required this.plan});
  final VenuePlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plan.title.isNotEmpty) ...[
          Text(plan.title,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: () => _openPlanViewer(context, plan),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CachedNetworkImage(
                  imageUrl: plan.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  placeholder: (_, _) => Container(
                    height: 150,
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 16, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Visor de plano a pantalla completa con pinch-zoom.
void _openPlanViewer(BuildContext context, VenuePlan plan) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (ctx) => Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(child: CachedNetworkImage(imageUrl: plan.imageUrl, fit: BoxFit.contain)),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(ctx).top + 8,
          right: 8,
          child: IconButton(
            onPressed: () => Navigator.of(ctx).pop(),
            icon: const Icon(PhosphorIconsRegular.x, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
          ),
        ),
      ],
    ),
  );
}
