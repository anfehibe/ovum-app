import 'package:shared_preferences/shared_preferences.dart';

/// Guarda el token Bearer en [SharedPreferences], con una copia en memoria para
/// lectura síncrona. Lo lee el interceptor de Dio y lo escribe el flujo de login.
///
/// (Se reusa `shared_preferences` por decisión de proyecto; para producción se
/// podría migrar a `flutter_secure_storage` sin tocar a los consumidores.)
class AuthTokenStore {
  AuthTokenStore(this._prefs) {
    _cached = _prefs.getString(_key);
  }

  static const _key = 'auth_token';

  final SharedPreferences _prefs;
  String? _cached;

  String? get token => _cached;
  bool get hasToken => _cached != null && _cached!.isNotEmpty;

  Future<void> save(String token) async {
    _cached = token;
    await _prefs.setString(_key, token);
  }

  Future<void> clear() async {
    _cached = null;
    await _prefs.remove(_key);
  }
}
