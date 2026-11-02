import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/ovum_event.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/states.dart';
import '../../data/models/bus_route.dart';
import '../../data/providers/transport_follow_provider.dart';
import '../../data/providers/transport_providers.dart';
import 'transport_shared.dart';

/// Listado de rutas de bus del congreso.
class TransportRoutesScreen extends ConsumerStatefulWidget {
  const TransportRoutesScreen({super.key});

  @override
  ConsumerState<TransportRoutesScreen> createState() =>
      _TransportRoutesScreenState();
}

class _TransportRoutesScreenState extends ConsumerState<TransportRoutesScreen> {
  @override
  void initState() {
    super.initState();
    // Al entrar se vuelven a pedir los horarios si tienen más de unos minutos:
    // el provider conserva su primer resultado durante toda la sesión.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshTransportIfStale(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(busRoutesProvider);
    // `valueOrNull` conserva los datos anteriores mientras se recarga o si la
    // recarga falla: un refresco fallido ya no sustituye los horarios que el
    // usuario tenía en pantalla por un error.
    final data = async.valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.transport)),
      body: switch (data) {
        null when async.isLoading => const LoadingView(),
        null => ErrorView(onRetry: () => ref.invalidate(busRoutesProvider)),
        final data => RefreshIndicator(
          onRefresh: () => refreshTransport(ref),
          child: _RoutesList(data: data),
        ),
      },
    );
  }
}

class _RoutesList extends StatelessWidget {
  const _RoutesList({required this.data});
  final TransportData data;

  @override
  Widget build(BuildContext context) {
    final routes = data.routes;
    return ListView(
      // Siempre desplazable: con pocas rutas, tirar para refrescar no haría nada.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (data.offline) ...[
          TransportOfflineBanner(savedAt: data.savedAt),
          const SizedBox(height: 14),
        ],
        if (routes.isEmpty) ...[
          const SizedBox(height: 60),
          EmptyState(
            icon: PhosphorIconsRegular.bus,
            message: context.l10n.transportNoRoutes,
          ),
        ] else ...[
          const _IntroCard(),
          for (var i = 0; i < routes.length; i++) ...[
            const SizedBox(height: 14),
            _RouteCard(route: routes[i], index: i),
          ],
        ],
      ],
    );
  }
}

/// Encabezado del listado.
///
/// **No afirma condiciones del servicio** (si es gratuito, si hay que mostrar
/// el gafete, si hay cupo): eso sigue sin confirmar por el organizador —es la
/// pregunta 4 de `docs/TRANSPORTE-ORGANIZADOR.md`— y no se puede dar por hecho
/// en una pantalla que lee todo el congreso. Cuando lo confirmen, el sitio
/// natural es `aviso` de cada ruta, que ya llega del API y se muestra en el
/// detalle; o esta tarjeta, si la condición es común a todas.
class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.bus, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.transportCongressBuses,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.transportIntroText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          // Tamaño mínimo por defecto (48 dp de objetivo táctil): es el botón
          // al que se recurre con prisa, cuando el bus no aparece.
          TextButton.icon(
            onPressed: () => openPhone(OvumEvent.contactPhone),
            icon: const Icon(PhosphorIconsRegular.phone, size: 16),
            label: Text(context.l10n.transportCallOrganizers),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.route, required this.index});
  final BusRoute route;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final color = routeColor(context, route, index);
    final next = ref.watch(nextDepartureProvider(route.id));
    final now = ref.watch(nowProvider);
    final followed = ref.watch(isRouteFollowedProvider(route.id));

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(R.busRoute(route.id)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Franja de color: identifica la ruta de un vistazo.
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                route.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (followed) ...[
                              Icon(
                                PhosphorIconsRegular.bellRinging,
                                size: 18,
                                color: scheme.primary,
                                semanticLabel:
                                    context.l10n.transportFollowingBadge,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Icon(
                              PhosphorIconsRegular.caretRight,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _Endpoints(route: route, color: color),
                        const SizedBox(height: 10),
                        _MetaRow(route: route),
                        if (next != null) ...[
                          const SizedBox(height: 12),
                          _NextDepartureChip(
                            route: route,
                            departure: next.departure,
                            at: next.at,
                            now: now,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Origen → destino en dos líneas, con el hilo vertical que las une. Una ruta
/// de una sola parada muestra solo esa: repetir el nombre parecería un error.
class _Endpoints extends StatelessWidget {
  const _Endpoints({required this.route, required this.color});
  final BusRoute route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final origin = route.origin;
    final destination = route.destination;
    if (origin == null || destination == null) return const SizedBox.shrink();
    final scheme = context.scheme;
    final style = Theme.of(context).textTheme.bodyMedium;

    Widget row(RouteStop stop, {required bool filled}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dot(color, filled: filled),
        const SizedBox(width: 10),
        Expanded(child: Text(stop.name, style: style)),
      ],
    );

    if (origin.id == destination.id) return row(origin, filled: true);
    return Column(
      children: [
        row(origin, filled: false),
        Padding(
          padding: const EdgeInsets.only(left: 4.5),
          child: Row(
            children: [
              Container(width: 1.5, height: 14, color: scheme.outlineVariant),
            ],
          ),
        ),
        row(destination, filled: true),
      ],
    );
  }
}

Widget _dot(Color color, {required bool filled}) => Container(
  width: 11,
  height: 11,
  margin: const EdgeInsets.only(top: 5),
  decoration: BoxDecoration(
    color: filled ? color : Colors.transparent,
    shape: BoxShape.circle,
    border: Border.all(color: color, width: 2),
  ),
);

/// Nº de paradas · duración estimada · frecuencia.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.route});
  final BusRoute route;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final parts = <String>[
      context.l10n.transportStopsCount(route.stops.length),
      if (route.totalMinutes case final m? when m > 0)
        context.l10n.transportApproxMinutes(m),
      if (route.headwayMinutes case final f? when f > 0)
        context.l10n.transportEveryMinutes(f),
    ];
    return Text(
      parts.join(' · '),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );
  }
}

/// "Próxima salida 7:30 · en 12 min". Se resalta cuando falta poco.
///
/// Debajo, si hace falta, desde dónde sale y la nota del organizador: la vuelta
/// de la cena de gala sale de la sede aunque la ruta sea "del hotel a la sede".
class _NextDepartureChip extends StatelessWidget {
  const _NextDepartureChip({
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
    final minutes = minutesUntil(at, now);
    final soon = minutes != null && minutes <= 20;
    final sameDay = at.sameDay(now);
    // Con la fecha: "Mié 07:00" a secas, visto el martes 4, parece mañana.
    final when = sameDay
        ? at.hm
        : '${at.dayNameShort} ${at.monthDayShort} ${at.hm}';
    final countdown = sameDay ? countdownLabel(context.l10n, at, now) : '';

    final details = departureDetails(context.l10n, route, departure);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: soon
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsRegular.clock,
                size: 14,
                color: soon
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              // Flexible: con letra grande el texto se parte en dos líneas en
              // vez de desbordar la tarjeta.
              Flexible(
                child: Text(
                  countdown.isEmpty
                      ? context.l10n.transportNextDeparture(when)
                      : context.l10n.transportNextDepartureWithCountdown(
                          when,
                          countdown,
                        ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: soon
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              details,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
