/// Configuración de la API TRIVVO.
///
/// Los valores se pueden sobreescribir en tiempo de compilación con
/// `--dart-define` (p. ej. `--dart-define=OVUM_TENANT=anavi`). Ver la sección
/// de verificación del plan para los valores reales a confirmar con backend.
abstract final class AppConfig {
  /// Institución (tenant). Se envía como header `X-Tenant` en cada petición.
  static const String tenantSlug =
      String.fromEnvironment('OVUM_TENANT', defaultValue: 'anavi');

  /// Base URL del API. Por defecto usa host fijo + header `X-Tenant`.
  /// Alternativas: `https://{slug}.trivvo.events/api/v1` · local `http://trivvo.test/api/v1`.
  static const String baseUrl = String.fromEnvironment(
    'OVUM_API_BASE',
    defaultValue: 'https://trivvo.events/api/v1',
  );

  /// Código del evento a mostrar; se resuelve a un `id` vía `GET /events`.
  static const String eventCode =
      String.fromEnvironment('OVUM_EVENT_CODE', defaultValue: 'OVUM 2026');

  // ── Flags de activación por fuente de datos (rollout escalonado) ──────────
  // El API v1 aún está en construcción. Hoy se conecta lo soportado; el resto
  // queda en mock hasta que su endpoint exista. Encender cada uno la próxima
  // semana = poner el flag en `true` + agregar su mapper. NO se elimina UI.

  static const bool useApiAuth =
      bool.fromEnvironment('OVUM_API_AUTH', defaultValue: true);
  static const bool useApiEvents =
      bool.fromEnvironment('OVUM_API_EVENTS', defaultValue: true);
  static const bool useApiAgenda =
      bool.fromEnvironment('OVUM_API_AGENDA', defaultValue: true);
  static const bool useApiAttendees =
      bool.fromEnvironment('OVUM_API_ATTENDEES', defaultValue: true);
  static const bool useApiSpeakers =
      bool.fromEnvironment('OVUM_API_SPEAKERS', defaultValue: true);
  static const bool useApiSponsors =
      bool.fromEnvironment('OVUM_API_SPONSORS', defaultValue: true);
  static const bool useApiOtherActivities =
      bool.fromEnvironment('OVUM_API_OTHER_ACTIVITIES', defaultValue: true);
  static const bool useApiContent =
      bool.fromEnvironment('OVUM_API_CONTENT', defaultValue: true);
  static const bool useApiPolls =
      bool.fromEnvironment('OVUM_API_POLLS', defaultValue: true);

  // Pendientes de endpoint (siguen en mock):
  static const bool useApiVenues = false;
  static const bool useApiHotels = false;
  static const bool useApiQuestions = false;
  static const bool useApiMeetings = false;
  static const bool useApiChat = false;
}
