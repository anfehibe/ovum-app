import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/utils/iterable_ext.dart';
import '../../core/widgets/edge_fade.dart';
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
  /// Grupos de agenda ocultos. Guardamos los ocultos y no los visibles para que
  /// un grupo nuevo que aparezca en el API entre visible por defecto.
  final Set<String> _hidden = {};

  /// Día que el usuario pidió, no el que se está mostrando. Los días
  /// disponibles cambian al ocultar un grupo (la agenda general va del 9 al 11
  /// y el programa científico del 11 al 13), así que guardar un índice no
  /// sirve: apuntaría a otra fecha o se saldría de rango.
  DateTime? _wantedDay;

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
    final all = ref.watch(agendaSessionsProvider);
    final groups = ref.watch(agendaGroupsProvider);
    if (all.isEmpty) {
      return const EmptyState(message: 'La agenda se publicará pronto');
    }

    // Con un solo grupo no hay filtro que mostrar ni nada que ocultar.
    final hasFilter = groups.length >= 2;
    final visible = groups.where((g) => !_hidden.contains(g)).toSet();
    final scoped = hasFilter
        ? all.where((s) => visible.contains(s.agendaGroup)).toList()
        : all;

    final allDays = _distinctDays(all);
    final days = _distinctDays(scoped);
    final selectedDay = _resolveDay(days);
    final daySessions = selectedDay == null
        ? const <Session>[]
        : scoped.where((s) => s.startDate.sameDay(selectedDay)).toList();

    return Column(
      children: [
        if (hasFilter)
          _GroupFilter(
            groups: groups,
            hidden: _hidden,
            onToggled: (g) => setState(() {
              if (!_hidden.remove(g)) _hidden.add(g);
            }),
          ),
        if (selectedDay != null)
          _DaySelector(
            days: days,
            selected: selectedDay,
            // Numeramos contra los días de todo el evento: si no, el 11 de
            // noviembre sería "Día 1" con solo el programa científico visible y
            // "Día 3" con todo, cambiando de nombre al tocar un chip.
            ordinalOf: (d) => allDays.indexWhere((e) => e.sameDay(d)) + 1,
            onSelected: (d) => setState(() => _wantedDay = d),
          ),
        Expanded(
          child: daySessions.isEmpty
              ? const EmptyState(message: AppStrings.agendaNoGroupSelected)
              : ListView.separated(
                  // Al cambiar de filtro la lista vuelve arriba y las
                  // animaciones de entrada se reproducen de nuevo.
                  key: ValueKey('${visible.join('|')}|$selectedDay'),
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

  /// Resuelve qué día mostrar contra los días que existen en el filtro actual.
  ///
  /// Preserva la fecha pedida; si esa fecha no está en el grupo visible, cae al
  /// día más cercano (no al primero: saltar del 10 al 13 de noviembre
  /// desorienta). No escribe [_wantedDay] — solo lo toca el tap del usuario —,
  /// así que volver a mostrar un grupo devuelve al día en que estaba.
  DateTime? _resolveDay(List<DateTime> days) {
    if (days.isEmpty) return null;
    final wanted = _wantedDay;
    if (wanted == null) return days.first;
    return days.firstWhereOrNull((d) => d.sameDay(wanted)) ??
        days.reduce((a, b) =>
            a.difference(wanted).abs() <= b.difference(wanted).abs() ? a : b);
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

/// Chips para mostrar/ocultar cada grupo de agenda (agenda general vs. programa
/// científico). Multi-selección: todos encendidos es el estado inicial.
class _GroupFilter extends StatefulWidget {
  const _GroupFilter({
    required this.groups,
    required this.hidden,
    required this.onToggled,
  });

  final List<String> groups;
  final Set<String> hidden;
  final ValueChanged<String> onToggled;

  @override
  State<_GroupFilter> createState() => _GroupFilterState();
}

class _GroupFilterState extends State<_GroupFilter> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Re-evaluar el degradado: en el primer build el controller aún no tenía
      // clients y EdgeFade no sabía si había desbordamiento.
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: EdgeFade(
        controller: _controller,
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: widget.groups.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final group = widget.groups[i];
            return FilterChip(
              selected: !widget.hidden.contains(group),
              onSelected: (_) => widget.onToggled(group),
              label: ConstrainedBox(
                // Los nombres vienen del API y pueden ser largos.
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(group, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.days,
    required this.selected,
    required this.ordinalOf,
    required this.onSelected,
  });

  final List<DateTime> days;

  /// Día visible. Se compara por fecha porque [days] cambia con el filtro.
  final DateTime selected;

  /// Número de jornada del día dentro del evento completo.
  final int Function(DateTime) ordinalOf;

  final ValueChanged<DateTime> onSelected;

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
          final isSel = day.sameDay(selected);
          final scheme = context.scheme;
          return Material(
            color: isSel ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelected(day),
              child: Container(
                width: 92,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Día ${ordinalOf(day)}',
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
