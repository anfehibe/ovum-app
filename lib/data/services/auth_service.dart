import '../../core/network/api_client.dart';
import '../models/app_user.dart';
import '../repositories/mappers/user_mapper.dart';

/// Resultado de un login exitoso: el usuario y su token Bearer.
typedef AuthResult = ({AppUser user, String token});

/// Llamadas de autenticación de la API TRIVVO (`/login`, `/me`, `/logout`).
class AuthService {
  const AuthService(this._api);

  final ApiClient _api;

  Future<AuthResult> login(String email, String password) async {
    final data = await _api.post(
      '/login',
      body: {'email': email, 'password': password},
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

  Future<void> logout() => _api.post('/logout');
}
