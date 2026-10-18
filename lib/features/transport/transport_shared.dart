import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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
String directionLabel(RouteDirection d) => switch (d) {
  RouteDirection.hotelToVenue => 'Del hotel a la sede',
  RouteDirection.venueToHotel => 'De la sede al hotel',
  RouteDirection.circular => 'Circular',
};

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

/// Minutos que faltan para [at], o `null` si ya pasó.
int? minutesUntil(DateTime at, DateTime now) {
  final diff = at.difference(now);
  return diff.isNegative ? null : diff.inMinutes;
}

/// "en 12 min", "en 1 h 20 min", "mañana 07:00".
String countdownLabel(DateTime at, DateTime now) {
  final minutes = minutesUntil(at, now);
  if (minutes == null) return '';
  if (minutes < 1) return 'saliendo';
  if (minutes < 60) return 'en $minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours < 12) {
    return rest == 0 ? 'en $hours h' : 'en $hours h $rest min';
  }
  return '';
}
