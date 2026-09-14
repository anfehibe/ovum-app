import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/session_reminders.dart';
import 'content_providers.dart';
import 'preferences.dart';
import 'user_provider.dart';

// ── Servicios ───────────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final sessionRemindersProvider = Provider<SessionReminders>(
  (ref) => SessionReminders(ref.watch(notificationServiceProvider).plugin),
);

/// Inicializa el servicio una sola vez. Se observa desde `NotificationsBootstrap`
/// (en app.dart) en lugar de `main()` para tener acceso al contenedor de Riverpod
/// y no bloquear el arranque.
final notificationsInitProvider = FutureProvider<void>(
  (ref) => ref.watch(notificationServiceProvider).init(),
);

// ── Preferencias del usuario, persistidas ───────────────────────────────────

@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.pushEnabled = true,
    this.remindersEnabled = true,
    this.leadMinutes = AppConfig.reminderLeadMinutes,
    this.promptSeen = false,
  });

  /// Recibir los avisos del congreso (push del panel).
  final bool pushEnabled;

  /// Programar recordatorios de las sesiones favoritas.
  final bool remindersEnabled;

  /// Minutos de antelación del recordatorio.
  final int leadMinutes;

  /// Si ya se mostró la hoja explicativa de permiso (solo se muestra una vez).
  final bool promptSeen;

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? remindersEnabled,
    int? leadMinutes,
    bool? promptSeen,
  }) => NotificationPrefs(
    pushEnabled: pushEnabled ?? this.pushEnabled,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    leadMinutes: leadMinutes ?? this.leadMinutes,
    promptSeen: promptSeen ?? this.promptSeen,
  );
}

class NotificationPrefsNotifier extends Notifier<NotificationPrefs> {
  static const _kPush = 'notif_push_enabled';
  static const _kReminders = 'notif_reminders_enabled';
  static const _kLead = 'notif_reminder_lead';
  static const _kPrompt = 'notif_prompt_seen';

  @override
  NotificationPrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return NotificationPrefs(
      pushEnabled: prefs.getBool(_kPush) ?? true,
      remindersEnabled: prefs.getBool(_kReminders) ?? true,
      leadMinutes: prefs.getInt(_kLead) ?? AppConfig.reminderLeadMinutes,
      promptSeen: prefs.getBool(_kPrompt) ?? false,
    );
  }

  Future<void> setPush(bool value) async {
    state = state.copyWith(pushEnabled: value);
    await ref.read(sharedPreferencesProvider).setBool(_kPush, value);
    final push = ref.read(pushRegistrationProvider.notifier);
    value ? await push.register() : await push.unregister();
  }

  Future<void> setReminders(bool value) async {
    state = state.copyWith(remindersEnabled: value);
    await ref.read(sharedPreferencesProvider).setBool(_kReminders, value);
  }

  Future<void> setLeadMinutes(int value) async {
    state = state.copyWith(leadMinutes: value);
    await ref.read(sharedPreferencesProvider).setInt(_kLead, value);
  }

  Future<void> markPromptSeen() async {
    state = state.copyWith(promptSeen: true);
    await ref.read(sharedPreferencesProvider).setBool(_kPrompt, true);
  }
}

final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
      NotificationPrefsNotifier.new,
    );

// ── Registro del token contra el backend ────────────────────────────────────

/// Mantiene el token FCM sincronizado con `POST/DELETE /me/device-token`.
///
/// El invitado no participa: no tiene Bearer y los endpoints exigen auth.
class PushRegistrationController extends Notifier<void> {
  static const _kToken = 'push_last_token';
  static const _kUser = 'push_last_user';

  @override
  void build() {
    if (!AppConfig.usePush) return;
    // FCM rota el token de vez en cuando; hay que re-registrarlo.
    final sub = ref
        .read(notificationServiceProvider)
        .onTokenRefresh
        .listen((_) => register(force: true));
    ref.onDispose(sub.cancel);
  }

  /// Registra el token del dispositivo. No hace nada si el flag está apagado,
  /// si el usuario lo desactivó, si no hay sesión con Bearer (invitado), o si
  /// ese mismo token ya se registró para este mismo usuario.
  Future<void> register({bool force = false}) async {
    if (!AppConfig.usePush || !AppConfig.useApiDeviceToken) return;
    if (!ref.read(notificationPrefsProvider).pushEnabled) return;
    if (!ref.read(authTokenStoreProvider).hasToken) return;

    final token = await ref.read(notificationServiceProvider).currentToken();
    if (token == null || token.isEmpty) return; // p. ej. simulador de iOS

    final prefs = ref.read(sharedPreferencesProvider);
    final userId = ref.read(currentUserProvider)?.id ?? '';
    if (!force &&
        prefs.getString(_kToken) == token &&
        prefs.getString(_kUser) == userId) {
      return; // ya registrado para este usuario
    }

    try {
      await ref.read(deviceTokenServiceProvider).register(token);
      await prefs.setString(_kToken, token);
      await prefs.setString(_kUser, userId);
    } catch (e) {
      // Best-effort: un fallo de push no puede romper el login.
      debugPrint('No se pudo registrar el token FCM: $e');
    }
  }

  /// Da de baja el token. **Debe correr antes de limpiar el Bearer**, o el
  /// backend respondería 401.
  Future<void> unregister() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final token = prefs.getString(_kToken);
    if (token == null || token.isEmpty) return;
    if (ref.read(authTokenStoreProvider).hasToken) {
      try {
        await ref.read(deviceTokenServiceProvider).unregister(token);
      } catch (e) {
        debugPrint('No se pudo dar de baja el token FCM: $e');
      }
    }
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }
}

final pushRegistrationProvider =
    NotifierProvider<PushRegistrationController, void>(
      PushRegistrationController.new,
    );

// ── Ruta pendiente por tap de notificación ──────────────────────────────────

/// Ruta que produjo el tap de una notificación y aún no se ha abierto.
///
/// Se guarda en vez de navegar directo porque el tap puede llegar antes de que
/// el splash termine, o con el usuario sin sesión (el router redirige a /login).
/// La UI la consume con [take] cuando puede atenderla.
class PendingRouteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String route) => state = route;

  /// Devuelve la ruta pendiente y la limpia.
  String? take() {
    final route = state;
    state = null;
    return route;
  }
}

final pendingNotificationRouteProvider =
    NotifierProvider<PendingRouteNotifier, String?>(PendingRouteNotifier.new);
