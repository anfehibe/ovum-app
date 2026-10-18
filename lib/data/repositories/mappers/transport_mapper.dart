import '../../models/bus_route.dart';

/// Mapea las rutas de transporte del API TRIVVO
/// (`GET /events/{id}/transport/routes`) al modelo [BusRoute].
///
/// Shape real verificado contra producción:
/// ```json
/// { "id": 1, "nombre": "Ruta A · Zona Viva", "codigo": "A", "color": "#E8991C",
///   "sentido": "hotel_sede", "descripcion": "…", "aviso": "Última salida 22:30",
///   "frecuencia_min": 30, "trazado": "_mbxA~pmgP…", "buses": [],
///   "paradas": [ { "id": 1, "orden": 1, "tipo": "hotel", "nombre": "…",
///                  "direccion": "…", "lat": 14.599421, "lng": -90.514233,
///                  "minutos": 0, "es_final": false } ],
///   "horarios": [ { "id": 1, "fecha": null, "hora_salida": "07:00",
///                   "hora_llegada": "07:35", "nota": null, "parada_id": 1 } ] }
/// ```
///
/// `buses` se ignora a propósito: en el Nivel B siempre llega vacío y no hay
/// nada que pintar. Cuando exista el GPS en vivo será otro endpoint
/// (`/positions`), no este.
BusRoute busRouteFromJson(Map<String, dynamic> j) {
  final stops = _stopsFrom(j['paradas']);
  return BusRoute(
    id: '${j['id']}',
    name: (j['nombre'] as String?)?.trim() ?? '',
    code: (j['codigo'] as String?)?.trim() ?? '',
    colorHex: _clean(j['color']),
    direction: RouteDirection.parse(j['sentido'] as String?),
    description: (j['descripcion'] as String?)?.trim() ?? '',
    notice: (j['aviso'] as String?)?.trim() ?? '',
    headwayMinutes: _toInt(j['frecuencia_min']),
    polyline: _clean(j['trazado']),
    stops: stops,
    departures: _departuresFrom(j['horarios']),
  );
}

List<BusRoute> busRoutesFromJson(List<dynamic> data) => [
  for (final e in data)
    if (e is Map) busRouteFromJson(e.cast<String, dynamic>()),
];

List<RouteStop> _stopsFrom(dynamic raw) {
  if (raw is! List) return const [];
  final out = <RouteStop>[];
  for (final s in raw) {
    if (s is! Map) continue;
    final m = s.cast<String, dynamic>();
    out.add(
      RouteStop(
        id: '${m['id']}',
        order: _toInt(m['orden']) ?? out.length + 1,
        kind: StopKind.parse(m['tipo'] as String?),
        name: (m['nombre'] as String?)?.trim() ?? '',
        address: (m['direccion'] as String?)?.trim() ?? '',
        lat: _toDouble(m['lat']),
        lng: _toDouble(m['lng']),
        minutesFromStart: _toInt(m['minutos']),
        isTerminal: m['es_final'] == true,
      ),
    );
  }
  // El backend ya las manda ordenadas, pero el orden es lo que da sentido a la
  // pantalla entera: no dependemos de que siga siendo así.
  out.sort((a, b) => a.order.compareTo(b.order));
  return out;
}

List<RouteDeparture> _departuresFrom(dynamic raw) {
  if (raw is! List) return const [];
  final out = <RouteDeparture>[];
  for (final d in raw) {
    if (d is! Map) continue;
    final m = d.cast<String, dynamic>();
    final time = _clean(m['hora_salida']);
    if (time == null) continue; // una salida sin hora no se puede mostrar
    out.add(
      RouteDeparture(
        id: '${m['id']}',
        date: _toDate(m['fecha']),
        departTime: _hhmm(time),
        arriveTime: _clean(m['hora_llegada']) == null
            ? null
            : _hhmm(_clean(m['hora_llegada'])!),
        note: _clean(m['nota']),
        stopId: m['parada_id'] == null ? null : '${m['parada_id']}',
      ),
    );
  }
  out.sort((a, b) => a.departTime.compareTo(b.departTime));
  return out;
}

/// Recorta a `HH:mm`: el backend puede mandar `"07:00"` o `"07:00:00"`.
String _hhmm(String raw) {
  final parts = raw.trim().split(':');
  if (parts.length < 2) return raw.trim();
  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
}

/// `"2026-11-12"` → `DateTime`. `null` significa "todos los días del evento".
DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  // Solo nos interesa el día: si llegara un ISO completo, nos quedamos con la fecha.
  return DateTime.tryParse(s.length > 10 ? s.substring(0, 10) : s);
}

/// Igual de defensivo que `venue_mapper._toDouble`: las coordenadas de este
/// backend han llegado históricamente como String, incluso con coma final
/// (`"14.609184,"`), porque en `venues` se capturan en un input de texto libre.
double? _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) {
    return double.tryParse(v.trim().replaceAll(RegExp(r'[,\s]+$'), ''));
  }
  return null;
}

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

String? _clean(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}
