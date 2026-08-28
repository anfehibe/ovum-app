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

class AttendeesScreen extends ConsumerStatefulWidget {
  const AttendeesScreen({super.key});

  @override
  ConsumerState<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends ConsumerState<AttendeesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(attendeesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.attendees)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (attendees) {
          final q = _query.toLowerCase();
          final filtered = attendees.where((a) {
            return q.isEmpty ||
                a.name.toLowerCase().contains(q) ||
                a.company.toLowerCase().contains(q) ||
                a.sector.toLowerCase().contains(q) ||
                a.position.toLowerCase().contains(q);
          }).toList();

          final grouped = <String, List<Attendee>>{};
          for (final a in filtered) {
            grouped.putIfAbsent(a.company, () => []).add(a);
          }
          final companies = grouped.keys.toList()..sort();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre, empresa o sector',
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
                          for (final company in companies) ...[
                            _CompanyHeader(company: company),
                            for (final a in grouped[company]!)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AttendeeTile(attendee: a),
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

class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({required this.company});
  final String company;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.buildings, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(company,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _AttendeeTile extends StatelessWidget {
  const _AttendeeTile({required this.attendee});
  final Attendee attendee;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(R.attendee(attendee.id)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              InitialsAvatar(name: attendee.name, imageUrl: attendee.photoUrl, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attendee.name, style: Theme.of(context).textTheme.titleSmall),
                    Text('${attendee.position} · ${attendee.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
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
