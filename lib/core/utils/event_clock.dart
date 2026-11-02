/// Hora del congreso, independiente de la zona horaria del teléfono.
///
/// Los horarios del evento (salidas de bus, sesiones de la agenda) son horas de
/// **pared** de Guatemala: "07:00" significa las 07:00 en Ciudad de Guatemala.
/// Compararlas con `DateTime.now()` funciona solo si el teléfono está en esa
/// zona. Quien abre la app desde Bogotá o Los Ángeles —antes de viajar, o con la
/// zona fijada a mano— vería la cuenta atrás y el calendario corridos una o
/// varias horas, y podría perder el bus. Todo lo que pregunte "¿qué hora es?" o
/// convierta una hora del evento en un instante real pasa por aquí.
library;

import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Zona horaria del congreso (Guatemala no tiene horario de verano).
const eventTimeZone = 'America/Guatemala';

bool _loaded = false;

/// Carga la base de zonas horarias una sola vez.
///
/// Es idempotente a propósito: `initializeTimeZones()` devuelve `tz.local` a UTC
/// cada vez que se llama, así que una segunda carga después de que el servicio
/// de notificaciones fijara la zona local rompería los recordatorios. Todo el
/// código de la app debe cargar la base a través de esta función.
void ensureTimeZonesLoaded() {
  if (_loaded) return;
  tz_data.initializeTimeZones();
  _loaded = true;
}

tz.Location get _eventLocation {
  ensureTimeZonesLoaded();
  return tz.getLocation(eventTimeZone);
}

/// Fuente del instante actual. Se sustituye en los tests para fijar el reloj.
DateTime Function() eventClockSource = DateTime.now;

/// Hora de pared actual en Guatemala, como `DateTime` sin zona.
///
/// Es comparable directamente con las horas del evento, que también son de
/// pared (`DateTime(2026, 11, 11, 7, 0)` = las 07:00 en Guatemala).
DateTime eventNow() => toEventWallClock(eventClockSource());

/// Convierte un instante real en la hora de pared que marca el reloj de
/// Guatemala en ese momento.
DateTime toEventWallClock(DateTime instant) {
  final t = tz.TZDateTime.from(instant, _eventLocation);
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
}

/// Instante real que corresponde a una hora de pared de Guatemala.
///
/// Es lo que hay que darle al calendario del sistema: el plugin trabaja con
/// milisegundos desde la época, así que un `DateTime` sin zona se interpretaría
/// en la zona del teléfono.
tz.TZDateTime eventInstant(DateTime wall) => tz.TZDateTime(
  _eventLocation,
  wall.year,
  wall.month,
  wall.day,
  wall.hour,
  wall.minute,
);
