import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';
import 'biometric_provider.dart';
import 'content_providers.dart';
import 'notifications_provider.dart';
import 'preferences.dart';

// ── Tema (claro / oscuro / sistema), persistido ────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }

  void toggle() => set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ── Sesión de usuario ───────────────────────────────────────────────────────

/// Controla el usuario logueado. `null` = sin sesión (se muestra el login).
/// La sesión (usuario + token) se persiste en SharedPreferences y se restaura
/// al arrancar. El modo invitado no lleva token y tiene acceso limitado.
class AuthController extends Notifier<AppUser?> {
  static const _userKey = 'auth_user';

  @override
  AppUser? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_userKey);
    if (raw == null) return null;
    AppUser user;
    try {
      user = AppUser.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
    // Refresca el perfil en segundo plano (no bloquea el arranque). Ambas
    // tareas necesitan el Bearer, que se lee del almacén seguro de forma
    // asíncrona, así que esperan a `ready` antes de salir a la red.
    if (!user.isGuest && AppConfig.useApiAuth) {
      final tokens = ref.read(authTokenStoreProvider);
      Future.microtask(() async {
        await tokens.ready;
        await _refreshMe();
        // Reafirma el token FCM por si cambió con la app cerrada (idempotente).
        await ref.read(pushRegistrationProvider.notifier).register();
      });
    }
    return user;
  }

  /// Login real contra la API. Propaga [ApiException] en error (la UI lo maneja).
  ///
  /// [rememberForBiometrics] deja las credenciales en memoria para que `/home`
  /// pueda ofrecer el acceso rápido. Se pasa `false` cuando el login vino del
  /// propio acceso rápido o de la reautenticación en Perfil: ahí ya están
  /// guardadas y no hay nada que ofrecer.
  Future<void> login(
    String email,
    String password, {
    bool rememberForBiometrics = true,
  }) async {
    if (!AppConfig.useApiAuth) {
      // Kill-switch: comportamiento mock previo (sin red).
      _persist(AppUser.guest.copyWith(name: _nameFromEmail(email), email: email));
      return;
    }
    final result = await ref.read(authServiceProvider).login(email, password);
    await ref.read(authTokenStoreProvider).save(result.token);
    // Antes de `_persist`: en cuanto cambia el estado, el `redirect` de
    // go_router saca la pantalla de login de la pila y ya no hay dónde
    // preguntar nada.
    if (rememberForBiometrics && AppConfig.useBiometricLogin) {
      ref
          .read(pendingBiometricEnrollProvider.notifier)
          .offer(email: email, password: password);
    }
    _persist(result.user);
    // Best-effort y sin bloquear la navegación post-login.
    unawaited(ref.read(pushRegistrationProvider.notifier).register());
  }

  /// Entra en modo invitado (sin token; por ahora solo la agenda).
  ///
  /// El invitado **no recibe push**: `/me/device-token` exige Bearer, así que no
  /// hay forma de registrar su dispositivo (haría falta un topic de FCM o un
  /// endpoint sin auth, ambos cambios de backend).
  Future<void> loginAsGuest() async {
    await ref.read(authTokenStoreProvider).clear();
    _persist(AppUser.guest);
  }

  /// Revalida la sesión contra `/me`. Cierra sesión solo si el token expiró
  /// (401); ante errores de red mantiene la sesión local (backend en construcción).
  Future<void> _refreshMe() async {
    if (!ref.read(authTokenStoreProvider).hasToken) return;
    try {
      _persist(await ref.read(authServiceProvider).me());
    } on ApiException catch (e) {
      if (e.isUnauthorized) await logout();
    } catch (_) {
      // Silencioso: no cerramos sesión por fallos de red.
    }
  }

  Future<void> logout() async {
    final tokens = ref.read(authTokenStoreProvider);
    // Primero el device-token: `POST /logout` no lo borra en el backend, y una
    // vez limpiado el Bearer el DELETE respondería 401.
    await ref.read(pushRegistrationProvider.notifier).unregister();
    await ref.read(sessionRemindersProvider).cancelAll();
    if (AppConfig.useApiAuth && tokens.hasToken) {
      try {
        await ref.read(authServiceProvider).logout();
      } catch (_) {
        // Best-effort: aunque el backend falle, limpiamos la sesión local.
      }
    }
    await tokens.clear();
    await ref.read(sharedPreferencesProvider).remove(_userKey);
    // Las credenciales del acceso rápido **sobreviven** al logout a propósito:
    // el botón de huella en /login es justamente su razón de existir. Se borran
    // solo desde el interruptor de Perfil o si el backend rechaza la contraseña.
    ref.read(pendingBiometricEnrollProvider.notifier).clear();
    state = null;
  }

  void updateUser(AppUser user) => _persist(user);

  void _persist(AppUser user) {
    ref.read(sharedPreferencesProvider).setString(_userKey, json.encode(user.toJson()));
    state = user;
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._]'), ' ').trim();
    if (local.isEmpty) return AppUser.guest.name;
    return local
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AppUser?>(AuthController.new);

/// Usuario actual (o null si no hay sesión).
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider));

final isLoggedInProvider = Provider<bool>((ref) => ref.watch(authControllerProvider) != null);

/// `true` cuando la sesión activa es de invitado (sin token; acceso limitado).
final isGuestProvider =
    Provider<bool>((ref) => ref.watch(authControllerProvider)?.isGuest ?? false);
