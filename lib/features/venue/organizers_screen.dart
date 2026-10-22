import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

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
      appBar: AppBar(title: Text(context.l10n.organizers)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (content) {
          final organizers = content.organizers;
          final texto = content.texto?.trim();
          final hasTexto = texto != null && texto.isNotEmpty;
          final headerCount = hasTexto ? 1 : 0;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: organizers.length + headerCount,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              if (hasTexto && i == 0) return _IntroText(text: texto);
              return _OrganizerCard(organizer: organizers[i - headerCount]);
            },
          );
        },
      ),
    );
  }
}

class _IntroText extends StatelessWidget {
  const _IntroText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
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
              InitialsAvatar(
                name: organizer.name,
                imageUrl: organizer.logoUrl,
                size: 52,
                zoomable: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  organizer.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (organizer.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              organizer.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (organizer.web != null && organizer.web!.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openUrl(organizer.web!),
              icon: const Icon(PhosphorIconsRegular.globe, size: 18),
              label: Text(context.l10n.website),
            ),
          ],
        ],
      ),
    );
  }
}
