/// Imagen de splash de la app (nivel institución), del API `GET /app/splash`.
/// `link` es un enlace opcional al tocar (hoy suele venir null).
class SplashItem {
  final int order;
  final String? imageUrl;
  final String? link;

  const SplashItem({required this.order, this.imageUrl, this.link});
}
