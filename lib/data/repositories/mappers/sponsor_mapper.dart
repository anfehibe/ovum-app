import '../../../core/utils/url_ext.dart';
import '../../models/sponsor.dart';

/// Mapea un patrocinador del API TRIVVO (`GET /events/{id}/sponsors`) al modelo
/// [Sponsor] de la app. Shape real: `{id, nombre, logo, web, descripcion, nivel, tipo}`.
///
/// `nivel` (pivot `congreso_sponsor.level`) es **texto libre**: en producción ya
/// llegan `Diamante, Platino, Oro, Plata, Bronce, Media Partner, Internet Oficial,
/// Línea Aérea Oficial`. [SponsorTier.fromLabel] conserva los desconocidos con su
/// etiqueta en vez de agruparlos como "Bronce" — por eso **no** se normaliza el
/// texto aquí (bajarlo a minúsculas rompería el casing al mostrarlo). El API v1 no
/// trae booth/email/phone (→ defaults).
Sponsor sponsorFromJson(Map<String, dynamic> j) {
  return Sponsor(
    id: '${j['id']}',
    name: j['nombre'] as String? ?? '',
    tier: SponsorTier.fromLabel(j['nivel'] as String?),
    description: j['descripcion'] as String? ?? '',
    logoUrl: absoluteUrlOrNull(j['logo'] as String?),
    web: j['web'] as String?,
  );
}
