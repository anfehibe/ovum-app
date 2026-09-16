import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/networking_card.dart';
import '../models/networking_catalog.dart';
import '../models/networking_meeting.dart';
import '../models/networking_message.dart';
import '../models/networking_profile.dart';
import '../repositories/mappers/networking_mapper.dart';

/// Acceso a `/events/{id}/networking/*` y `/events/{id}/messages` del API TRIVVO.
///
/// Va como **servicio y no como parte de `OvumRepository`** a propósito: ese
/// repositorio es "contenido del congreso que siempre devuelve algo, con gemelo
/// mock", y networking es lo contrario — exige Bearer, escribe, pagina, es por
/// espectador y **puede no estar disponible** (403 si el organizador no abrió el
/// networking o si el usuario no es asistente confirmado). Sigue el patrón de
/// [AuthService] / [DeviceTokenService].
///
/// Los errores se dejan propagar como [ApiException]: el backend ya manda su
/// `{message}` en español y la UI lo muestra tal cual, que es la única forma de
/// distinguir las dos causas del 403 (no hay endpoint que informe el estado).
class NetworkingService {
  NetworkingService(this._api, {required Future<String?> Function() eventId})
    : _eventIdResolver = eventId;

  final ApiClient _api;
  final Future<String?> Function() _eventIdResolver;

  Future<String> _eventBase() async {
    final id = await _eventIdResolver();
    if (id == null) {
      throw const ApiException('No se pudo identificar el congreso.');
    }
    return '/events/$id';
  }

  /// La mensajería cuelga de `/events/{id}/messages`, no de `/networking`, pero
  /// pasa por la misma compuerta 403 del backend.
  Future<String> _base() async => '${await _eventBase()}/networking';

  /// Vocabulario de sectores/intereses/etc. Es el **único** endpoint sin guard,
  /// así que responde aunque el networking esté cerrado.
  Future<NetworkingCatalog> catalog() async {
    final data = await _api.get('${await _base()}/catalog');
    return networkingCatalogFromJson(_data(data));
  }

  /// Perfil propio. Se usa además como **sonda de disponibilidad**: un 403 aquí es
  /// la única señal de que el networking está cerrado o el usuario no aplica.
  Future<NetworkingProfile> me() async {
    final data = await _api.get('${await _base()}/me');
    return networkingProfileFromJson(_data(data));
  }

  /// Guarda las preferencias. Devuelve el `message` del servidor.
  ///
  /// OJO: el `PUT` **no devuelve el perfil**, trunca en silencio a los topes y no
  /// escribe nada si el usuario no tiene ficha base — por eso quien llame debe
  /// releer con [me] y adoptar lo que diga el servidor.
  Future<String> saveMe({
    required List<String> sectors,
    required List<String> interests,
    required List<String> seeking,
    required List<String> solutions,
    required List<String> regions,
    NetworkingCatalog? catalog,
  }) async {
    final res = await _api.put(
      '${await _base()}/me',
      body: networkingProfileBody(
        sectors: sectors,
        interests: interests,
        seeking: seeking,
        solutions: solutions,
        regions: regions,
        catalog: catalog,
      ),
    );
    return _message(res, 'Perfil de networking guardado.');
  }

