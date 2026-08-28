import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';

class OrganizersScreen extends ConsumerWidget {
  const OrganizersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(organizersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.organizers)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (organizers) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: organizers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, i) => _OrganizerCard(organizer: organizers[i]),
        ),
      ),
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  const _OrganizerCard({required this.organizer});
  final Organizer organizer;

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
              InitialsAvatar(name: organizer.name, imageUrl: organizer.logoUrl, size: 52),
              const SizedBox(width: 14),
              Expanded(child: Text(organizer.name, style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          if (organizer.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(organizer.description, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (organizer.web != null && organizer.web!.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openUrl(organizer.web!),
              icon: const Icon(PhosphorIconsRegular.globe, size: 18),
              label: const Text(AppStrings.website),
            ),
          ],
        ],
      ),
    );
  }
}
