import '../router/route_paths.dart';

/// Traduce el `data` de una notificación a una ruta de go_router.
///
/// **Hoy devuelve `null` casi siempre**: el panel de TRIVVO envía únicamente
/// `{"origen":"panel"}` en el payload, sin ninguna clave de destino, así que
/// tocar una push solo puede abrir la app. Esta función queda lista para el día
/// en que el backend agregue `tipo` + `id` (o una `ruta` explícita); entonces no
/// hay que tocar nada más que este archivo.
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

  return switch (tipo) {
    'sesion' || 'sesión' || 'session' || 'programa' => R.session(id),
    'ponente' || 'speaker' || 'conferencista' => R.speaker(id),
    'patrocinador' || 'sponsor' => R.sponsor(id),
    'expositor' || 'exhibitor' => R.exhibitor(id),
    'asistente' || 'attendee' => R.attendee(id),
    'encuesta' || 'poll' => R.pollsFor(id),
    'pregunta' || 'question' => R.liveQuestionsFor(id),
    _ => null,
  };
}
