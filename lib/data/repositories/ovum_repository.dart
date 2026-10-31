import '../models/models.dart';

/// Fuente de datos del congreso. La implementa `ApiOvumRepository` contra el
/// API TRIVVO; la UI y los providers solo dependen de esta interfaz.
///
/// No hay implementación con datos de demo a propósito: si el API falla, el
/// error llega a la pantalla en vez de disfrazarse de contenido real.
abstract interface class OvumRepository {
  Future<List<Session>> getSessions();
  Future<List<Speaker>> getSpeakers();
  Future<List<Sponsor>> getSponsors();
  Future<List<Exhibitor>> getExhibitors();
  Future<List<Attendee>> getAttendees();
  Future<List<Venue>> getVenues();
  Future<List<Hotel>> getHotels();
  Future<OrganizersContent> getOrganizers();
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

  /// Rutas de bus del congreso, con paradas y horarios.
  Future<List<BusRoute>> getBusRoutes();
}
