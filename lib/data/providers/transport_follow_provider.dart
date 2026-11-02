import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'notifications_provider.dart';
import 'preferences.dart';

/// Topic de FCM de una ruta de bus.
///
/// **Espejo exacto del backend**: `trivvo/app/Console/Commands/AvisosTransporte.php`
/// publica el aviso "Tu bus sale en 15 min" en `transporte_ruta_{id}`. Si uno
/// cambia sin el otro, los avisos dejan de llegar sin ningún error visible.
String transportTopic(String routeId) => 'transporte_ruta_$routeId';

/// Rutas que el usuario sigue (quiere recibir sus avisos de salida).
///
/// Es la intención del usuario, no el estado en FCM: eso lo lleva
/// [TransportTopicsController]. Sobrevive al cierre de sesión, igual que los
/// favoritos, porque los topics no dependen de la cuenta.
class FollowedRoutesNotifier extends Notifier<Set<String>> {
  static const _key = 'notif_transport_routes';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getStringList(_key)?.toSet() ?? <String>{};
  }

  /// Sigue o deja de seguir [routeId]. Devuelve `true` si queda seguida.
  bool toggle(String routeId) {
    final next = {...state};
    final following = next.add(routeId);
    if (!following) next.remove(routeId);
    state = next;
    ref.read(sharedPreferencesProvider).setStringList(_key, next.toList());
    return following;
  }
}

final followedRoutesProvider =
    NotifierProvider<FollowedRoutesNotifier, Set<String>>(
      FollowedRoutesNotifier.new,
    );

final isRouteFollowedProvider = Provider.family<bool, String>(
  (ref, routeId) => ref.watch(followedRoutesProvider).contains(routeId),
);

/// Mantiene las suscripciones de FCM al día con lo que el usuario quiere.
///
/// Deseado = rutas seguidas, **solo si** "Avisos del congreso" está activo en
/// Perfil: apagar ese interruptor también da de baja los topics, sin tocar
/// `setPush`. Se resincroniza:
/// - al terminar de inicializar las notificaciones (cada arranque, forzado:
///   resuscribir lo que ya estaba es idempotente y repara suscripciones
///   perdidas por una reinstalación o un token nuevo);
/// - al seguir o dejar de seguir una ruta, o al cambiar las preferencias;
/// - cuando FCM rota el token;
/// - con reintentos espaciados si algo falló (en iOS, hasta que llegue APNs).
class TransportTopicsController extends Notifier<void> {
  /// Topics realmente suscritos según la última sincronización.
  static const _kSynced = 'push_transport_topics';
  static const _maxRetries = 3;

  Timer? _retry;
  int _attempts = 0;
  bool _running = false;
  bool _pending = false;

  @override
  void build() {
    ref.onDispose(() => _retry?.cancel());
    if (!AppConfig.usePush) return;
    // Oyente propio: el de `PushRegistrationController` solo existe para
    // usuarios con sesión, y los topics también sirven al invitado.
    final sub = ref
        .read(notificationServiceProvider)
        .onTokenRefresh
        .listen((_) => sync(force: true));
    ref.onDispose(sub.cancel);
  }

  /// Lleva FCM al estado deseado. Con [force], vuelve a suscribir también lo
  /// que ya figuraba como suscrito.
  Future<void> sync({bool force = false}) async {
    if (!AppConfig.usePush) return;
    if (!ref.read(notificationsInitProvider).hasValue) return;
    // Una sola sincronización a la vez; si llega otra petición, se repite al
    // terminar con el estado más reciente.
    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    try {
      final failed = await _apply(force: force);
      if (failed) {
        _scheduleRetry();
      } else {
        _attempts = 0;
      }
    } finally {
      _running = false;
    }
    if (_pending) {
      _pending = false;
      await sync();
    }
  }

  /// Devuelve `true` si alguna operación falló.
  Future<bool> _apply({required bool force}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final service = ref.read(notificationServiceProvider);
    final desired = ref.read(notificationPrefsProvider).pushEnabled
        ? ref.read(followedRoutesProvider).map(transportTopic).toSet()
        : <String>{};
    final synced = (prefs.getStringList(_kSynced) ?? const <String>[]).toSet();

    var failed = false;
    final next = {...synced};
    final toSubscribe = force ? desired : desired.difference(synced);
    for (final topic in toSubscribe) {
      if (await service.subscribeTopic(topic)) {
        next.add(topic);
      } else {
        failed = true;
      }
    }
    for (final topic in synced.difference(desired)) {
      if (await service.unsubscribeTopic(topic)) {
        next.remove(topic);
      } else {
        failed = true;
      }
    }
    await prefs.setStringList(_kSynced, next.toList());
    return failed;
  }

  void _scheduleRetry() {
    if (_attempts >= _maxRetries) return;
    _attempts++;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: 10 * _attempts), () => sync(force: true));
  }
}

final transportTopicsProvider =
    NotifierProvider<TransportTopicsController, void>(
      TransportTopicsController.new,
    );
