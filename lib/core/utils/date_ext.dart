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
