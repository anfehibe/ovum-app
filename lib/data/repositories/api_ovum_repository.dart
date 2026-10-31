import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';
import 'mappers/attendee_mapper.dart';
import 'mappers/content_mapper.dart';
import 'mappers/hotel_mapper.dart';
import 'mappers/poll_mapper.dart';
import 'mappers/question_mapper.dart';
import 'mappers/session_mapper.dart';
import 'mappers/speaker_mapper.dart';
import 'mappers/splash_mapper.dart';
import 'mappers/sponsor_mapper.dart';
import 'mappers/transport_mapper.dart';
import 'mappers/venue_mapper.dart';
import 'ovum_repository.dart';

/// Repositorio del congreso contra la API TRIVVO v1.
///
/// El `eventId` se resuelve una sola vez (vía [_eventIdResolver]) y se pasa a
/// cada llamada. Si no se puede resolver, o el endpoint falla, el error llega a
/// la pantalla: **no hay datos de demo** que lo tapen.
class ApiOvumRepository implements OvumRepository {
  ApiOvumRepository(this._api, {required Future<String> Function() eventId})
    : _eventIdResolver = eventId;

  final ApiClient _api;
  final Future<String> Function() _eventIdResolver;

  @override
  Future<List<Session>> getSessions() async {
    final id = await _eventIdResolver();
    final agendaData = await _api.get('/events/$id/agenda');
    final sessions = sessionsFromAgendaJson(_listOf(agendaData));
    // "Otras actividades" es un endpoint aparte; se une aquí (isOtherActivity=true).
    try {
      final otherData = await _api.get('/events/$id/other-activities');
      sessions.addAll(sessionsFromOtherActivitiesJson(_listOf(otherData)));
    } on ApiException {
      // No romper la agenda si el endpoint secundario falla.
    }
    return sessions;
  }

  @override
  Future<List<Attendee>> getAttendees() async {
    final id = await _eventIdResolver();
    final data = await _api.get('/events/$id/attendees');
    return _listOf(data)
        .map((e) => attendeeFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<Speaker>> getSpeakers() async {
    final id = await _eventIdResolver();
    final data = await _api.get('/events/$id/speakers');
    return _listOf(data)
        .map((e) => speakerFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<Sponsor>> getSponsors() async {
    final id = await _eventIdResolver();
    final data = await _api.get('/events/$id/sponsors');
    return _listOf(data)
        .map((e) => sponsorFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<Exhibitor>> getExhibitors() async {
    final id = await _eventIdResolver();
    final data = await _api.get('/events/$id/content/exhibitors');
    return _indexed(_listOf(data), exhibitorFromJson);
  }

  @override
  Future<OrganizersContent> getOrganizers() async {
    final id = await _eventIdResolver();
    final data = await _api.get('/events/$id/content/organizers');
    final texto = data is Map ? data['texto'] as String? : null;
    return OrganizersContent(
      organizers: _indexed(_listOf(data), organizerFromJson),
      texto: texto,
    );
  }

  @override
  Future<List<InfoItem>> getInfoItems() async {
    final id = await _eventIdResolver();
    // La pantalla de Info agrega tres tipos de contenido del backend.
    return [
      ..._indexed(await _safeList('/events/$id/content/interest'), infoFromInterest),
      ..._indexed(await _safeList('/events/$id/content/phones'), infoFromPhone),
      ..._indexed(await _safeList('/events/$id/content/services'), infoFromService),
    ];
  }

  @override
  Future<List<Poll>> getPolls() async {
    final id = await _eventIdResolver();
    final data = await _api.get('/events/$id/polls');
    return _listOf(data)
        .map((e) => pollFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> votePoll(String pollId, int optionIndex) async {
    await _api.post('/polls/$pollId/vote', body: {'option_index': optionIndex});
  }

  @override
  Future<List<Hotel>> getHotels() async {
    final id = await _eventIdResolver();
    final data = await _api.get('/events/$id/hotels');
    return _listOf(data)
        .map((e) => hotelFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<SplashItem>> getSplashes() async {
    final id = await _eventIdResolver();
    // Splash POR EVENTO: aquí viven las 2 imágenes (order:1 = pantalla splash,
    // order:2 = banner del congreso). El top-level /app/splash quedó vacío.
    final data = await _api.get('/events/$id/splash');
    return _listOf(data)
        .map((e) => splashFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<Venue>> getVenues() async {
    final id = await _eventIdResolver();
    // Las sedes (con sus planos) viven en la respuesta de agenda: data[] = sedes.
    final data = await _api.get('/events/$id/agenda');
    return venuesFromAgendaJson(_listOf(data));
  }

  @override
  Future<List<LiveQuestion>> getSessionQuestions(String sessionId) async {
    final id = await _eventIdResolver();
    // Detalle de sesión: trae las preguntas aprobadas (con respuesta si existe).
    final data = await _api.get('/events/$id/program/$sessionId');
    return questionsFromProgramJson(data, sessionId);
  }

  @override
  Future<void> askQuestion(String sessionId, String question) async {
    final id = await _eventIdResolver();
    // OJO: GET usa /program/{id} (singular); POST usa /programs/{id}/questions (plural).
    await _api.post('/events/$id/programs/$sessionId/questions',
        body: {'question': question});
  }

  @override
  Future<List<BusRoute>> getBusRoutes() async {
    final id = await _eventIdResolver();
    final data = await _api.get('/events/$id/transport/routes');
    return busRoutesFromJson(_listOf(data));
  }

  // Networking, reuniones y mensajería viven en `NetworkingService`: exigen
  // Bearer, escriben y pueden responder 403 — ver ese archivo.

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Normaliza la respuesta a una lista: acepta `{ "data": [...] }` o un array.
  List<dynamic> _listOf(dynamic data) {
    if (data is Map && data['data'] is List) return data['data'] as List;
    if (data is List) return data;
    return const [];
  }

  /// Mapea una lista cruda a modelos, pasando el índice (para ids sintéticos).
  List<T> _indexed<T>(List<dynamic> raw, T Function(Map<String, dynamic>, int) map) {
    final out = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      if (e is Map) out.add(map(e.cast<String, dynamic>(), i));
    }
    return out;
  }

  /// GET que devuelve `[]` ante un error de API (para feeds secundarios agregados).
  Future<List<dynamic>> _safeList(String path) async {
    try {
      return _listOf(await _api.get(path));
    } on ApiException {
      return const [];
    }
  }
}
