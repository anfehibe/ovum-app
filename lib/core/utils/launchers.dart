import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> shareText(String text) async {
  await SharePlus.instance.share(ShareParams(text: text));
}

Future<void> openUrl(String url) async {
  if (url.isEmpty) return;
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> openEmail(String email) async {
  if (email.isEmpty) return;
  await launchUrl(Uri(scheme: 'mailto', path: email));
}

Future<void> openPhone(String phone) async {
  if (phone.isEmpty) return;
  await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
}

/// Abre la app de calendario del teléfono con un evento **prellenado** para que
/// el usuario lo guarde. El sistema operativo pide el permiso de calendario al
/// abrir su propia UI (no se maneja permiso en la app).
Future<void> addToCalendar({
  required String title,
  String description = '',
  String location = '',
  required DateTime start,
  required DateTime end,
}) async {
  if (title.trim().isEmpty) return;
  final startWall = _wallClock(start);
  var endWall = _wallClock(end);
  if (!endWall.isAfter(startWall)) {
    endWall = startWall.add(const Duration(hours: 1));
  }
  await Add2Calendar.addEvent2Cal(Event(
    title: title,
    description: description,
    location: location,
    startDate: startWall,
    endDate: endWall,
  ));
}

/// Convierte una fecha (que del API llega en UTC, por el offset -05:00) a una
/// hora local "flotante" con los MISMOS componentes que muestra la app
/// (año/mes/día/hora/min). Así el evento del calendario coincide con la hora
/// mostrada en la agenda, sin el corrimiento que causaría un `toLocal()`.
DateTime _wallClock(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
