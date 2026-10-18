/// Transporte del congreso: rutas de bus hotel ↔ sede.
///
/// Contrato: `GET /events/{id}/transport/routes` (ver `docs/API.md` §Transporte
/// del repo `trivvo`). Nivel B: hay rutas, paradas, horarios y trazado, pero
/// **no** posiciones de buses en vivo (`buses` siempre llega vacío).
library;

/// Tipo de parada. El backend manda `hotel` | `sede` | `libre`.
enum StopKind {
  hotel,
  venue,
  free;

  static StopKind parse(String? raw) => switch (raw) {
    'hotel' => StopKind.hotel,
    'sede' || 'venue' => StopKind.venue,
    _ => StopKind.free,
  };
}

/// Sentido del recorrido.
enum RouteDirection {
  hotelToVenue,
  venueToHotel,
  circular;

  static RouteDirection parse(String? raw) => switch (raw) {
    'sede_hotel' => RouteDirection.venueToHotel,
    'circular' => RouteDirection.circular,
    _ => RouteDirection.hotelToVenue,
  };
}

/// Una parada del recorrido. `order` es la posición en la ruta (1..n).
class RouteStop {
  const RouteStop({
    required this.id,
    required this.order,
    required this.kind,
    required this.name,
    this.address = '',
    this.lat,
    this.lng,
    this.minutesFromStart,
    this.isTerminal = false,
  });

  final String id;
  final int order;
  final StopKind kind;
  final String name;
  final String address;
  final double? lat;
  final double? lng;

  /// Minutos estimados desde la primera parada. Lo captura el organizador a
  /// mano; es informativo, no un cálculo con tráfico.
  final int? minutesFromStart;
  final bool isTerminal;

  bool get hasCoords => lat != null && lng != null;

  /// Texto para buscar este punto en un mapa: la dirección si la hay, si no el nombre.
  String get searchQuery => address.isNotEmpty ? address : name;
}

/// Una salida programada. `date == null` significa **todos los días del evento**,
/// que es el caso habitual del shuttle.
class RouteDeparture {
  const RouteDeparture({
    required this.id,
    this.date,
    required this.departTime,
    this.arriveTime,
    this.note,
    this.stopId,
  });

  final String id;

  /// Día concreto, o `null` para "todos los días del evento".
  final DateTime? date;

  /// Hora de salida en formato `HH:mm`, tal cual la manda el backend.
  ///
  /// Es una hora de pared local (no un instante con zona horaria), así que se
  /// compara directamente con `DateTime.now()` sin convertir. A diferencia de la
  /// agenda —cuyas horas llegan como instantes UTC y se muestran en crudo, ver
  /// `date_ext.dart`— aquí no hay nada que convertir.
  final String departTime;

  final String? arriveTime;
  final String? note;

  /// Parada desde la que sale. Normalmente la primera de la ruta.
  final String? stopId;

  /// Aplica a todos los días del congreso.
  bool get isDaily => date == null;

  /// Esta salida convertida en instantes concretos dentro de [eventDays].
  ///
  /// Una salida diaria produce una ocurrencia por día; una con fecha concreta,
  /// solo esa (y únicamente si cae dentro de los días del evento).
  List<DateTime> occurrences(List<DateTime> eventDays) {
    final hm = _parseHm(departTime);
    if (hm == null) return const [];
    final (hour, minute) = hm;
    if (date case final d?) {
      return [DateTime(d.year, d.month, d.day, hour, minute)];
    }
    return [
      for (final d in eventDays) DateTime(d.year, d.month, d.day, hour, minute),
    ];
  }
}

/// Una ruta de bus con sus paradas y horarios.
class BusRoute {
  const BusRoute({
    required this.id,
    required this.name,
    this.code = '',
    this.colorHex,
    this.direction = RouteDirection.hotelToVenue,
    this.description = '',
    this.notice = '',
    this.headwayMinutes,
    this.polyline,
    this.stops = const [],
    this.departures = const [],
  });

  final String id;
  final String name;

  /// Etiqueta corta ("A", "B1").
  final String code;

  /// Color de la ruta en formato `#RRGGBB`. Puede faltar: la UI cae a la paleta.
  final String? colorHex;

  final RouteDirection direction;
  final String description;

  /// Aviso del organizador ("Última salida 22:30").
  final String notice;

  /// Frecuencia aproximada en minutos, si el servicio es por frecuencia en vez
  /// de por horario fijo.
  final int? headwayMinutes;

  /// Polilínea codificada de Google con el trazado. `null` → la app dibuja
  /// líneas rectas entre paradas (ver `polyline_codec.dart`).
  final String? polyline;

  final List<RouteStop> stops;
  final List<RouteDeparture> departures;

  RouteStop? get origin => stops.isEmpty ? null : stops.first;
  RouteStop? get destination => stops.isEmpty ? null : stops.last;

  /// Duración estimada del recorrido completo, según los minutos por parada que
  /// cargó el organizador. `null` si no los cargó.
  int? get totalMinutes => stops.isEmpty ? null : stops.last.minutesFromStart;

  /// Paradas con coordenadas, en orden. Es lo que se puede pintar en un mapa.
  List<RouteStop> get mappableStops =>
      stops.where((s) => s.hasCoords).toList(growable: false);

  /// La próxima salida a partir de [now], y cuándo ocurre.
  ///
  /// Devuelve `null` si ya pasaron todas las del evento (o si no hay horarios).
  ({RouteDeparture departure, DateTime at})? nextDeparture(
    DateTime now,
    List<DateTime> eventDays,
  ) {
    ({RouteDeparture departure, DateTime at})? best;
    for (final d in departures) {
      for (final at in d.occurrences(eventDays)) {
        if (!at.isAfter(now)) continue;
        if (best == null || at.isBefore(best.at)) {
          best = (departure: d, at: at);
        }
      }
    }
    return best;
  }

  /// Salidas que aplican a un día concreto, ordenadas por hora: las diarias más
  /// las que llevan esa fecha.
  List<RouteDeparture> departuresOn(DateTime day) {
    final list = departures
        .where(
          (d) =>
              d.isDaily ||
              (d.date!.year == day.year &&
                  d.date!.month == day.month &&
                  d.date!.day == day.day),
        )
        .toList();
    list.sort((a, b) => a.departTime.compareTo(b.departTime));
    return list;
  }
}

/// `"07:30"` → `(7, 30)`. `null` si no es una hora válida.
(int, int)? _parseHm(String raw) {
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return (h, m);
}
