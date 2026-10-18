import 'package:flutter/material.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/bus_route.dart';
import '../transport_shared.dart';

/// Recorrido de la ruta como línea de tiempo vertical.
///
/// Cada parada muestra su nombre, su dirección y los minutos estimados desde la
/// primera. Tocar una abre Google Maps con las indicaciones hasta ella.
class RouteStopTimeline extends StatelessWidget {
  const RouteStopTimeline({
    super.key,
    required this.route,
    required this.color,
  });

  final BusRoute route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final stops = route.stops;
    if (stops.isEmpty) {
      return Text(
        'Esta ruta aún no tiene paradas publicadas.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < stops.length; i++)
          _StopRow(
            stop: stops[i],
            color: color,
            isFirst: i == 0,
            isLast: i == stops.length - 1,
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  final RouteStop stop;
  final Color color;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final terminal = isFirst || isLast || stop.isTerminal;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openDirectionsToStop(stop),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carril del hilo: tramo superior, punto, tramo inferior.
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 10,
                      color: isFirst
                          ? Colors.transparent
                          : color.withValues(alpha: 0.45),
                    ),
                    Container(
                      width: terminal ? 13 : 10,
                      height: terminal ? 13 : 10,
                      decoration: BoxDecoration(
                        color: terminal ? color : scheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isLast
                            ? Colors.transparent
                            : color.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stop.name,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: terminal
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                          ),
                          if (stop.minutesFromStart case final m?
                              when m > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '+$m min',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                      if (stop.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          stop.address,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _iconFor(stop.kind),
                            size: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _labelFor(stop.kind),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const Spacer(),
                          Icon(
                            PhosphorIconsRegular.caretRight,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(StopKind kind) => switch (kind) {
  StopKind.hotel => PhosphorIconsRegular.bed,
  StopKind.venue => PhosphorIconsRegular.mapTrifold,
  StopKind.free => PhosphorIconsRegular.mapPin,
};

String _labelFor(StopKind kind) => switch (kind) {
  StopKind.hotel => 'Hotel',
  StopKind.venue => 'Sede',
  StopKind.free => 'Punto de encuentro',
};
