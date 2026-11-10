import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics.dart';
import 'date_ext.dart';
import 'event_clock.dart';

Future<void> shareText(String text) async {
  logEvent('share');
  await SharePlus.instance.share(ShareParams(text: text));
}

Future<void> openUrl(String url) async {
  final raw = url.trim();
  if (raw.isEmpty) return;
  // Algunos enlaces del API llegan sin esquema (p. ej. "www.linkedin.com/..."),
  // lo que hace fallar canLaunchUrl. Les anteponemos https://.
  final normalized = raw.contains('://') ? raw : 'https://$raw';
  final uri = Uri.parse(normalized);
  if (await canLaunchUrl(uri)) {
    logOutboundLink(uri);
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
///
/// [start] y [end] son horas de **pared de Guatemala** (los mismos componentes
/// que muestra la app). Se convierten al instante real del congreso y se pasa la
/// zona al plugin: sin eso, quien agenda desde otra zona —antes de viajar, o con
/// el teléfono sin actualizar— vería el evento corrido una o varias horas. Lo
/// usan la agenda y el transporte.
///
/// Devuelve lo que informa el sistema: en iOS, `true` si el usuario guardó el
/// evento; en Android, si se abrió el editor.
Future<bool> addToCalendar({
  required String title,
  String description = '',
  String location = '',
  required DateTime start,
  required DateTime end,
}) async {
  if (title.trim().isEmpty) return false;
  logEvent('add_to_calendar');
  final startWall = wallClock(start);
  var endWall = wallClock(end);
  if (!endWall.isAfter(startWall)) {
    endWall = startWall.add(const Duration(hours: 1));
  }
  // El plugin envía milisegundos desde la época: un TZDateTime de Guatemala los
  // fija al instante correcto aunque el teléfono esté en otra zona.
  return Add2Calendar.addEvent2Cal(Event(
    title: title,
    description: description,
    location: location,
    startDate: eventInstant(startWall),
    endDate: eventInstant(endWall),
    timeZone: eventTimeZone,
  ));
}
