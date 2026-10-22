import 'package:intl/intl.dart';

/// Formateo de fechas según el idioma activo. Se usan constructores por
/// "skeleton" (p. ej. `DateFormat.MMMMd`) en vez de patrones literales para que
/// el orden y los conectores sean los correctos de cada idioma: en español
/// "11 de noviembre", en inglés "November 11".
///
/// El idioma lo toma de `Intl.defaultLocale`, que la app mantiene al día con el
/// idioma efectivo (ver `app.dart`). Requiere `initializeDateFormatting` de ese
/// locale en el arranque (ver main.dart: se cargan 'es' y 'en').
extension DateFmt on DateTime {
  String get dayName => DateFormat.EEEE().format(this); // lunes / Monday
  String get dayNameShort => toBeginningOfSentenceCase(DateFormat.E().format(this)) ?? '';
  String get monthDayShort => DateFormat.MMMd().format(this); // 11 nov / Nov 11
  String get monthDay => DateFormat.MMMMd().format(this); // 11 de noviembre / November 11
  String get fullDate => DateFormat.yMMMMEEEEd().format(this);
  String get hm => DateFormat('HH:mm').format(this);
  int get dayNumber => day;

  bool sameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

String timeRange(DateTime start, DateTime end) =>
    '${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(end)}';

/// Convierte una fecha del API (que llega como instante **UTC**, por el offset
/// `-05:00` que manda TRIVVO) a una fecha "flotante" con los MISMOS componentes
/// que muestra la app (año/mes/día/hora/min).
///
/// Las extensiones de arriba formatean **sin `.toLocal()`**, así que la agenda
/// muestra la hora UTC cruda (`08:00-05:00` se ve como "13:00"). Todo lo que
/// derive una hora real de una sesión — el botón de calendario y los
/// recordatorios locales — debe pasar por aquí para coincidir con lo mostrado.
/// Si algún día se corrige el display a hora local, basta con cambiar esto.
DateTime wallClock(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
