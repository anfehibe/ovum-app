import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';

class OtherActivitiesScreen extends ConsumerWidget {
  const OtherActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.otherActivities)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (_) {
          final activities = ref.watch(otherActivitiesProvider);
          if (activities.isEmpty) {
            return const EmptyState(message: 'No hay actividades adicionales');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: activities.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ActivityCard(activity: activities[i])
                .animate()
                .fadeIn(delay: (50 * i).ms)
                .slideY(begin: 0.08, end: 0),
          );
        },
      ),
    );
  }
}

IconData _activityIcon(Session s) {
  final t = s.title.toLowerCase();
  if (t.contains('cóctel') || t.contains('coctel') || t.contains('cena')) {
    return PhosphorIconsRegular.forkKnife;
  }
  if (t.contains('premiación') || t.contains('premiacion')) return PhosphorIconsRegular.trophy;
  if (t.contains('cultural')) return PhosphorIconsRegular.confetti;
  if (t.contains('fiesta') || t.contains('clausura')) return PhosphorIconsRegular.confetti;
  return PhosphorIconsRegular.calendarStar;
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});
  final Session activity;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final color = context.ovum.categoryAt(activity.title.hashCode.abs());
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(R.session(activity.id)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_activityIcon(activity), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity.title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(PhosphorIconsRegular.calendarBlank, size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${activity.startDate.dayNameShort} ${activity.startDate.dayNumber} · ${timeRange(activity.startDate, activity.endDate)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(PhosphorIconsRegular.mapPin, size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(activity.room,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                      ],
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
