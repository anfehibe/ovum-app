import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';
import '../widgets/session_tile.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  int _dayIndex = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navAgenda)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (_) => _content(),
      ),
    );
  }

  Widget _content() {
    final sessions = ref.watch(agendaSessionsProvider);
    final days = _distinctDays(sessions);
    if (days.isEmpty) {
      return const EmptyState(message: 'La agenda se publicará pronto');
    }
    final safeIndex = _dayIndex.clamp(0, days.length - 1);
    final selectedDay = days[safeIndex];
    final daySessions = sessions.where((s) => s.startDate.sameDay(selectedDay)).toList();

    return Column(
      children: [
        _DaySelector(
          days: days,
          selected: safeIndex,
          onSelected: (i) => setState(() => _dayIndex = i),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: daySessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => SessionTile(
              session: daySessions[i],
              onTap: () => context.push(R.session(daySessions[i].id)),
            ).animate().fadeIn(delay: (40 * i).ms).slideY(begin: 0.08, end: 0),
          ),
        ),
      ],
    );
  }

  List<DateTime> _distinctDays(List<Session> sessions) {
    final days = <DateTime>[];
    for (final s in sessions) {
      if (!days.any((d) => d.sameDay(s.startDate))) days.add(s.day);
    }
    days.sort();
    return days;
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.days,
    required this.selected,
    required this.onSelected,
  });

  final List<DateTime> days;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final day = days[i];
          final isSel = i == selected;
          final scheme = context.scheme;
          return Material(
            color: isSel ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelected(i),
              child: Container(
                width: 92,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Día ${i + 1}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isSel ? scheme.onPrimary : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.dayNameShort} ${day.dayNumber}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isSel ? scheme.onPrimary : scheme.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
