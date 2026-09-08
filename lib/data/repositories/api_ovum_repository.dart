import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';
import 'mappers/attendee_mapper.dart';
import 'mappers/content_mapper.dart';
import 'mappers/poll_mapper.dart';
import 'mappers/session_mapper.dart';
import 'mappers/speaker_mapper.dart';
import 'mappers/splash_mapper.dart';
import 'mappers/sponsor_mapper.dart';
import 'ovum_repository.dart';

/// Repositorio híbrido: usa la API TRIVVO en los métodos con endpoint (y flag
/// activo) y **delega en [_mock]** todo lo que el API v1 aún no expone. Así la
/// app queda 100% funcional y ninguna UI se pierde mientras el backend crece.
///
/// El `eventId` se resuelve una sola vez (vía [_eventId]) y se pasa a las
/// llamadas de agenda/asistentes; si no se puede resolver, se cae al mock.
class ApiOvumRepository implements OvumRepository {
  ApiOvumRepository(
    this._api, {
    required OvumRepository fallback,
    required Future<String?> Function() eventId,
  }) : _mock = fallback,
       _eventIdResolver = eventId;

  final ApiClient _api;
  final OvumRepository _mock;
  final Future<String?> Function() _eventIdResolver;

  // ── Con endpoint en el API v1 ─────────────────────────────────────────────

  @override
  Future<List<Session>> getSessions() async {
    if (!AppConfig.useApiAgenda) return _mock.getSessions();
    final id = await _eventIdResolver();
    if (id == null) return _mock.getSessions();
    final agendaData = await _api.get('/events/$id/agenda');
    final sessions = sessionsFromAgendaJson(_listOf(agendaData));
    // "Otras actividades" es un endpoint aparte; se une aquí (isOtherActivity=true).
    if (AppConfig.useApiOtherActivities) {
      try {
        final otherData = await _api.get('/events/$id/other-activities');
        sessions.addAll(sessionsFromOtherActivitiesJson(_listOf(otherData)));
      } on ApiException {
        // No romper la agenda si el endpoint secundario falla.
      }
    }
    return sessions;
  }

  @override
  Future<List<Attendee>> getAttendees() async {
    if (!AppConfig.useApiAttendees) return _mock.getAttendees();
    final id = await _eventIdResolver();
    if (id == null) return _mock.getAttendees();
    final data = await _api.get('/events/$id/attendees');
    return _listOf(data)
        .map((e) => attendeeFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<Speaker>> getSpeakers() async {
    if (!AppConfig.useApiSpeakers) return _mock.getSpeakers();
    final id = await _eventIdResolver();
    if (id == null) return _mock.getSpeakers();
    final data = await _api.get('/events/$id/speakers');
    return _listOf(data)
        .map((e) => speakerFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<Sponsor>> getSponsors() async {
    if (!AppConfig.useApiSponsors) return _mock.getSponsors();
    final id = await _eventIdResolver();
    if (id == null) return _mock.getSponsors();
    final data = await _api.get('/events/$id/sponsors');
    return _listOf(data)
        .map((e) => sponsorFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<Exhibitor>> getExhibitors() async {
    if (!AppConfig.useApiContent) return _mock.getExhibitors();
    final id = await _eventIdResolver();
    if (id == null) return _mock.getExhibitors();
    final data = await _api.get('/events/$id/content/exhibitors');
    return _indexed(_listOf(data), exhibitorFromJson);
  }

  @override
  Future<List<Organizer>> getOrganizers() async {
    if (!AppConfig.useApiContent) return _mock.getOrganizers();
    final id = await _eventIdResolver();
    if (id == null) return _mock.getOrganizers();
    final data = await _api.get('/events/$id/content/organizers');
    return _indexed(_listOf(data), organizerFromJson);
  }

  @override
  Future<List<InfoItem>> getInfoItems() async {
    if (!AppConfig.useApiContent) return _mock.getInfoItems();
    final id = await _eventIdResolver();
    if (id == null) return _mock.getInfoItems();
    // La pantalla de Info agrega tres tipos de contenido del backend.
    return [
      ..._indexed(await _safeList('/events/$id/content/interest'), infoFromInterest),
      ..._indexed(await _safeList('/events/$id/content/phones'), infoFromPhone),
      ..._indexed(await _safeList('/events/$id/content/services'), infoFromService),
    ];
  }

  @override
  Future<List<Poll>> getPolls() async {
    if (!AppConfig.useApiPolls) return _mock.getPolls();
    final id = await _eventIdResolver();
    if (id == null) return _mock.getPolls();
    final data = await _api.get('/events/$id/polls');
    return _listOf(data)
        .map((e) => pollFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> votePoll(String pollId, int optionIndex) async {
    if (!AppConfig.useApiPolls) return _mock.votePoll(pollId, optionIndex);
    await _api.post('/polls/$pollId/vote', body: {'option_index': optionIndex});
  }

  @override
  Future<List<SplashItem>> getSplashes() async {
    if (!AppConfig.useApiSplash) return _mock.getSplashes();
    // Endpoint top-level de institución; no depende del evento (no usa eventId).
    final data = await _api.get('/app/splash');
    return _listOf(data)
        .map((e) => splashFromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ── Sin endpoint conectado todavía → mock ─────────────────────────────────
  @override
  Future<List<Venue>> getVenues() => _mock.getVenues();
  @override
  Future<List<Hotel>> getHotels() => _mock.getHotels();
  @override
  Future<List<LiveQuestion>> getSeedQuestions() => _mock.getSeedQuestions();
  @override
  Future<List<Meeting>> getSeedMeetings() => _mock.getSeedMeetings();
  @override
  Future<List<ChatMessage>> getSeedChatMessages() => _mock.getSeedChatMessages();

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
