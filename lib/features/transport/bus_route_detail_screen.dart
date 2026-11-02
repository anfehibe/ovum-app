import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/config/app_config.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/states.dart';
import '../../data/models/bus_route.dart';
import '../../data/providers/notifications_provider.dart';
import '../../data/providers/transport_follow_provider.dart';
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
    final data = async.valueOrNull;
    final route = ref.watch(busRouteByIdProvider(routeId));

    if (route == null) {
      return Scaffold(
        appBar: AppBar(),
        // "Sin red" y "esta ruta ya no existe" son problemas distintos: el
        // primero se arregla reintentando, el segundo no.
        body: switch (data) {
          _ when async.isLoading => const LoadingView(),
          null => ErrorView(onRetry: () => ref.invalidate(busRoutesProvider)),
          _ => EmptyState(
            icon: PhosphorIconsRegular.bus,
            message: context.l10n.transportRouteUnavailable,
          ),
        },
      );
    }

    final index = (data?.routes ?? const <BusRoute>[]).indexWhere(
      (r) => r.id == route.id,
    );
    final color = routeColor(context, route, index < 0 ? 0 : index);
    final next = ref.watch(nextDepartureProvider(route.id));
    final now = ref.watch(nowProvider);
    final days = ref.watch(serviceDaysProvider(route.id));
    final headway = route.headwayMinutes ?? 0;
    // Servicio por frecuencia sin horario fijo: la tarjeta de arriba ya lo dice
    // y una sección "Horarios" vacía solo confundiría.
    final byFrequencyOnly = route.departures.isEmpty && headway > 0;

    return Scaffold(
      appBar: AppBar(title: Text(route.name)),
      body: RefreshIndicator(
        onRefresh: () => refreshTransport(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (data != null && data.offline) ...[
              TransportOfflineBanner(savedAt: data.savedAt),
              const SizedBox(height: 16),
            ],
            _Header(route: route, color: color),
            if (next != null) ...[
              const SizedBox(height: 16),
              _NextDepartureCard(
                route: route,
                departure: next.departure,
                at: next.at,
                now: now,
              ),
            ] else if (byFrequencyOnly) ...[
              const SizedBox(height: 16),
              _NoServiceCard(
                message: context.l10n.transportServiceEvery(headway),
              ),
            ] else if (route.departures.isNotEmpty) ...[
              const SizedBox(height: 16),
              _NoServiceCard(message: context.l10n.transportNoDeparturesLeft),
            ],
            if (AppConfig.usePush) ...[
              const SizedBox(height: 12),
              _FollowButton(routeId: route.id),
            ],
            const SizedBox(height: 20),
            // Mapa embebido. Se construye solo si AppConfig.useEmbeddedMap está
            // encendido Y la ruta tiene paradas ubicables; si no, desaparece sin
            // dejar hueco y quedan los botones de abajo, que dan tráfico y tiempo
            // reales abriendo Google Maps.
            RouteMap(
              route: route,
              color: color,
              onExpand: () => context.push(R.busRouteMap(route.id)),
            ),
            if (AppConfig.useEmbeddedMap && route.mappableStops.isNotEmpty)
              const SizedBox(height: 14),
            _MapActions(
              route: route,
              origin: next?.departure.originIn(route) ?? route.origin,
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              icon: PhosphorIconsRegular.mapPin,
              title: context.l10n.transportItinerary,
            ),
            const SizedBox(height: 12),
            RouteStopTimeline(route: route, color: color),
            if (!byFrequencyOnly) ...[
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
          ],
        ),
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
          Text(
            route.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
    required this.route,
    required this.departure,
    required this.at,
    required this.now,
  });
  final BusRoute route;
  final RouteDeparture departure;
  final DateTime at;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final sameDay = at.sameDay(now);
    final countdown = sameDay ? countdownLabel(context.l10n, at, now) : '';
    final details = departureDetails(context.l10n, route, departure);
    final onCard = scheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expanded: con letra grande la fecha larga ("miércoles, 11 de
          // noviembre de 2026") desbordaba la tarjeta.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.transportNextDepartureLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: onCard),
                ),
                const SizedBox(height: 2),
                Text(
                  at.hm,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: onCard,
                    height: 1.1,
                  ),
                ),
                Text(
                  sameDay
                      ? (countdown.isEmpty
                            ? context.l10n.transportToday
                            : countdown)
                      : at.fullDate,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: onCard),
                ),
                // Desde dónde sale si no es la primera parada, y la nota: sin
                // esto la vuelta de la cena de gala parecía salir del hotel.
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    details,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onCard,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (departure.arriveTime case final arrive?) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  context.l10n.transportArrival,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: onCard),
                ),
                Text(
                  arrive,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onCard,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Lo que se ve cuando no hay una próxima salida que mostrar: nunca un error,
/// siempre una explicación ("Sale cada 15 min", "No quedan salidas…").
class _NoServiceCard extends StatelessWidget {
  const _NoServiceCard({required this.message});
  final String message;

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
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Avisarme de las salidas": suscribe el teléfono al topic de la ruta, por el
/// que el backend manda "Tu bus sale en 15 min".
///
/// Funciona también para el invitado (los topics no dependen de la sesión), y
/// es el momento de pedirle el permiso de notificaciones: la hoja del inicio no
/// se le muestra nunca.
class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.routeId});
  final String routeId;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final following = ref.watch(isRouteFollowedProvider(widget.routeId));
    final pushOn = ref.watch(notificationPrefsProvider).pushEnabled;
    final onPressed = _busy ? null : _toggle;

    final button = following
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: const Icon(PhosphorIconsRegular.bellRinging, size: 18),
            label: Text(context.l10n.transportFollowingRoute),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(PhosphorIconsRegular.bell, size: 18),
            label: Text(context.l10n.transportFollowRoute),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(toggled: following, child: button),
        // Sigue la ruta pero "Avisos del congreso" está apagado en Perfil: no
        // le llegaría nada y tiene que saberlo.
        if (following && !pushOn)
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.transportPushOffSnack,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.ovum.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(notificationPrefsProvider.notifier).setPush(true),
                child: Text(context.l10n.transportPushOffAction),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _toggle() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final followed = ref.read(followedRoutesProvider.notifier);
    // Se captura ahora: la acción del snackbar puede ejecutarse con esta
    // pantalla ya cerrada, y entonces `ref` no se puede usar.
    final prefs = ref.read(notificationPrefsProvider.notifier);

    if (ref.read(isRouteFollowedProvider(widget.routeId))) {
      followed.toggle(widget.routeId);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.transportUnfollowedSnack)),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final service = ref.read(notificationServiceProvider);
      final allowed =
          await service.hasPermission() || await service.requestPermission();
      if (!mounted) return;
      if (!allowed) {
        // Seguir sin permiso sería prometer un aviso que el sistema no va a
        // mostrar.
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.transportPermissionDenied)),
        );
        return;
      }
      followed.toggle(widget.routeId);
      if (!ref.read(notificationPrefsProvider).pushEnabled) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.transportPushOffSnack),
            action: SnackBarAction(
              label: l10n.transportPushOffAction,
              onPressed: () => prefs.setPush(true),
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.transportFollowedSnack)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Accesos al mapa: abren la app de Google Maps, con tráfico y tiempo estimado
/// reales y sin que esta app pida permiso de ubicación. Con el mapa embebido
/// encendido quedan debajo de él como alternativa.
class _MapActions extends StatelessWidget {
  const _MapActions({required this.route, required this.origin});
  final BusRoute route;

