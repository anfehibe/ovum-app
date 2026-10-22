import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/states.dart';
import '../../data/models/bus_route.dart';
import '../../data/providers/transport_providers.dart';
import 'transport_shared.dart';
import 'widgets/route_map.dart';
import 'widgets/route_stop_timeline.dart';

/// Detalle de una ruta: recorrido, horarios y accesos al mapa.
class BusRouteDetailScreen extends ConsumerWidget {
  const BusRouteDetailScreen({super.key, required this.routeId});
  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(busRoutesProvider);
    final route = ref.watch(busRouteByIdProvider(routeId));

    if (async.isLoading && route == null) {
      return const Scaffold(body: LoadingView());
    }
    if (route == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: PhosphorIconsRegular.bus,
          message: context.l10n.transportRouteUnavailable,
        ),
      );
    }

    final index = (async.valueOrNull ?? const <BusRoute>[]).indexWhere(
      (r) => r.id == route.id,
    );
    final color = routeColor(context, route, index < 0 ? 0 : index);
    final next = ref.watch(nextDepartureProvider(route.id));
    final now = ref.watch(nowProvider);
    final days = ref.watch(serviceDaysProvider(route.id));

    return Scaffold(
      appBar: AppBar(title: Text(route.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Header(route: route, color: color),
          if (next != null) ...[
            const SizedBox(height: 16),
            _NextDepartureCard(at: next.at, departure: next.departure, now: now),
          ] else ...[
            const SizedBox(height: 16),
            const _NoServiceCard(),
          ],
          const SizedBox(height: 20),
          // Mapa embebido. Se construye solo si AppConfig.useEmbeddedMap está
          // encendido Y la ruta tiene paradas ubicables; si no, desaparece sin
          // dejar hueco y quedan los botones de abajo, que dan tráfico y tiempo
          // reales abriendo Google Maps.
          RouteMap(route: route, color: color),
          if (AppConfig.useEmbeddedMap && route.mappableStops.isNotEmpty)
            const SizedBox(height: 14),
          _MapActions(route: route),
          const SizedBox(height: 24),
          _SectionTitle(
            icon: PhosphorIconsRegular.mapPin,
            title: context.l10n.transportItinerary,
          ),
          const SizedBox(height: 12),
          RouteStopTimeline(route: route, color: color),
          const SizedBox(height: 24),
          _SectionTitle(
            icon: PhosphorIconsRegular.clock,
            title: context.l10n.transportDepartureTimes,
          ),
          const SizedBox(height: 12),
          if (days.isEmpty)
            Text(
              context.l10n.transportNoSchedules,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            )
          else
            for (final day in days) ...[
              _DaySchedule(route: route, day: day, now: now, color: color),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.route, required this.color});
  final BusRoute route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (route.code.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  route.code,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Text(
              directionLabel(context.l10n, route.direction),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        if (route.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(route.description, style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (route.notice.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                PhosphorIconsRegular.info,
                size: 16,
                color: context.ovum.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  route.notice,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.ovum.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NextDepartureCard extends StatelessWidget {
  const _NextDepartureCard({
    required this.at,
    required this.departure,
    required this.now,
  });
  final DateTime at;
  final RouteDeparture departure;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final sameDay = at.sameDay(now);
    final countdown = sameDay ? countdownLabel(context.l10n, at, now) : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.transportNextDepartureLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                at.hm,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                  height: 1.1,
                ),
              ),
              Text(
                sameDay
                    ? (countdown.isEmpty ? context.l10n.transportToday : countdown)
                    : at.fullDate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (departure.arriveTime case final arrive?)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  context.l10n.transportArrival,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  arrive,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Lo que se ve cuando ya no quedan salidas: nunca un error, siempre una
/// explicación. El servicio opera solo durante el congreso.
class _NoServiceCard extends StatelessWidget {
  const _NoServiceCard();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.clock,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.transportNoDeparturesLeft,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Accesos al mapa.
///
/// En esta entrega el mapa es la app de Google Maps, no un mapa embebido: así
/// el asistente ve tráfico y tiempo estimado reales sin que la app pida permiso
/// de ubicación. El mapa dentro de la pantalla llega con `google_maps_flutter`
/// (ver `docs/TRANSPORTE.md` §1.1 del repo `trivvo`): cuando exista, se inserta
/// encima de estos botones y ellos se quedan como alternativa.
class _MapActions extends StatelessWidget {
  const _MapActions({required this.route});
  final BusRoute route;

  @override
  Widget build(BuildContext context) {
    final origin = route.origin;
    return Column(
      children: [
        if (origin != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => openDirectionsToStop(origin),
              icon: const Icon(PhosphorIconsRegular.mapPin, size: 18),
              label: Text(context.l10n.transportDirectionsTo(origin.name)),
            ),
          ),
        if (route.mappableStops.length >= 2) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => openRouteOnMaps(route),
              icon: const Icon(PhosphorIconsRegular.mapTrifold, size: 18),
              label: Text(
                AppConfig.useEmbeddedMap
                    ? context.l10n.transportOpenRouteInGoogleMaps
                    : context.l10n.transportViewRouteOnMap,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: context.scheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

/// Salidas de un día, como chips. La próxima va resaltada y se puede agendar.
class _DaySchedule extends StatelessWidget {
  const _DaySchedule({
    required this.route,
    required this.day,
    required this.now,
    required this.color,
  });
  final BusRoute route;
  final DateTime day;
  final DateTime now;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final departures = route.departuresOn(day);
    final isToday = day.sameDay(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isToday ? context.l10n.transportTodayDate(day.monthDay) : day.fullDate,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isToday ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in departures)
              _DepartureChip(
                route: route,
                departure: d,
                day: day,
                now: now,
                color: color,
              ),
          ],
        ),
      ],
    );
  }
}

class _DepartureChip extends StatelessWidget {
  const _DepartureChip({
    required this.route,
    required this.departure,
    required this.day,
    required this.now,
    required this.color,
  });
  final BusRoute route;
  final RouteDeparture departure;
  final DateTime day;
  final DateTime now;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final at = departure.occurrences([day]).firstOrNull;
    final past = at != null && !at.isAfter(now);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: at == null || past ? null : () => _agendar(context, at),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: past
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: past ? Colors.transparent : color.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  departure.departTime,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: past ? scheme.onSurfaceVariant : scheme.onSurface,
                    decoration: past ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (!past) ...[
                  const SizedBox(width: 6),
                  Icon(
                    PhosphorIconsRegular.calendarPlus,
                    size: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            // La nota ("Cena de gala", "Solo ponentes") va visible, no en un
            // tooltip: es la diferencia entre tomar el bus correcto y el que no.
            if (departure.note case final note?) ...[
              const SizedBox(height: 2),
              Text(
                note,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: past ? scheme.onSurfaceVariant : color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _agendar(BuildContext context, DateTime at) async {
    final origin = route.origin;
    final arrive = departure.arriveTime;
    // Duración: hasta la hora de llegada si la hay; si no, los minutos que
    // estimó el organizador; si tampoco, una hora.
    final end = switch ((arrive, route.totalMinutes)) {
      (final String a, _) when a.contains(':') => _withTime(at, a),
      (_, final int m) when m > 0 => at.add(Duration(minutes: m)),
      _ => at.add(const Duration(hours: 1)),
    };
    await addToCalendar(
      title: context.l10n.transportBusDepartureTitle(route.name),
      description: route.description,
      location: origin?.searchQuery ?? '',
      start: at,
      end: end ?? at.add(const Duration(hours: 1)),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.transportOpeningCalendar)),
      );
    }
  }

  /// Aplica `"07:35"` sobre el día de [base]. Si la llegada es anterior a la
  /// salida, la salida cruza la medianoche: suma un día.
  DateTime? _withTime(DateTime base, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first);
    final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (h == null || m == null) return null;
    final end = DateTime(base.year, base.month, base.day, h, m);
    return end.isAfter(base) ? end : end.add(const Duration(days: 1));
  }
}
