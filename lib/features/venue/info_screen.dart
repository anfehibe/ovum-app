import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/icons.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';

class InfoScreen extends ConsumerWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(infoItemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.generalInfo)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (items) {
          final grouped = <String, List<InfoItem>>{};
          for (final it in items) {
            grouped.putIfAbsent(it.category, () => []).add(it);
          }
          final categories = grouped.keys.toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              for (final cat in categories) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                  child: Text(cat, style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final item in grouped[cat]!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InfoCard(item: item),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.item});
  final InfoItem item;

  void _onAction() {
    final value = item.actionValue;
    if (value == null || value.isEmpty) return;
    switch (item.actionType) {
      case InfoActionType.url:
        openUrl(value);
      case InfoActionType.email:
        openEmail(value);
      case InfoActionType.phone:
        openPhone(value);
      case InfoActionType.none:
        break;
    }
  }

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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(infoIcon(item.icon), color: scheme.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleSmall)),
            ],
          ),
          if (item.body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(item.body, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (item.actionType != InfoActionType.none && item.actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _onAction, child: Text(item.actionLabel!)),
          ],
        ],
      ),
    );
  }
}
