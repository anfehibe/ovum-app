import 'package:flutter/material.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/utils/event_clock.dart';
import '../../core/utils/launchers.dart';
import '../../data/models/bus_route.dart';

/// Color de una ruta: el que cargó el organizador, o uno de la paleta de
/// categorías por posición para que dos rutas nunca se vean iguales.
Color routeColor(BuildContext context, BusRoute route, int index) {
  final hex = route.colorHex;
  if (hex != null) {
    final parsed = _parseHex(hex);
    if (parsed != null) return parsed;
  }
  final palette = context.ovum.categoryColors;
  return palette[index % palette.length];
}

/// `#E8991C` o `#FFE8991C` → [Color]. `null` si no es un hex válido.
Color? _parseHex(String raw) {
  var hex = raw.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(value);
}

/// Etiqueta del sentido del recorrido, para la tarjeta y la cabecera.
String directionLabel(AppLocalizations l10n, RouteDirection d) => switch (d) {
  RouteDirection.hotelToVenue => l10n.transportDirHotelToVenue,
  RouteDirection.venueToHotel => l10n.transportDirVenueToHotel,
  RouteDirection.circular => l10n.transportDirCircular,
};

/// Lo que distingue una salida además de su hora: la parada, si no es la
/// primera de la ruta, y la nota del organizador. "Desde Parque de la
/// Industria · Cena de gala". Vacío si no hay nada que añadir.
String departureDetails(
  AppLocalizations l10n,
  BusRoute route,
  RouteDeparture departure,
) {
  final origin = departure.originIn(route);
  return [
    if (origin != null && origin.id != route.origin?.id)
      l10n.transportFromStop(origin.name),
    if (departure.note case final note? when note.trim().isNotEmpty)
      note.trim(),
  ].join(' · ');
}

/// Abre Google Maps con **indicaciones** hasta [stop] desde donde esté el
/// usuario, con tráfico y hora estimada reales.
///
/// Es el camino del Nivel B para "cómo llego a mi parada": no necesita el
/// permiso de ubicación de la app (lo resuelve Google Maps con el suyo) ni el
/// SDK de mapas embebido.
Future<void> openDirectionsToStop(RouteStop stop) {
  final destination = stop.hasCoords
      ? '${stop.lat},${stop.lng}'
      : stop.searchQuery;
  return openUrl(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${Uri.encodeComponent(destination)}'
    '&travelmode=walking',
  );
}

/// Abre Google Maps con el **recorrido completo** de la ruta: origen, destino y
/// las paradas intermedias como waypoints, en coche.
///
/// Google admite hasta 9 waypoints en un enlace; las rutas de shuttle tienen
/// muchas menos, pero recortamos por si acaso en vez de generar una URL que el
/// propio Google rechaza.
Future<void> openRouteOnMaps(BusRoute route) {
  final points = route.mappableStops;
  if (points.length < 2) {
    final only = points.isNotEmpty ? points.first : route.origin;
    return only == null ? Future.value() : openDirectionsToStop(only);
  }
  final origin = '${points.first.lat},${points.first.lng}';
  final destination = '${points.last.lat},${points.last.lng}';
  final middle = points
      .sublist(1, points.length - 1)
      .take(9)
      .map((s) => '${s.lat},${s.lng}')
      .join('|');

  final waypoints = middle.isEmpty
      ? ''
      : '&waypoints=${Uri.encodeComponent(middle)}';
  return openUrl(
    'https://www.google.com/maps/dir/?api=1'
    '&origin=$origin&destination=$destination$waypoints&travelmode=driving',
  );
}

/// Minutos que faltan para [at], **redondeando hacia arriba**, o `null` si la
/// salida ya pasó.
///
/// Hacia arriba porque es lo que entiende quien mira un reloj: a las 06:30:00 al
/// bus de las 07:00 le faltan 30 minutos, no 29. Durante el minuto de la salida
/// (ver `BusRoute.departureGrace`) devuelve 0: el bus está saliendo.
int? minutesUntil(DateTime at, DateTime now) {
  if (!BusRoute.isUpcoming(at, now)) return null;
  final seconds = at.difference(now).inSeconds;
  if (seconds <= 0) return 0;
  return (seconds + 59) ~/ 60;
}

/// "en 12 min", "en 1 h 20 min", "mañana 07:00".
String countdownLabel(AppLocalizations l10n, DateTime at, DateTime now) {
  final minutes = minutesUntil(at, now);
  if (minutes == null) return '';
  if (minutes == 0) return l10n.transportLeavingNow;
  if (minutes < 60) return l10n.transportInMinutes(minutes);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours < 12) {
    return rest == 0
        ? l10n.transportInHours(hours)
        : l10n.transportInHoursMinutes(hours, rest);
  }
  return '';
}

/// Aviso de que los horarios vienen de la copia guardada en el teléfono porque
/// el servidor no respondió. Dice de cuándo son: un horario de esta mañana
/// sirve, pero el asistente tiene que saber que puede haber cambiado.
class TransportOfflineBanner extends StatelessWidget {
  const TransportOfflineBanner({super.key, required this.savedAt});

  /// Instante absoluto en que se obtuvieron del servidor.
  final DateTime savedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final saved = toEventWallClock(savedAt);
    final time = saved.sameDay(eventNow())
        ? saved.hm
        : '${saved.dayNameShort} ${saved.hm}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.ovum.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.cloudSlash,
            size: 18,
            color: context.ovum.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.transportOfflineBanner(time),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
