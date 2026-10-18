import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/ovum_event.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/states.dart';
import '../../data/models/bus_route.dart';
import '../../data/providers/transport_providers.dart';
import 'transport_shared.dart';

/// Listado de rutas de bus del congreso.
class TransportRoutesScreen extends ConsumerWidget {
  const TransportRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(busRoutesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.transport)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (routes) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(busRoutesProvider),
          child: routes.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: PhosphorIconsRegular.bus,
                      message:
                          'Todavía no hay rutas de transporte publicadas.\n'
                          'Vuelve a consultar cerca de las fechas del congreso.',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: routes.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) => i == 0
                      ? const _IntroCard()
                      : _RouteCard(route: routes[i - 1], index: i - 1),
                ),
        ),
      ),
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
              Text(
                'Buses del congreso',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Traslados entre los hoteles y la sede del congreso. '
            'Toca una ruta para ver sus paradas y horarios.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => openPhone(OvumEvent.contactPhone),
            icon: const Icon(PhosphorIconsRegular.phone, size: 16),
            label: const Text('Llamar a la organización'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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
                          _NextDepartureChip(at: next.at, now: now),
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

/// Origen → destino en dos líneas, con el hilo vertical que las une.
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

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dot(color, filled: false),
            const SizedBox(width: 10),
            Expanded(child: Text(origin.name, style: style)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4.5),
          child: Row(
            children: [
              Container(width: 1.5, height: 14, color: scheme.outlineVariant),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dot(color, filled: true),
            const SizedBox(width: 10),
            Expanded(child: Text(destination.name, style: style)),
          ],
        ),
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
      '${route.stops.length} paradas',
      if (route.totalMinutes case final m? when m > 0) '$m min aprox.',
      if (route.headwayMinutes case final f? when f > 0) 'cada $f min',
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
class _NextDepartureChip extends StatelessWidget {
  const _NextDepartureChip({required this.at, required this.now});
  final DateTime at;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final minutes = minutesUntil(at, now);
    final soon = minutes != null && minutes <= 20;
    final sameDay = at.sameDay(now);
    final when = sameDay ? at.hm : '${at.dayNameShort} ${at.hm}';
    final countdown = sameDay ? countdownLabel(at, now) : '';

    return Container(
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
            color: soon ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            countdown.isEmpty
                ? 'Próxima salida $when'
                : 'Próxima salida $when · $countdown',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: soon ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
