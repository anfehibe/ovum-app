import '../../../core/utils/url_ext.dart';
import '../../models/social_links.dart';
import '../../models/speaker.dart';

/// Mapea un ponente del API TRIVVO (`GET /events/{id}/speakers`, shape de
/// `personPayload` con detalle) al modelo [Speaker] de la app.
///
/// Shape real: `{id, nombre, cargo, foto, bio, web, redes:[{red, link}]}`.
/// Gaps del API v1 (defaults): no trae `empresa` (→ '') ni flag de keynote (→ false).
Speaker speakerFromJson(Map<String, dynamic> j) {
  final web = (j['web'] as String?)?.trim();
  return Speaker(
    id: '${j['id']}',
    name: j['nombre'] as String? ?? '',
    role: j['cargo'] as String? ?? '',
    company: '', // el payload de ponentes no incluye empresa
    bio: j['bio'] as String? ?? '',
    photoUrl: absoluteUrlOrNull(j['foto'] as String?),
    socials: _socialsFromRedes(j['redes'], web),
    isKeynote: false, // el API no distingue keynotes
  );
}

/// Convierte `redes:[{red, link}]` + el campo `web` en [SocialLinks].
SocialLinks _socialsFromRedes(dynamic redes, String? web) {
  String? webLink = (web != null && web.isNotEmpty) ? web : null;
  String? linkedin, twitter, instagram, facebook;

  if (redes is List) {
    for (final r in redes) {
      if (r is! Map) continue;
      final red = (r['red'] as String?)?.toLowerCase().trim() ?? '';
      final link = (r['link'] as String?)?.trim();
      if (link == null || link.isEmpty) continue;
      switch (red) {
        case 'linkedin':
          linkedin = link;
        case 'twitter':
        case 'x':
          twitter = link;
        case 'instagram':
          instagram = link;
        case 'facebook':
          facebook = link;
        case 'web':
        case 'website':
        case 'sitio':
          webLink ??= link;
      }
    }
  }

  return SocialLinks(
    web: webLink,
    linkedin: linkedin,
    twitter: twitter,
    instagram: instagram,
    facebook: facebook,
  );
}
