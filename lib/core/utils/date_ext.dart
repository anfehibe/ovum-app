import 'package:intl/intl.dart';

/// Formateo de fechas en español. Requiere `initializeDateFormatting('es')`
/// en el arranque (ver main.dart).
extension DateFmt on DateTime {
  String get dayName => DateFormat('EEEE', 'es').format(this); // lunes
  String get dayNameShort => toBeginningOfSentenceCase(DateFormat('EEE', 'es').format(this)) ?? '';
  String get monthDayShort => DateFormat('d MMM', 'es').format(this); // 11 nov
  String get monthDay => DateFormat("d 'de' MMMM", 'es').format(this);
  String get fullDate => DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(this);
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
