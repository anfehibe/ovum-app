import '../../../core/constants/app_strings.dart';
import '../../../core/utils/url_ext.dart';
import '../../models/session.dart';

/// Aplana la agenda del API TRIVVO a la lista plana de [Session] que consume la
/// app. El contrato real es `data[] = sedes/venues`, cada una con `sesiones[]`,
/// y cada sesión embebe `ponentes`, `sponsor` y `features` (qa/ponentes).
List<Session> sessionsFromAgendaJson(List<dynamic> venues) {
  final sessions = <Session>[];
  for (final venue in venues) {
    if (venue is! Map) continue;
    final venueName = venue['nombre'] as String?;
    final group = _agendaGroupOf(venue);
    final sesiones = venue['sesiones'];
    if (sesiones is! List) continue;
    for (final s in sesiones) {
      if (s is! Map) continue;
      final session =
          _sessionFromSesion(s.cast<String, dynamic>(), venueName, group);
      if (session != null) sessions.add(session);
    }
  }
  return sessions;
}

/// Mapea las "otras actividades" del API (`GET /events/{id}/other-activities`,
/// un endpoint aparte) a [Session] con `isOtherActivity: true`, para alimentar
/// la pantalla "Otras actividades" sin tocar su UI.
/// Shape real: `{id, titulo, tipo, descripcion, inicio, fin, imagen}`.
List<Session> sessionsFromOtherActivitiesJson(List<dynamic> items) {
  final sessions = <Session>[];
  for (final a in items) {
    if (a is! Map) continue;
    final j = a.cast<String, dynamic>();
    final start = DateTime.tryParse(j['inicio'] as String? ?? '');
    final end = DateTime.tryParse(j['fin'] as String? ?? '');
    if (start == null || end == null) continue;
    final tipo = (j['tipo'] as String?)?.trim();
    sessions.add(Session(
      id: '${j['id']}',
      title: j['titulo'] as String? ?? '',
      description: j['descripcion'] as String? ?? '',
      shortDescription: '',
      room: '',
      track: (tipo != null && tipo.isNotEmpty) ? tipo : 'General',
      startDate: start,
      endDate: end,
      imageUrl: absoluteUrlOrNull(j['imagen'] as String?),
      isOtherActivity: true,
    ));
  }
  return sessions;
}

/// Etiqueta del grupo de agenda de una entrada de `data[]`.
///
/// Una entrada con dirección, coordenadas o planos es un recinto físico → sus
/// sesiones son la agenda general del congreso. Una sin nada de eso es un
/// contenedor lógico (hoy "Programa Científico") y se etiqueta con su propio
/// nombre. Genérico a propósito: si mañana agregan otro bloque, aparece solo.
String _agendaGroupOf(Map venue) {
  final address = (venue['direccion'] as String?)?.trim() ?? '';
  final hasCoords = venue['lat'] != null || venue['lng'] != null;
  final planos = venue['planos'];
  final hasPlans = planos is List && planos.isNotEmpty;
  if (address.isNotEmpty || hasCoords || hasPlans) return AppStrings.agendaGeneral;
  return (venue['nombre'] as String?)?.trim() ?? '';
}

Session? _sessionFromSesion(
    Map<String, dynamic> j, String? venueName, String agendaGroup) {
  // Fechas ISO-8601 con offset -05:00 (America/Bogota). Sin horario no va a la agenda.
  final start = DateTime.tryParse(j['inicio'] as String? ?? '');
  final end = DateTime.tryParse(j['fin'] as String? ?? '');
  if (start == null || end == null) return null;

  final sala = (j['sala'] as String?)?.trim();
  final tipo = (j['tipo'] as String?)?.trim();

  // Ponentes embebidos → ids (el roster completo llega por GET /events/{id}/speakers).
  final ponentes = j['ponentes'];
  final speakerIds = <String>[
    if (ponentes is List)
      for (final p in ponentes)
        if (p is Map && p['id'] != null) '${p['id']}',
  ];

  // Sponsor por sesión: { nombre, logo } | null.
  String? sponsorName;
  String? sponsorLogo;
  final sponsor = j['sponsor'];
  if (sponsor is Map) {
    sponsorName = sponsor['nombre'] as String?;
    sponsorLogo = absoluteUrlOrNull(sponsor['logo'] as String?);
  }

  // features: { ponentes: bool, qa: bool }.
  final features = j['features'];
  final hasQuestions = features is Map && features['qa'] == true;

  return Session(
    id: '${j['id']}',
    title: j['titulo'] as String? ?? '',
    description: j['descripcion'] as String? ?? '',
    shortDescription: '',
    room: (sala != null && sala.isNotEmpty) ? sala : (venueName ?? ''),
    track: (tipo != null && tipo.isNotEmpty) ? tipo : 'General',
    startDate: start,
    endDate: end,
    speakerIds: speakerIds,
    sponsorName: sponsorName,
    sponsorLogo: sponsorLogo,
    hasQuestions: hasQuestions,
    // El API v1 no expone flag de encuestas por sesión (se revisita en el paso de polls).
    hasPolls: false,
    isOtherActivity: false,
    agendaGroup: agendaGroup,
  );
}
