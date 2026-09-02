/// Error tipado de la API TRIVVO. Envuelve el `{ "message": ... }` del backend
/// junto con el código HTTP, para que la UI decida qué mensaje mostrar.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 422; // p. ej. falta X-Tenant
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
