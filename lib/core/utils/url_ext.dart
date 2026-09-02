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
