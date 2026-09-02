import '../../../core/utils/url_ext.dart';
import '../../models/attendee.dart';
import '../../models/social_links.dart';

/// Mapea un asistente del API TRIVVO (claves en español, `linkedin` plano) al
/// modelo [Attendee] de la app. Une `nombre` + `apellido` en un solo `name` y
/// envuelve el linkedin en [SocialLinks]. Los campos que el API v1 no entrega
/// (ciudad, país, intereses, servicios, otras redes) quedan vacíos por defecto.
Attendee attendeeFromJson(Map<String, dynamic> j) {
  final nombre = (j['nombre'] as String?)?.trim() ?? '';
  final apellido = (j['apellido'] as String?)?.trim() ?? '';
  final name = [nombre, apellido].where((s) => s.isNotEmpty).join(' ');
  final linkedin = (j['linkedin'] as String?)?.trim();

  return Attendee(
    id: '${j['id']}',
    name: name,
    position: j['cargo'] as String? ?? '',
    company: j['empresa'] as String? ?? '',
    photoUrl: absoluteUrlOrNull(j['foto'] as String?),
    bio: j['bio'] as String? ?? '',
    sector: j['sector'] as String? ?? '',
    socials: SocialLinks(
      linkedin: (linkedin != null && linkedin.isNotEmpty) ? linkedin : null,
    ),
  );
}
