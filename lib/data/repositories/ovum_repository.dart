import '../models/models.dart';
import 'asset_loader.dart';

/// Fuente de datos del congreso. Hoy la implementa [MockOvumRepository]
/// (JSON local); mañana podría implementarla un `ApiOvumRepository` sin
/// tocar la UI ni los providers que dependen de esta interfaz.
abstract interface class OvumRepository {
  Future<List<Session>> getSessions();
  Future<List<Speaker>> getSpeakers();
  Future<List<Sponsor>> getSponsors();
  Future<List<Exhibitor>> getExhibitors();
  Future<List<Attendee>> getAttendees();
  Future<List<Venue>> getVenues();
  Future<List<Hotel>> getHotels();
  Future<List<Organizer>> getOrganizers();
  Future<List<InfoItem>> getInfoItems();
  Future<List<Poll>> getPolls();

  /// Registra el voto del usuario en una encuesta (escritura).
  Future<void> votePoll(String pollId, int optionIndex);

  /// Imágenes de splash de la app (nivel institución).
  Future<List<SplashItem>> getSplashes();

  /// Preguntas **aprobadas** (Q&A) de una sesión, con su respuesta si existe.
  Future<List<LiveQuestion>> getSessionQuestions(String sessionId);

  /// Envía una pregunta a una sesión. Queda pendiente de moderación del organizador.
  Future<void> askQuestion(String sessionId, String question);

  Future<List<Meeting>> getSeedMeetings();
  Future<List<ChatMessage>> getSeedChatMessages();
}

/// Implementación que lee los datos simulados desde `assets/mock/*.json`.
class MockOvumRepository implements OvumRepository {
  const MockOvumRepository();

  @override
  Future<List<Session>> getSessions() async {
    final rows = await loadJsonList('assets/mock/agenda.json');
    return rows.map(Session.fromJson).toList();
  }

  @override
  Future<List<Speaker>> getSpeakers() async {
    final rows = await loadJsonList('assets/mock/speakers.json');
    return rows.map(Speaker.fromJson).toList();
  }

  @override
  Future<List<Sponsor>> getSponsors() async {
    final rows = await loadJsonList('assets/mock/sponsors.json');
    return rows.map(Sponsor.fromJson).toList();
  }

  @override
  Future<List<Exhibitor>> getExhibitors() async {
    final rows = await loadJsonList('assets/mock/exhibitors.json');
    return rows.map(Exhibitor.fromJson).toList();
  }

  @override
  Future<List<Attendee>> getAttendees() async {
    final rows = await loadJsonList('assets/mock/attendees.json');
    return rows.map(Attendee.fromJson).toList();
  }

  @override
  Future<List<Venue>> getVenues() async {
    final rows = await loadJsonList('assets/mock/venues.json');
    return rows.map(Venue.fromJson).toList();
  }

  @override
  Future<List<Hotel>> getHotels() async {
    final rows = await loadJsonList('assets/mock/hotels.json');
    return rows.map(Hotel.fromJson).toList();
  }

  @override
  Future<List<Organizer>> getOrganizers() async {
    final rows = await loadJsonList('assets/mock/organizers.json');
    return rows.map(Organizer.fromJson).toList();
  }

  @override
  Future<List<InfoItem>> getInfoItems() async {
    final rows = await loadJsonList('assets/mock/info.json');
    return rows.map(InfoItem.fromJson).toList();
  }

  @override
  Future<List<Poll>> getPolls() async {
    final rows = await loadJsonList('assets/mock/polls.json');
    return rows.map(Poll.fromJson).toList();
  }

  @override
  Future<void> votePoll(String pollId, int optionIndex) async {
    // Mock: el voto vive en memoria (pollAnswersProvider); nada que persistir.
  }

  @override
  Future<List<SplashItem>> getSplashes() async => const [];

  @override
  Future<List<LiveQuestion>> getSessionQuestions(String sessionId) async {
    final rows = await loadJsonList('assets/mock/questions.json');
    return rows
        .map(LiveQuestion.fromJson)
        .where((q) => q.sessionId == sessionId)
        .toList();
  }

  @override
  Future<void> askQuestion(String sessionId, String question) async {
    // Mock: sin backend de moderación; nada que persistir.
  }

  @override
  Future<List<Meeting>> getSeedMeetings() async {
    final rows = await loadJsonList('assets/mock/meetings.json');
    return rows.map(Meeting.fromJson).toList();
  }

  @override
  Future<List<ChatMessage>> getSeedChatMessages() async {
    final rows = await loadJsonList('assets/mock/chats.json');
    return rows.map(ChatMessage.fromJson).toList();
  }
}
