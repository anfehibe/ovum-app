import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';
import '../widgets/contact_buttons.dart';

class HotelsScreen extends ConsumerWidget {
  const HotelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hotelsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.hotels)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (hotels) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: hotels.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, i) => _HotelCard(hotel: hotels[i]),
        ),
      ),
    );
  }
}

class _HotelCard extends StatelessWidget {
  const _HotelCard({required this.hotel});
  final Hotel hotel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hotel.isOfficial
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
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
                child: Icon(PhosphorIconsRegular.bed, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hotel.name, style: Theme.of(context).textTheme.titleMedium),
                    if (hotel.soldOut || hotel.isOfficial)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: hotel.soldOut
                            ? _pill(context, 'AGOTADO', scheme.error, scheme.onError)
                            : _pill(context, 'Hotel oficial',
                                scheme.primary.withValues(alpha: 0.14), scheme.primary),
                      ),
                  ],
                ),
              ),
              if (hotel.priceFrom != null)
                Text('Desde ${hotel.priceFrom!}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          if (hotel.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(hotel.description, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 10),
          if (hotel.address.isNotEmpty) _row(context, PhosphorIconsRegular.mapPin, hotel.address),
          if (hotel.distance.isNotEmpty) _row(context, PhosphorIconsRegular.mapTrifold, hotel.distance),
          if (hotel.contact != null)
            _row(context, PhosphorIconsRegular.user, 'Reservas: ${hotel.contact}'),
          const SizedBox(height: 12),
          ContactButtons(web: hotel.web, email: hotel.email, phone: hotel.phone),
          if (hotel.bookingUrl != null && !hotel.soldOut) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => openUrl(hotel.bookingUrl!),
                icon: const Icon(PhosphorIconsRegular.calendarPlus, size: 18),
                label: const Text('Reservar'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
