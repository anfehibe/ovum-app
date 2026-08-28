import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';

class ExhibitorsScreen extends ConsumerStatefulWidget {
  const ExhibitorsScreen({super.key});

  @override
  ConsumerState<ExhibitorsScreen> createState() => _ExhibitorsScreenState();
}

class _ExhibitorsScreenState extends ConsumerState<ExhibitorsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(exhibitorsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.exhibitors)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (exhibitors) {
          final q = _query.toLowerCase();
          final filtered = exhibitors.where((e) {
            return q.isEmpty ||
                e.name.toLowerCase().contains(q) ||
                e.category.toLowerCase().contains(q);
          }).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          final grouped = <String, List<Exhibitor>>{};
          for (final e in filtered) {
            grouped.putIfAbsent(e.initial, () => []).add(e);
          }
          final letters = grouped.keys.toList()..sort();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar expositor',
                    prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(message: 'Sin resultados')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          for (final letter in letters) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                              child: Text(letter,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: context.scheme.primary)),
                            ),
                            for (final e in grouped[letter]!)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ExhibitorTile(exhibitor: e),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExhibitorTile extends StatelessWidget {
  const _ExhibitorTile({required this.exhibitor});
  final Exhibitor exhibitor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(R.exhibitor(exhibitor.id)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              InitialsAvatar(name: exhibitor.name, imageUrl: exhibitor.logoUrl, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exhibitor.name, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      [exhibitor.category, if (exhibitor.booth.isNotEmpty) 'Stand ${exhibitor.booth}']
                          .where((e) => e.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIconsRegular.caretRight, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
