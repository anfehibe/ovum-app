import '../config/app_config.dart';
import '../router/route_paths.dart';

/// Alias que el backend podría usar para un mensaje nuevo. Una sola lista para
/// que el resolver de rutas y `chatCounterpartId` no se desincronicen.
const _tiposChat = {'chat', 'mensaje', 'message'};

/// Igual que [_tiposChat], para las reuniones (solicitud, respuesta, cambio y
/// cancelación usan el mismo `tipo`).
const _tiposReunion = {'reunion', 'reunión', 'meeting'};

/// Traduce el `data` de una notificación a una ruta de go_router.
///
/// Emisores conocidos: el envío manual del panel (`Admin/PushController`, manda
/// `{"origen":"panel"}` sin destino, así que solo abre la app), los disparadores
/// de networking (`tipo` reunion/chat + `id`) y el aviso de transporte
/// (`AvisosTransporte`: `ruta` ya construida + `tipo:'transporte'` + `id`).
///
/// Es una función pura a propósito: se puede testear sin plugins nativos.
String? resolveNotificationRoute(Map<String, dynamic> data) {
  // 1) Ruta explícita, si algún día el backend la manda ya construida.
  final raw = data['ruta'] ?? data['route'];
  if (raw is String && raw.startsWith('/')) return raw;

  // 2) Par tipo + id.
  final tipo = (data['tipo'] ?? data['type'])?.toString().toLowerCase();
  final id = (data['id'] ?? data['entity_id'])?.toString();
  if (tipo == null || id == null || id.isEmpty) return null;

  // Para un chat el `id` es el del **remitente**, no el del mensaje: el hilo se
  // direcciona por interlocutor (`GET /messages/{userId}`). Sin
  // `AppConfig.userContent` la ruta no está registrada y la push solo abre la app.
  if (_tiposChat.contains(tipo)) {
    return AppConfig.userContent ? R.chatWith(id) : null;
  }

  return switch (tipo) {
    'sesion' || 'sesión' || 'session' || 'programa' => R.session(id),
    'ponente' || 'speaker' || 'conferencista' => R.speaker(id),
    'patrocinador' || 'sponsor' => R.sponsor(id),
    'expositor' || 'exhibitor' => R.exhibitor(id),
    'asistente' || 'attendee' => R.attendee(id),
    'encuesta' || 'poll' => R.pollsFor(id),
    'pregunta' || 'question' => R.liveQuestionsFor(id),
    // Aviso de salida de bus: el `id` es el de la RUTA, no el de la salida.
    _ when _tiposTransporte.contains(tipo) => R.busRoute(id),
    // No hay ruta por reunión: la pestaña Reuniones vive dentro de /networking
    // y su TabController no está expuesto. Aterriza en Networking; abrir la
    // pestaña correcta pediría un parámetro en la ruta.
    _ when _tiposReunion.contains(tipo) => R.networking,
    _ => null,
  };
}

/// `true` si la notificación es de una reunión: alguien la pidió, la respondió,
/// la cambió o la canceló. Sirve para refrescar el listado sin esperar a que el
/// usuario lo arrastre.
bool isMeetingNotification(Map<String, dynamic> data) {
  final tipo = (data['tipo'] ?? data['type'])?.toString().toLowerCase();
  return tipo != null && _tiposReunion.contains(tipo);
}

/// Id del interlocutor si la notificación anuncia un **mensaje nuevo**; `null`
/// en cualquier otro caso.
///
/// Lo usan la pantalla de chat (para refrescar el hilo abierto sin esperar al
/// poll) y `NotificationService` (para no dibujar una notificación de un mensaje
/// que el usuario ya está viendo llegar). Pura y testeable, como el resolver.
String? chatCounterpartId(Map<String, dynamic> data) {
  final tipo = (data['tipo'] ?? data['type'])?.toString().toLowerCase();
  if (tipo == null || !_tiposChat.contains(tipo)) return null;
  final id = (data['id'] ?? data['entity_id'])?.toString();
  return (id == null || id.isEmpty) ? null : id;
}

/// Alias del aviso de salida de bus (`AvisosTransporte` usa `transporte`).
const _tiposTransporte = {'transporte', 'transport', 'ruta', 'bus'};

/// `true` si la notificación es de transporte: por su `tipo` o porque su `ruta`
/// apunta a una pantalla de transporte. Sirve para refrescar los horarios.
bool isTransportNotification(Map<String, dynamic> data) {
  final tipo = (data['tipo'] ?? data['type'])?.toString().toLowerCase();
  if (tipo != null && _tiposTransporte.contains(tipo)) return true;
  final ruta = (data['ruta'] ?? data['route'])?.toString();
  return ruta != null && ruta.startsWith('/transport');
}
