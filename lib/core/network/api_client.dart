import 'package:dio/dio.dart';

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
          print(
            'API request: ${options.method} ${options.baseUrl}${options.path}',
          );
          final token = _tokens.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          print(
            'API response: ${response.statusCode}${response.requestOptions.baseUrl}${response.requestOptions.path}',
          );
          print(response.data.toString());
          handler.next(response);
        },
      ),
    );
  }

  final Dio _dio;
  final AuthTokenStore _tokens;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body));

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