  /// Parada de la próxima salida, que no siempre es la primera de la ruta.
  final RouteStop? origin;

  @override
  Widget build(BuildContext context) {
    final origin = this.origin;
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
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

/// Salidas de un día, como chips. Las que no han pasado se pueden agendar.
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
          isToday
              ? context.l10n.transportTodayDate(day.monthDay)
              : day.fullDate,
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
    final l10n = context.l10n;
    final at = departure.occurrences([day]).firstOrNull;
    // Mismo criterio que la tarjeta de arriba: durante su minuto el bus está
    // saliendo y no se tacha.
    final past = at != null && !BusRoute.isUpcoming(at, now);
    final details = departureDetails(l10n, route, departure);
    final semantics = [
      past
          ? l10n.transportDeparturePastSemantics(departure.departTime)
          : l10n.transportDepartureSemantics(departure.departTime),
      if (details.isNotEmpty) details,
    ].join(' ');

    return Semantics(
      button: at != null && !past,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: at == null || past ? null : () => _agendar(context, at),
        child: Container(
          // Objetivo táctil cómodo aunque el chip sea solo una hora.
          constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
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
            mainAxisAlignment: MainAxisAlignment.center,
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
              // La parada y la nota ("Cena de gala", "Solo ponentes") van
              // visibles, no en un tooltip: es la diferencia entre tomar el bus
              // correcto y el que no.
              if (details.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  details,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: past ? scheme.onSurfaceVariant : color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Sin snackbar: en iOS el plugin devuelve `false` también cuando el usuario
  /// cierra la hoja del calendario a propósito, así que no distingue un fallo,
  /// y en Android la propia app de calendario ya se abre a la vista.
  Future<void> _agendar(BuildContext context, DateTime at) async {
    final origin = departure.originIn(route);
    final details = departureDetails(context.l10n, route, departure);
    await addToCalendar(
      title: context.l10n.transportBusDepartureTitle(route.name),
      description: [
        details,
        route.description,
      ].where((s) => s.isNotEmpty).join('\n\n'),
      location: origin?.searchQuery ?? '',
      start: at,
      end: _arrival(at) ?? at.add(_rideDuration(origin)),
    );
  }

  /// Llegada aplicada sobre el día de [at]. Si es anterior a la salida, la
  /// salida cruza la medianoche y se suma un día.
  ///
  /// `null` si no hay llegada, si no es una hora válida, si coincide con la
  /// salida (el panel la rellena así cuando no se conoce: crearía un evento de
  /// 24 h) o si da un trayecto absurdo de más de 6 h, que es un error de carga.
  DateTime? _arrival(DateTime at) {
    final parts = departure.arriveTime?.split(':');
    if (parts == null || parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    var end = DateTime(at.year, at.month, at.day, h, m);
    if (!end.isAfter(at)) end = end.add(const Duration(days: 1));
    return end.difference(at) > const Duration(hours: 6) ? null : end;
  }

  /// Duración estimada desde [origin] hasta el final, según los minutos por
  /// parada del organizador; una hora si no los cargó.
  Duration _rideDuration(RouteStop? origin) {
    final total = route.totalMinutes ?? 0;
    final ride = total - (origin?.minutesFromStart ?? 0);
    return ride > 0 ? Duration(minutes: ride) : const Duration(hours: 1);
  }
}
