import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_token_store.dart';

/// Cliente HTTP de la API TRIVVO. Inyecta los headers comunes (`Accept`,
/// `X-Tenant` y `Authorization: Bearer` cuando hay token) y normaliza los
/// errores del backend a [ApiException].
class ApiClient {
  ApiClient(this._tokens, {Dio? dio, String? baseUrl, String? tenantSlug})
    : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl ?? AppConfig.baseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers['Accept'] = 'application/json'
      ..headers['X-Tenant'] = tenantSlug ?? AppConfig.tenantSlug;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Solo en debug y con los secretos tapados: el body de `POST /login`
          // lleva la contraseña y la respuesta el Bearer. Con `print` esto
          // acababa en logcat y en el log unificado de iOS también en release,
          // y con el acceso biométrico la contraseña se reenvía en cada
          // apertura de la app.
          if (kDebugMode) {
            debugPrint(
              'API → ${options.method} ${options.baseUrl}${options.path}',
            );
            debugPrint('  headers: ${_preview(options.headers)}');
            debugPrint('  query: ${options.queryParameters}');
            debugPrint('  body: ${_preview(options.data)}');
          }
          final token = _tokens.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            final req = response.requestOptions;
            debugPrint(
              'API ← ${response.statusCode} ${req.baseUrl}${req.path}',
            );
            debugPrint('  ${_preview(response.data)}');
          }
          handler.next(response);
        },
      ),
    );
  }

  /// Claves cuyo valor nunca se imprime.
  static const _secretas = {
    'password',
    'password_confirmation',
    'token',
    'authorization',
  };

  /// Versión imprimible de headers/body: tapa los valores sensibles y recorta.
  ///
  /// El recorte importa: `debugPrint` estrangula la salida (a diferencia del
  /// `print` anterior), y los listados del API son de decenas de KB. Sin cortar,
  /// la cola se llena y los logs siguientes llegan con minutos de retraso.
  static String _preview(Object? data) {
    final redacted = data is Map
        ? {
            for (final e in data.entries)
              e.key: _secretas.contains(e.key.toString().toLowerCase())
                  ? '***'
                  : e.value,
          }
        : data;
    final text = '$redacted';
    return text.length <= _maxLog ? text : '${text.substring(0, _maxLog)}…';
  }

  /// Caracteres que se imprimen de un body antes de recortar.
  static const _maxLog = 400;

  final Dio _dio;
  final AuthTokenStore _tokens;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body));

  /// `DELETE` con cuerpo: `DELETE /me/device-token` lee el token del body.
  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete(path, data: body));

  Future<dynamic> _send(Future<Response<dynamic>> Function() run) async {
    try {
      final res = await run();
      return res.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String message;
    if (data is Map && data['message'] is String) {
      message = data['message'] as String;
    } else {
      message = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => 'La conexión tardó demasiado.',
        DioExceptionType.connectionError => 'Sin conexión con el servidor.',
        _ => 'Ocurrió un error de red.',
      };
    }
    return ApiException(message, statusCode: status);
  }
}
