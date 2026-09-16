import '../router/route_paths.dart';

/// Alias que el backend podría usar para un mensaje nuevo. Una sola lista para
/// que el resolver de rutas y `chatCounterpartId` no se desincronicen.
const _tiposChat = {'chat', 'mensaje', 'message'};

/// Traduce el `data` de una notificación a una ruta de go_router.
///
/// **Hoy devuelve `null` casi siempre**: el único emisor del backend
/// (`Admin/PushController`, el envío manual del panel) manda `{"origen":"panel"}`
/// sin ninguna clave de destino, así que tocar esa push solo abre la app. La
/// función ya entiende `tipo` + `id` (o una `ruta` explícita) para cuando el
/// backend conecte los disparadores automáticos; entonces no hay que tocar nada
/// más que este archivo.
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
  // direcciona por interlocutor (`GET /messages/{userId}`).
  if (_tiposChat.contains(tipo)) return R.chatWith(id);

  return switch (tipo) {
    'sesion' || 'sesión' || 'session' || 'programa' => R.session(id),
    'ponente' || 'speaker' || 'conferencista' => R.speaker(id),
    'patrocinador' || 'sponsor' => R.sponsor(id),
    'expositor' || 'exhibitor' => R.exhibitor(id),
    'asistente' || 'attendee' => R.attendee(id),
    'encuesta' || 'poll' => R.pollsFor(id),
    'pregunta' || 'question' => R.liveQuestionsFor(id),
    // No hay ruta por reunión: la pestaña Reuniones vive dentro de /networking
    // y su TabController no está expuesto. Aterriza en Networking; abrir la
    // pestaña correcta pediría un parámetro en la ruta.
    'reunion' || 'reunión' || 'meeting' => R.networking,
    _ => null,
  };
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
