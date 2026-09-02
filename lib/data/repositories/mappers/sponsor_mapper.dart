import '../../../core/utils/url_ext.dart';
import '../../models/sponsor.dart';

/// Mapea un patrocinador del API TRIVVO (`GET /events/{id}/sponsors`) al modelo
/// [Sponsor] de la app. Shape real: `{id, nombre, logo, web, descripcion, nivel, tipo}`.
///
/// `nivel` (pivot `congreso_sponsor.level`) → [SponsorTier] por su `name`
/// (diamante/oro/plata/bronce); si no coincide, cae a `bronce`. **Verificar los
/// valores reales de `nivel` cuando el backend cargue patrocinadores.** El API v1
/// no trae booth/email/phone (→ defaults).
Sponsor sponsorFromJson(Map<String, dynamic> j) {
  return Sponsor(
    id: '${j['id']}',
    name: j['nombre'] as String? ?? '',
    tier: SponsorTier.fromKey((j['nivel'] as String?)?.toLowerCase().trim()),
    description: j['descripcion'] as String? ?? '',
    logoUrl: absoluteUrlOrNull(j['logo'] as String?),
    web: j['web'] as String?,
  );
}
