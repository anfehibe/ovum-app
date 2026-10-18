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
  static const bool useApiSplash =
      bool.fromEnvironment('OVUM_API_SPLASH', defaultValue: true);
  static const bool useApiHotels =
      bool.fromEnvironment('OVUM_API_HOTELS', defaultValue: true);
  static const bool useApiVenues =
      bool.fromEnvironment('OVUM_API_VENUES', defaultValue: true);
  static const bool useApiQuestions =
      bool.fromEnvironment('OVUM_API_QUESTIONS', defaultValue: true);

  /// Transporte: rutas de bus hotel ↔ sede
  /// (`GET /events/{id}/transport/routes`, en producción desde el 2026-10-18).
  /// Con `=false` la sección cae al mock y sigue siendo navegable sin backend.
  static const bool useApiTransport =
      bool.fromEnvironment('OVUM_API_TRANSPORT', defaultValue: true);

  /// Mapa **embebido** en la pantalla de ruta (`google_maps_flutter`).
  ///
  /// Apagado por defecto, y es deliberado: si el SDK nativo de Google Maps no
  /// recibe su clave (`GMSServices.provideAPIKey`), **aborta la app** en cuanto
  /// se monta el primer `GoogleMap` — verificado en el spike, no es teórico:
  ///
  /// ```
  /// +[GMSServices checkServicePreconditions]  → NSException
  /// -[FGMGoogleMapFactory createWithFrame:…]
  /// ```
  ///
  /// Una guarda en `AppDelegate.swift` no basta: solo evita llamar a
  /// `provideAPIKey` con una clave vacía, que es precisamente lo que provoca el
  /// cierre. La protección que sí funciona es esta: con el flag apagado el
  /// widget `GoogleMap` **nunca se construye**, así que el SDK no se inicializa
  /// y no hay forma de que la app se caiga, esté como esté el proyecto nativo.
  ///
  /// Encenderlo exige las dos cosas a la vez:
  ///   1. `ios/Flutter/Secrets.xcconfig` con `GMS_API_KEY` válida (y el
  ///      equivalente en Android), con facturación activa en Google Cloud.
  ///   2. `--dart-define=OVUM_EMBEDDED_MAP=true`.
  ///
  /// Con clave inválida no se cae, pero el mapa sale sin teselas (marco, logo y
  /// marcador sobre fondo vacío). Ver `docs/SPIKE-IOS-MAPS.md`.
  static const bool useEmbeddedMap =
      bool.fromEnvironment('OVUM_EMBEDDED_MAP', defaultValue: false);

  /// Sección de Transporte en la app. Interruptor independiente del origen de
  /// datos: con `=false` desaparece el acceso del home aunque el API responda.
  /// Sirve para publicar la build antes de que el organizador cargue las rutas.
  static const bool showTransport =
      bool.fromEnvironment('OVUM_TRANSPORT', defaultValue: true);

  /// Networking (`/events/{id}/networking/*`): directorio, perfil, favoritos y
  /// reuniones. Apagarlo cae al **mismo camino degradado que un 403** del backend
  /// (banner + roster de solo lectura), así que sirve para probar ese estado.
  static const bool useApiNetworking =
      bool.fromEnvironment('OVUM_API_NETWORKING', defaultValue: true);

  /// Segundos entre refrescos de un hilo de chat abierto. No hay websockets ni
  /// push para mensajes (el backend solo manda correo), así que sin esto una
  /// respuesta no aparece hasta reabrir. **`0` desactiva el polling** — sirve
  /// como interruptor si molesta en desarrollo o hay que apagarlo en producción.
  static const int messagePollSeconds =
      int.fromEnvironment('OVUM_MESSAGE_POLL', defaultValue: 15);

  /// Editar y cancelar reuniones (`PUT .../meetings/{id}` y
  /// `POST .../meetings/{id}/cancel`, `docs/API-PENDIENTES.md` §A6, en
  /// producción desde el 2026-10-16). Queda como interruptor: con `=false` los
  /// botones desaparecen sin tocar el resto de la tarjeta.
  static const bool meetingEdits =
      bool.fromEnvironment('OVUM_MEETING_EDITS', defaultValue: true);

  // ── Contenido de usuarios ──────────────────────────────────────────────────

  /// Texto libre que un asistente escribe y otro lee: el chat 1 a 1, la nota y
  /// la respuesta de las solicitudes de reunión, y la bio ("Sobre") de las
  /// fichas.
  ///
  /// Al ser `const`, el gating se resuelve en compilación: con el flag apagado
  /// esas pantallas y sus rutas quedan fuera del binario.
  static const bool userContent =
      bool.fromEnvironment('OVUM_USER_CONTENT', defaultValue: true);

  // ── Legal ──────────────────────────────────────────────────────────────────

  /// Páginas legales de TRIVVO. Son globales (no por tenant) y App Store Connect
  /// enlaza la misma política.
  static const String privacyUrl = String.fromEnvironment(
    'OVUM_PRIVACY_URL',
    defaultValue: 'https://trivvo.events/politica_privacidad',
  );
  static const String termsUrl = String.fromEnvironment(
    'OVUM_TERMS_URL',
    defaultValue: 'https://trivvo.events/terms-conditions',
  );

  // ── Seguridad ──────────────────────────────────────────────────────────────

  /// Acceso rápido con huella / Face ID en la pantalla de login.
  static const bool useBiometricLogin =
      bool.fromEnvironment('OVUM_BIOMETRIC', defaultValue: true);

  // ── Diagnóstico ────────────────────────────────────────────────────────────

  /// Crashlytics: cierres inesperados y errores no capturados, en el mismo
  /// proyecto Firebase que el push. Solo **envía** fuera de debug (ver
  /// `crash_reporting.dart`). Apagarlo deja de inicializar Firebase si además
  /// el push está apagado.
  static const bool useCrashlytics =
      bool.fromEnvironment('OVUM_CRASHLYTICS', defaultValue: true);

  /// Prueba de punta a punta de Crashlytics: la app se cierra a propósito al
  /// abrir (una vez sí, una no). **Nunca en una build que se publique.**
  static const bool crashTest =
      bool.fromEnvironment('OVUM_CRASH_TEST', defaultValue: false);

  // ── Notificaciones ─────────────────────────────────────────────────────────

  /// Push (FCM). Apagarlo evita inicializar Firebase Messaging por completo.
  static const bool usePush =
      bool.fromEnvironment('OVUM_PUSH', defaultValue: true);

  /// Registro del token del dispositivo (`POST/DELETE /me/device-token`).
  static const bool useApiDeviceToken =
      bool.fromEnvironment('OVUM_API_DEVICE_TOKEN', defaultValue: true);

  /// Recordatorios locales de las sesiones favoritas (no requiere backend).
  static const bool useLocalReminders =
      bool.fromEnvironment('OVUM_LOCAL_REMINDERS', defaultValue: true);

  /// Minutos de antelación por defecto del recordatorio de sesión.
  static const int reminderLeadMinutes =
      int.fromEnvironment('OVUM_REMINDER_LEAD', defaultValue: 15);
}
