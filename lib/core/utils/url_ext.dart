/// Devuelve la URL solo si es absoluta (http/https); de lo contrario `null`.
///
/// El API TRIVVO puede responder rutas relativas placeholder para imágenes
/// (p. ej. `/img/usuario.jpg`, `/img/no_pic.jpg`) que no sirven como imagen de
/// red. Al normalizarlas a `null`, la UI cae limpiamente al avatar de iniciales
/// / placeholder en lugar de intentar (y fallar al) cargar una URL inválida.
String? absoluteUrlOrNull(String? url) {
  if (url == null) return null;
  final u = url.trim();
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  return null;
}

/// Archivos que el backend sirve como "sin foto".
const _photoPlaceholders = {'usuario.jpg', 'no_pic.jpg', 'no-pic.jpg'};

/// Como [absoluteUrlOrNull], pero además descarta los placeholders de "sin foto".
///
/// Hace falta porque el módulo de networking devuelve la foto **absoluta**
/// (`https://trivvo.events/storage/img/usuario.jpg`) en vez de la ruta relativa
/// que mandan los endpoints viejos, así que ya no basta con filtrar por relativa:
/// sin esto, todas las fichas mostrarían el mismo gris genérico en lugar del
/// avatar de iniciales.
String? personPhotoOrNull(String? url) {
  final abs = absoluteUrlOrNull(url);
  if (abs == null) return null;
  final segments = Uri.tryParse(abs)?.pathSegments ?? const <String>[];
  final file = segments.isEmpty ? '' : segments.last.toLowerCase();
  return _photoPlaceholders.contains(file) ? null : abs;
}
