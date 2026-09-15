import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/secure_storage.dart';

/// Guarda el token Bearer en el Keychain (iOS) / KeyStore (Android), con una
/// copia en memoria para lectura síncrona.
///
/// El interceptor de Dio consulta [token] en cada request y no puede esperar un
/// `Future`, pero leer el Keychain/KeyStore sí es asíncrono. La instancia se
/// construye de forma síncrona y arranca la lectura en segundo plano: quien
/// necesite el token antes de usarlo espera a [ready] (lo hace el splash, que
/// de todos modos dura unos segundos). Así no se bloquea el primer frame —
/// medido en ~900 ms en un emulador Android con el KeyStore recién creado.
class AuthTokenStore {
  AuthTokenStore(this._prefs, {FlutterSecureStorage? storage})
    : _storage = storage ?? OvumSecureStorage.instance {
    _ready = _load();
  }

  static const _key = 'auth_token';

  late final Future<void> _ready;

  /// Se completa cuando el token ya se leyó del almacén seguro. Hasta entonces
  /// [token] es `null` y las peticiones saldrían sin Bearer.
  Future<void> get ready => _ready;

  /// Lee el token del almacén seguro y migra, una sola vez, el que los usuarios
  /// de versiones ≤ 0.4.0 tienen en SharedPreferences.
  ///
  /// Nunca lanza: si el almacén seguro falla (KeyStore inservible tras
  /// restaurar un backup, por ejemplo) la app queda sin sesión en vez de no
  /// arrancar.
  Future<void> _load() async {
    String? token;
    try {
      token = await _storage.read(key: _key);
    } catch (e) {
      debugPrint('No se pudo leer el token del almacén seguro: $e');
    }

    final legacy = _prefs.getString(_key);
    if (token != null && token.isNotEmpty) {
      // Ya migrado en un arranque anterior; se limpia el resto en claro.
      if (legacy != null) await _prefs.remove(_key);
    } else if (legacy != null && legacy.isNotEmpty) {
      token = legacy; // la sesión sigue viva desde este mismo arranque
      try {
        await _storage.write(key: _key, value: legacy);
        await _prefs.remove(_key); // solo si la escritura funcionó
      } catch (e) {
        // Se deja en SharedPreferences y se reintenta el próximo arranque:
        // borrarlo aquí desconectaría al usuario sin necesidad.
        debugPrint('No se pudo migrar el token al almacén seguro: $e');
      }
    }

    // Si mientras se leía hubo un login o un logout, ese valor manda: lo
    // contrario restauraría un token que el usuario acaba de invalidar.
    if (!_touched) _cached = token;
  }

  final FlutterSecureStorage _storage;
  final SharedPreferences _prefs;
  String? _cached;

  /// `true` en cuanto [save] o [clear] fijan el token, para que una carga que
  /// termine tarde no pise la decisión más reciente.
  bool _touched = false;

  String? get token => _cached;
  bool get hasToken => _cached != null && _cached!.isNotEmpty;

  Future<void> save(String token) async {
    _touched = true;
    _cached = token; // primero la RAM: el interceptor ya puede usarlo
    try {
      await _storage.write(key: _key, value: token);
    } catch (e) {
      // No se propaga: el backend ya emitió el token y la sesión funciona en
      // este arranque. Fallar aquí haría ver un login correcto como error y
      // además abortaría el registro del token FCM.
      debugPrint('No se pudo persistir el token: $e');
    }
  }

  Future<void> clear() async {
    _touched = true;
    _cached = null;
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('No se pudo borrar el token del almacén seguro: $e');
    }
    await _prefs.remove(_key); // defensivo: por si quedó de una versión previa
  }
}
