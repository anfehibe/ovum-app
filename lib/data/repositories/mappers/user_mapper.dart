import '../../../core/utils/url_ext.dart';
import '../../models/app_user.dart';

/// Mapea el usuario del API TRIVVO (`/login`, `/me`) al [AppUser] de la app.
/// Une `nombre` + `apellido` en `name` y conserva los identificadores de la API
/// (`movil`, `pais_id`, `tenant_id`) para uso futuro.
AppUser appUserFromApiJson(Map<String, dynamic> j) {
  final nombre = (j['nombre'] as String?)?.trim() ?? '';
  final apellido = (j['apellido'] as String?)?.trim() ?? '';
  final name = [nombre, apellido].where((s) => s.isNotEmpty).join(' ');
  final email = j['email'] as String? ?? '';

  return AppUser(
    id: '${j['id']}',
    name: name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Usuario'),
    position: j['cargo'] as String? ?? '',
    company: j['empresa'] as String? ?? '',
    email: email,
    photoUrl: absoluteUrlOrNull(j['foto'] as String?),
    city: j['ciudad'] as String? ?? '',
    mobile: j['movil'] as String?,
    countryId: (j['pais_id'] as num?)?.toInt(),
    tenantId: (j['tenant_id'] as num?)?.toInt(),
  );
}
