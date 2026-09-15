import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/secure_storage.dart';

/// Credenciales guardadas para el acceso rápido.
typedef BiometricCredentials = ({String email, String password});

/// Correo + contraseña del acceso rápido, en el Keychain / KeyStore.
///
/// El correo se duplica en SharedPreferences (ver `BiometricPrefs`) porque hay
/// que pintarlo en el botón del login y `Notifier.build()` es síncrono; aquí se
/// guarda de nuevo para que las credenciales sean un bloque coherente. La
/// contraseña **nunca** sale de este almacén.
class BiometricCredentialsStore {
  const BiometricCredentialsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? OvumSecureStorage.instance;

  static const _kEmail = 'biometric_email';
  static const _kPassword = 'biometric_password';

  final FlutterSecureStorage _storage;

  /// Propaga el error a propósito: la UI acaba de prometer activar el acceso
  /// rápido y no puede decir que sí si el almacén no aceptó el secreto.
  Future<void> save({required String email, required String password}) async {
    try {
      await _storage.write(key: _kEmail, value: email);
      await _storage.write(key: _kPassword, value: password);
    } catch (e) {
      debugPrint('No se pudieron guardar las credenciales: $e');
      rethrow;
    }
  }

  /// `null` si no hay nada guardado o si el almacén quedó inservible (por
  /// ejemplo tras restaurar un backup en otro dispositivo).
  Future<BiometricCredentials?> read() async {
    try {
      final email = await _storage.read(key: _kEmail);
      final password = await _storage.read(key: _kPassword);
      if (email == null || email.isEmpty) return null;
      if (password == null || password.isEmpty) return null;
      return (email: email, password: password);
    } catch (e) {
      debugPrint('No se pudieron leer las credenciales: $e');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _kEmail);
      await _storage.delete(key: _kPassword);
    } catch (e) {
      debugPrint('No se pudieron borrar las credenciales: $e');
    }
  }
}
