import '../../../core/utils/url_ext.dart';
import '../../models/app_user.dart';
import '../../models/social_links.dart';

/// Mapea el usuario del API TRIVVO (`/login`, `/me`) al [AppUser] de la app.
/// Une `nombre` + `apellido` en `name` y conserva los identificadores de la API
/// (`movil`, `pais_id`, `tenant_id`) para uso futuro.
///
/// Conserva `nombre` y `apellido` separados: `PUT /me` los escribe por separado.
AppUser appUserFromApiJson(Map<String, dynamic> j) {
  final nombre = (j['nombre'] as String?)?.trim() ?? '';
  final apellido = (j['apellido'] as String?)?.trim() ?? '';
  final email = j['email'] as String? ?? '';
  // Sin nombre no se deja la ficha en blanco: cae al correo. El respaldo va en
  // `firstName` porque `AppUser.name` es derivado y no admite un valor propio.
  final sinNombre = nombre.isEmpty && apellido.isEmpty;

  return AppUser(
    id: '${j['id']}',
    firstName: sinNombre ? (email.isNotEmpty ? email : 'Usuario') : nombre,
    lastName: sinNombre ? '' : apellido,
    position: j['cargo'] as String? ?? '',
    company: j['empresa'] as String? ?? '',
    email: email,
    photoUrl: absoluteUrlOrNull(j['foto'] as String?),
    city: j['ciudad'] as String? ?? '',
    // `bio` y `linkedin` los añadió el backend a `userPayload()` con `PUT /me`.
    bio: j['bio'] as String? ?? '',
    socials: SocialLinks(linkedin: j['linkedin'] as String?),
    mobile: j['movil'] as String?,
    countryId: (j['pais_id'] as num?)?.toInt(),
    tenantId: (j['tenant_id'] as num?)?.toInt(),
  );
}
