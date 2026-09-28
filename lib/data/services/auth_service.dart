import '../../core/network/api_client.dart';
import '../models/app_user.dart';
import '../models/profile_edits.dart';
import '../repositories/mappers/user_mapper.dart';

/// Resultado de un login exitoso: el usuario y su token Bearer.
typedef AuthResult = ({AppUser user, String token});

/// Llamadas de autenticación de la API TRIVVO (`/login`, `/me`, `/logout` y
/// `DELETE /me`).
class AuthService {
  const AuthService(this._api);

  final ApiClient _api;

  /// Correo y contraseña se envían sin espacios en los extremos: uno de más (al
  /// pegar, o tecleado sin querer) daba 401 con la clave correcta. Los de en
  /// medio se respetan. Por aquí pasan el formulario, el acceso rápido y la
  /// reautenticación de Perfil. Coste asumido: el backend no recorta
  /// `password`, así que una clave que de verdad termine en espacio no entra.
  Future<AuthResult> login(String email, String password) async {
    final data = await _api.post(
      '/login',
      body: {'email': email.trim(), 'password': password.trim()},
    );
    final map = (data as Map).cast<String, dynamic>();
    final token = map['token'] as String;
    final user = appUserFromApiJson((map['user'] as Map).cast<String, dynamic>());
    return (user: user, token: token);
  }

  Future<AppUser> me() async {
    final data = await _api.get('/me');
    final map = (data as Map).cast<String, dynamic>();
    return appUserFromApiJson((map['user'] as Map).cast<String, dynamic>());
  }

  /// `PUT /me` → perfil general. Devuelve el usuario **como quedó en el
  /// servidor**, no lo que se mandó: es la única forma de no divergir.
  ///
  /// El body lo arma [profileUpdateBody], que es pura y está testeada, porque
  /// las omisiones que hace no son cosméticas — evitan un 500 del backend.
  Future<AppUser> updateProfile(ProfileEdits edits) async {
    final data = await _api.put('/me', body: profileUpdateBody(edits));
    final raw = data is Map ? (data['user'] ?? data['data'] ?? data) : data;
    return appUserFromApiJson((raw as Map).cast<String, dynamic>());
  }

  Future<void> logout() => _api.post('/logout');

  /// Elimina la cuenta. El backend pide la contraseña como confirmación y
  /// responde 422 si no coincide. Ver `docs/API-APP-STORE.md` §1. Se recorta
  /// igual que en [login], o no coincidiría con la que sirvió para entrar.
  Future<void> deleteAccount(String password) =>
      _api.delete('/me', body: {'password': password.trim()});
}
