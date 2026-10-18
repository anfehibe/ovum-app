import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/data/models/bus_route.dart';
import 'package:ovum/data/repositories/mappers/transport_mapper.dart';

/// Respuesta real de `GET /events/94/transport/routes` (recortada).
const _json = '''
[{
  "id": 1, "nombre": "Ruta A · Zona Viva", "codigo": "A", "color": "#E8991C",
  "sentido": "hotel_sede", "descripcion": "Recoge en los hoteles de Zona 10.",
  "aviso": "Última salida 22:30", "frecuencia_min": 30,
  "trazado": "_mbxA~pmgPKlA", "buses": [],
  "paradas": [
    { "id": 2, "orden": 2, "tipo": "sede", "nombre": "COPEREX",
      "direccion": "Calzada Atanasio Tzul 22-00 Z.12",
      "lat": 14.61, "lng": -90.52, "minutos": 25, "es_final": true },
    { "id": 1, "orden": 1, "tipo": "hotel", "nombre": "Hotel Real InterContinental",
      "direccion": "14 Calle 2-51 Z.10",
      "lat": 14.599421, "lng": -90.514233, "minutos": 0, "es_final": false }
  ],
  "horarios": [
    { "id": 1, "fecha": null, "hora_salida": "07:00", "hora_llegada": "07:35",
      "nota": null, "parada_id": 1 },
    { "id": 3, "fecha": "2026-11-12", "hora_salida": "22:30", "hora_llegada": null,
      "nota": "Cena de gala", "parada_id": 2 }
  ]
}]
''';

void main() {
  final routes = busRoutesFromJson(jsonDecode(_json) as List<dynamic>);
  final route = routes.single;

  // Los tres días del congreso.
  final eventDays = [
    DateTime(2026, 11, 11),
    DateTime(2026, 11, 12),
    DateTime(2026, 11, 13),
  ];

  group('busRouteFromJson', () {
    test('mapea los campos de la ruta', () {
      expect(route.id, '1');
      expect(route.name, 'Ruta A · Zona Viva');
      expect(route.code, 'A');
      expect(route.colorHex, '#E8991C');
      expect(route.direction, RouteDirection.hotelToVenue);
      expect(route.notice, 'Última salida 22:30');
      expect(route.headwayMinutes, 30);
      expect(route.polyline, isNotNull);
    });

    test('ordena las paradas por `orden`, no por el orden del array', () {
      // El JSON las trae al revés a propósito: el recorrido es lo que da
      // sentido a la pantalla y no podemos depender del orden de `data[]`.
      expect(route.stops.map((s) => s.id), ['1', '2']);
      expect(route.origin!.name, 'Hotel Real InterContinental');
      expect(route.destination!.name, 'COPEREX');
      expect(route.totalMinutes, 25);
    });

    test('distingue hotel de sede', () {
      expect(route.stops.first.kind, StopKind.hotel);
      expect(route.stops.last.kind, StopKind.venue);
      expect(route.stops.last.isTerminal, isTrue);
    });

    test('parsea coordenadas y las expone como mapeables', () {
      expect(route.mappableStops, hasLength(2));
      expect(route.stops.first.lat, closeTo(14.599421, 1e-6));
      expect(route.stops.first.lng, closeTo(-90.514233, 1e-6));
    });

    test('tolera lat/lng como String con coma final', () {
      // Es lo que manda el backend en `venues`, donde se capturan a mano.
      final sucio = busRoutesFromJson([
        {
          'id': 9,
          'nombre': 'R',
          'paradas': [
            {'id': 1, 'orden': 1, 'lat': '14.609184,', 'lng': ' -90.5069 '},
          ],
        },
      ]);
      expect(sucio.single.stops.single.lat, closeTo(14.609184, 1e-6));
      expect(sucio.single.stops.single.lng, closeTo(-90.5069, 1e-6));
    });

    test('normaliza la hora a HH:mm', () {
      final conSegundos = busRoutesFromJson([
        {
          'id': 9,
          'nombre': 'R',
          'horarios': [
            {'id': 1, 'hora_salida': '7:05:00', 'hora_llegada': '08:30:00'},
          ],
        },
      ]);
      expect(conSegundos.single.departures.single.departTime, '07:05');
      expect(conSegundos.single.departures.single.arriveTime, '08:30');
    });

    test('descarta una salida sin hora en vez de romper la ruta', () {
      final roto = busRoutesFromJson([
        {
          'id': 9,
          'nombre': 'R',
          'horarios': [
            {'id': 1, 'hora_salida': null},
            {'id': 2, 'hora_salida': '09:00'},
          ],
        },
      ]);
      expect(roto.single.departures, hasLength(1));
    });
  });

  group('horarios', () {
    test('una salida diaria ocurre los tres días del congreso', () {
      final diaria = route.departures.firstWhere((d) => d.isDaily);
      final ocurrencias = diaria.occurrences(eventDays);
      expect(ocurrencias, hasLength(3));
      expect(ocurrencias.first, DateTime(2026, 11, 11, 7, 0));
      expect(ocurrencias.last, DateTime(2026, 11, 13, 7, 0));
    });

    test('una salida con fecha ocurre solo ese día', () {
      final gala = route.departures.firstWhere((d) => !d.isDaily);
      expect(gala.occurrences(eventDays), [DateTime(2026, 11, 12, 22, 30)]);
      expect(gala.note, 'Cena de gala');
    });

    test('departuresOn mezcla las diarias con las del día', () {
      expect(route.departuresOn(DateTime(2026, 11, 11)), hasLength(1));
      // El día 12 hay la diaria + la de la gala.
      expect(route.departuresOn(DateTime(2026, 11, 12)), hasLength(2));
    });
  });

  group('nextDeparture', () {
    test('devuelve la siguiente del mismo día', () {
      final now = DateTime(2026, 11, 11, 6, 30);
      expect(route.nextDeparture(now, eventDays)!.at, DateTime(2026, 11, 11, 7, 0));
    });

    test('salta al día siguiente cuando ya pasó la del día', () {
      final now = DateTime(2026, 11, 11, 9, 0);
      expect(route.nextDeparture(now, eventDays)!.at, DateTime(2026, 11, 12, 7, 0));
    });

    test('justo en la hora de salida ya no cuenta como próxima', () {
      // Si el bus sale a las 07:00, a las 07:00 clavadas ya se fue.
      final now = DateTime(2026, 11, 11, 7, 0);
      expect(route.nextDeparture(now, eventDays)!.at, isNot(DateTime(2026, 11, 11, 7, 0)));
    });

    test('devuelve null cuando el congreso terminó', () {
      final now = DateTime(2026, 11, 14, 8, 0);
      expect(route.nextDeparture(now, eventDays), isNull);
    });

    test('antes del congreso apunta al primer día', () {
      final now = DateTime(2026, 10, 18, 12, 0);
      expect(route.nextDeparture(now, eventDays)!.at, DateTime(2026, 11, 11, 7, 0));
    });
  });
}
