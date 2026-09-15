import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/biometric_credentials_store.dart';
import '../../core/auth/biometric_service.dart';
import '../../core/config/app_config.dart';
import 'preferences.dart';

// ── Servicios ───────────────────────────────────────────────────────────────

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(),
);

final biometricCredentialsStoreProvider = Provider<BiometricCredentialsStore>(
  (ref) => const BiometricCredentialsStore(),
);

/// ¿El dispositivo puede verificar la identidad (biometría o PIN / patrón)?
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  if (!AppConfig.useBiometricLogin) return false;
  return ref.watch(biometricServiceProvider).isAvailable();
});

/// Tipo de biometría, para decidir el texto ("Face ID" vs "tu huella").
///
/// Se cachea durante toda la vida de la app. Si alguien enrola una huella con
/// la app abierta, basta un `ref.invalidate` tras un `noBiometricsEnrolled`.
final biometricKindProvider = FutureProvider<BiometricKind>((ref) async {
  if (!AppConfig.useBiometricLogin) return BiometricKind.none;
  return ref.watch(biometricServiceProvider).availableKind();
});

// ── Preferencia del usuario, persistida ─────────────────────────────────────

@immutable
class BiometricPrefs {
  const BiometricPrefs({
    this.enabled = false,
    this.email = '',
    this.promptSeen = false,
  });

  /// El usuario activó el acceso rápido.
  final bool enabled;

  /// Correo de la cuenta guardada. No es sensible (se pinta en el botón) y vive
  /// en SharedPreferences para que `build()` pueda ser síncrono.
  final String email;

  /// Si ya se ofreció alguna vez la activación (no se insiste en cada login).
  final bool promptSeen;

  /// `true` cuando hay algo que ofrecer en la pantalla de login.
  bool get isReady => enabled && email.isNotEmpty;

  BiometricPrefs copyWith({bool? enabled, String? email, bool? promptSeen}) =>
      BiometricPrefs(
        enabled: enabled ?? this.enabled,
        email: email ?? this.email,
        promptSeen: promptSeen ?? this.promptSeen,
      );
}

class BiometricPrefsNotifier extends Notifier<BiometricPrefs> {
  static const _kEnabled = 'biometric_enabled';
  static const _kEmail = 'biometric_email';
  static const _kPrompt = 'biometric_prompt_seen';

  @override
  BiometricPrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return BiometricPrefs(
      enabled: prefs.getBool(_kEnabled) ?? false,
      email: prefs.getString(_kEmail) ?? '',
      promptSeen: prefs.getBool(_kPrompt) ?? false,
    );
  }

  /// Activa el acceso rápido. Pide la verificación **antes** de guardar nada:
  /// así el usuario comprueba en el momento que funciona, y en iOS es aquí
  /// donde aparece por primera vez el permiso de Face ID.
  Future<BiometricResult> enable({
    required String email,
    required String password,
  }) async {
    final result = await ref
        .read(biometricServiceProvider)
        .authenticate(
          reason: 'Confirma tu identidad para activar el acceso rápido',
        );
    if (!result.isOk) return result;

    try {
      await ref
          .read(biometricCredentialsStoreProvider)
          .save(email: email, password: password);
    } catch (_) {
      return const BiometricResult(
        BiometricOutcome.error,
        message: 'No se pudo guardar el acceso rápido en este dispositivo.',
      );
    }

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_kEnabled, true);
    await prefs.setString(_kEmail, email);
    await prefs.setBool(_kPrompt, true);
    state = state.copyWith(enabled: true, email: email, promptSeen: true);
    return result;
  }

  /// Apaga el acceso rápido y borra las credenciales.
  ///
  /// `promptSeen` vuelve a `false` a propósito: si esto se disparó porque la
  /// contraseña dejó de servir (401), queremos volver a ofrecerlo tras el
  /// siguiente login manual.
  Future<void> disable() async {
    await ref.read(biometricCredentialsStoreProvider).clear();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_kEnabled);
    await prefs.remove(_kEmail);
    await prefs.remove(_kPrompt);
    state = const BiometricPrefs();
  }

  Future<void> markPromptSeen() async {
    state = state.copyWith(promptSeen: true);
    await ref.read(sharedPreferencesProvider).setBool(_kPrompt, true);
  }

  /// Verifica la identidad y devuelve las credenciales guardadas.
  ///
  /// `credentials` es `null` si la verificación no pasó o si el almacén quedó
  /// inconsistente (p. ej. se restauró un backup: el flag sobrevive en
  /// SharedPreferences pero el secreto ya no se puede descifrar).
  Future<({BiometricResult result, BiometricCredentials? credentials})>
  unlock() async {
    final result = await ref
        .read(biometricServiceProvider)
        .authenticate(reason: 'Verifica tu identidad para entrar a OVUM 2026');
    if (!result.isOk) return (result: result, credentials: null);

    final creds = await ref.read(biometricCredentialsStoreProvider).read();
    if (creds == null) {
      await disable();
      return (
        result: const BiometricResult(
          BiometricOutcome.error,
          message: 'El acceso rápido dejó de estar disponible. Ingresa tu '
              'contraseña para volver a activarlo.',
        ),
        credentials: null,
      );
    }
    return (result: result, credentials: creds);
  }
}

final biometricPrefsProvider =
    NotifierProvider<BiometricPrefsNotifier, BiometricPrefs>(
      BiometricPrefsNotifier.new,
    );

// ── Oferta de activación pendiente ──────────────────────────────────────────

/// Credenciales del login que se acaba de hacer, **solo en memoria** y de un
/// solo uso.
///
/// Existen porque la oferta de activar el acceso rápido no se puede mostrar en
/// `/login`: en cuanto `AuthController.login()` cambia el estado, el `redirect`
/// de go_router reemplaza esa pantalla. La atiende `/home`, igual que la hoja
/// de permiso de notificaciones. Nunca se persisten y se limpian al consumirlas
/// o al cerrar sesión.
class PendingBiometricEnrollNotifier extends Notifier<BiometricCredentials?> {
  @override
  BiometricCredentials? build() => null;

  void offer({required String email, required String password}) =>
      state = (email: email, password: password);

  /// Devuelve las credenciales pendientes y las limpia.
  BiometricCredentials? take() {
    final creds = state;
    state = null;
    return creds;
  }

  void clear() => state = null;
}

final pendingBiometricEnrollProvider =
    NotifierProvider<PendingBiometricEnrollNotifier, BiometricCredentials?>(
      PendingBiometricEnrollNotifier.new,
    );
