import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Tipo de biometría disponible. Solo se usa para elegir el texto del botón.
enum BiometricKind { faceId, touchId, fingerprint, none }

/// Cómo terminó una verificación local, ya traducido a algo accionable.
enum BiometricOutcome {
  ok,

  /// El usuario se echó atrás (canceló, se fue de la app, expiró). No es error.
  canceled,

  /// No hay sensor, no hay nada enrolado, o el dispositivo no tiene bloqueo.
  unavailable,

  /// Demasiados intentos fallidos.
  lockedOut,

  /// Se mostró el diálogo pero la identidad no coincidió.
  failed,

  error,
}

@immutable
class BiometricResult {
  const BiometricResult(this.outcome, {this.message});

  final BiometricOutcome outcome;

  /// Texto en español listo para pintar. `null` cuando no hay nada que decir.
  final String? message;

  bool get isOk => outcome == BiometricOutcome.ok;

  /// `true` cuando el usuario solo se arrepintió: la UI no debe mostrar error.
  bool get isSilent => outcome == BiometricOutcome.canceled;
}

/// Envuelve `local_auth`. No conoce Riverpod ni el API: solo dice si el
/// dispositivo puede verificar la identidad y devuelve el resultado traducido.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// `true` si el dispositivo puede autenticar localmente: sensor biométrico
  /// **o**, como respaldo, PIN / patrón / código. Por eso se usa
  /// `isDeviceSupported()` y no `canCheckBiometrics`, que ignora el respaldo.
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('No se pudo consultar el soporte biométrico: $e');
      return false;
    }
  }

  /// Qué biometría hay enrolada, para decidir "Face ID" vs "huella".
  ///
  /// Ojo: en Android el plugin solo reporta `strong` / `weak`, nunca
  /// `face` / `fingerprint`. Allí siempre caemos en [BiometricKind.fingerprint]
  /// y el texto es genérico; solo iOS distingue Face ID de Touch ID.
  Future<BiometricKind> availableKind() async {
    try {
      final tipos = await _auth.getAvailableBiometrics();
      if (tipos.contains(BiometricType.face)) return BiometricKind.faceId;
      if (tipos.contains(BiometricType.fingerprint)) {
        return BiometricKind.touchId;
      }
      if (tipos.isNotEmpty) return BiometricKind.fingerprint;
      return BiometricKind.none;
    } catch (e) {
      debugPrint('No se pudo consultar la biometría enrolada: $e');
      return BiometricKind.none;
    }
  }

  /// Pide la verificación. `biometricOnly: false` por decisión de producto: si
  /// la huella falla o no hay sensor, el sistema acepta PIN / patrón / código.
  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        // Los textos por defecto del plugin están en inglés y la app es
        // monolingüe en español, así que se pasan siempre. Los límites de
        // caracteres son los que documenta AndroidAuthMessages (60/60/30).
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Verifica tu identidad',
            signInHint: 'Entra a OVUM 2026 sin escribir tu contraseña',
            cancelButton: 'Cancelar',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancelar',
            localizedFallbackTitle: 'Usar código',
          ),
        ],
      );
      // En iOS un no-match devuelve `false`; Android nunca devuelve `false`
      // (lanza LocalAuthException).
      return ok
          ? const BiometricResult(BiometricOutcome.ok)
          : const BiometricResult(
              BiometricOutcome.failed,
              message: 'No pudimos verificar tu identidad. Inténtalo de nuevo.',
            );
    } on LocalAuthException catch (e) {
      return _traducir(e);
    } catch (e) {
      debugPrint('Fallo inesperado en local_auth: $e');
      return const BiometricResult(
        BiometricOutcome.error,
        message: 'No se pudo usar el desbloqueo del dispositivo.',
      );
    }
  }

  /// `LocalAuthExceptionCode` puede crecer sin que sea un cambio incompatible,
  /// así que el `switch` lleva `default` a propósito.
  BiometricResult _traducir(LocalAuthException e) {
    switch (e.code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.authInProgress:
      case LocalAuthExceptionCode.userRequestedFallback:
        return const BiometricResult(BiometricOutcome.canceled);

      case LocalAuthExceptionCode.noCredentialsSet:
        return const BiometricResult(
          BiometricOutcome.unavailable,
          message: 'Tu dispositivo no tiene bloqueo configurado. Actívalo en '
              'Ajustes para usar el acceso rápido.',
        );
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return const BiometricResult(
          BiometricOutcome.unavailable,
          message: 'No tienes huella ni rostro registrados en este dispositivo.',
        );
      case LocalAuthExceptionCode.noBiometricHardware:
        return const BiometricResult(
          BiometricOutcome.unavailable,
          message: 'Este dispositivo no tiene lector biométrico.',
        );
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return const BiometricResult(
          BiometricOutcome.unavailable,
          message: 'El sensor no está disponible en este momento.',
        );

      case LocalAuthExceptionCode.temporaryLockout:
        return const BiometricResult(
          BiometricOutcome.lockedOut,
          message: 'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
        );
      case LocalAuthExceptionCode.biometricLockout:
        return const BiometricResult(
          BiometricOutcome.lockedOut,
          message: 'La biometría se bloqueó. Desbloquea el teléfono con tu PIN '
              'o código y vuelve a intentarlo.',
        );

      case LocalAuthExceptionCode.uiUnavailable:
        // En Android esto casi siempre significa que MainActivity no es un
        // FlutterFragmentActivity. Útil dejarlo en el log.
        debugPrint('local_auth no pudo mostrar la UI: ${e.description}');
        return const BiometricResult(
          BiometricOutcome.error,
          message: 'No se pudo mostrar la verificación.',
        );

      default:
        debugPrint('local_auth ${e.code.name}: ${e.description}');
        return const BiometricResult(
          BiometricOutcome.error,
          message: 'No se pudo verificar tu identidad. Ingresa tu contraseña.',
        );
    }
  }
}