  /// Directorio paginado. `search` busca en nombre/apellido/empresa/cargo y el
  /// servidor excluye al propio usuario. `per` lo acota el backend a 10-50.
  Future<DirectoryPage> directory({
    String? search,
    String? sector,
    int page = 1,
    int per = 25,
  }) async {
    final data = await _api.get(
      '${await _base()}/directory',
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (sector != null && sector.isNotEmpty) 'sector': sector,
        'page': page,
        'per': per,
      },
    );
    return directoryPageFromJson(data);
  }

  /// Ficha individual. Devuelve 404 si esa persona ya no participa del networking.
  Future<NetworkingCard> attendee(String userId) async {
    final data = await _api.get('${await _base()}/attendees/$userId');
    return networkingCardFromJson(_data(data));
  }

  Future<List<NetworkingCard>> favorites() async {
    final data = await _api.get('${await _base()}/favorites');
    final raw = data is Map ? data['data'] : data;
    return [
      if (raw is List)
        for (final e in raw)
          if (e is Map) networkingCardFromJson(e.cast<String, dynamic>()),
    ];
  }

  /// Alterna el favorito y devuelve el valor **que quedó en el servidor**.
  Future<bool> toggleFavorite(String userId) async {
    final res = await _api.post('${await _base()}/favorites/$userId');
    return _data(res)['favorito'] == true;
  }

  Future<List<NetworkingMeeting>> meetings() async {
    final data = await _api.get('${await _base()}/meetings');
    final raw = data is Map ? data['data'] : data;
    return [
      if (raw is List)
        for (final e in raw)
          if (e is Map) networkingMeetingFromJson(e.cast<String, dynamic>()),
    ];
  }

  /// Solicita una reunión. Todos los campos son opcionales para el backend, así
  /// que se puede enviar solo con el mensaje. Devuelve el `message` del servidor.
  /// 422 si se solicita a uno mismo; 404 si el destinatario ya no es asistente.
  Future<String> requestMeeting(
    String userId, {
    String? message,
    String? date,
    String? startTime,
    String? endTime,
  }) async {
    final res = await _api.post(
      '${await _base()}/meetings/$userId',
      body: {
        if (message != null && message.isNotEmpty) 'mensaje': message,
        if (date != null && date.isNotEmpty) 'fecha': date,
        if (startTime != null && startTime.isNotEmpty) 'hora_inicio': startTime,
        if (endTime != null && endTime.isNotEmpty) 'hora_fin': endTime,
      },
    );
    return _message(res, 'Solicitud de reunión enviada.');
  }

  /// Acepta o rechaza una invitación. Solo puede el destinatario y solo mientras
  /// siga pendiente (si no, el backend responde **422** "ya fue respondida").
  /// Al aceptar auto-asigna mesa y devuelve dónde quedó.
  Future<({MeetingOutcome outcome, String message})> respondMeeting(
    String meetingId, {
    required bool accept,
  }) async {
    final res = await _api.post(
      '${await _base()}/meetings/$meetingId/respond',
      body: {'action': accept ? 'accept' : 'reject'},
    );
    return (
      outcome: meetingOutcomeFromJson(_data(res)),
      message: _message(res, accept ? 'Reunión confirmada.' : 'Reunión rechazada.'),
    );
  }

  // ── Mensajería ────────────────────────────────────────────────────────────

  /// Mis conversaciones, de la más reciente a la más antigua.
  Future<List<ConversationSummary>> conversations() async =>
      conversationsFromJson(await _api.get('${await _eventBase()}/messages'));

  /// Hilo completo con un asistente, en orden cronológico.
  Future<MessageThread> thread(String userId) async {
    final data = await _api.get('${await _eventBase()}/messages/$userId');
    return messageThreadFromJson(_data(data));
  }

  /// Envía un mensaje y devuelve el que creó el servidor (con su id y fecha
  /// reales). **422 si el congreso ya terminó** o si es uno mismo; 404 si el
  /// destinatario ya no es asistente.
  Future<NetworkingMessage> sendMessage(String userId, String text) async {
    final res = await _api.post(
      '${await _eventBase()}/messages/$userId',
      // El backend corta en 2000; recortamos igual para no mandar de más.
      body: {'texto': text.length > 2000 ? text.substring(0, 2000) : text},
    );
    return networkingMessageFromJson(_data(res));
  }

  Map<String, dynamic> _data(dynamic res) {
    final inner = res is Map ? res['data'] : null;
    return inner is Map ? inner.cast<String, dynamic>() : <String, dynamic>{};
  }

  String _message(dynamic res, String fallback) {
    final msg = res is Map ? res['message'] : null;
    return msg is String && msg.trim().isNotEmpty ? msg.trim() : fallback;
  }
}
