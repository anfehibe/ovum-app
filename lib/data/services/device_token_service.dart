import 'dart:io' show Platform;

import '../../core/network/api_client.dart';

/// Registro del token FCM del dispositivo en el backend TRIVVO.
///
/// Ambos endpoints exigen Bearer, así que **en modo invitado no aplican**.
/// `POST` es un upsert idempotente sobre el valor del token, de modo que
/// reintentar es inofensivo.
class DeviceTokenService {
  const DeviceTokenService(this._api);

  final ApiClient _api;

  Future<void> register(String token) => _api.post(
    '/me/device-token',
    body: {'token': token, 'platform': _platform},
  );

  /// `POST /logout` no borra el token en el backend: hay que llamar esto antes
  /// de cerrar sesión, mientras el Bearer sigue vivo.
  Future<void> unregister(String token) =>
      _api.delete('/me/device-token', body: {'token': token});

  /// El backend acepta hasta 20 caracteres.
  String get _platform => Platform.isIOS ? 'ios' : 'android';
}
