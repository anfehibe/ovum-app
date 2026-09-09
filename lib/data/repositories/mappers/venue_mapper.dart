import '../../../core/utils/url_ext.dart';
import '../../models/venue.dart';

/// Deriva las sedes (venues) de la respuesta de agenda del API TRIVVO.
///
/// El contrato de `GET /events/{id}/agenda` es `data[] = sedes`, cada una con
/// `{id, nombre, direccion, lat, lng, planos:[{id,titulo,imagen}], sesiones:[…]}`.
/// Aquí extraemos la sede + sus planos (los planos son la novedad a mostrar).
List<Venue> venuesFromAgendaJson(List<dynamic> data) {
  final venues = <Venue>[];
  for (final v in data) {
    if (v is! Map) continue;
    final j = v.cast<String, dynamic>();
    // OJO: el backend puede mandar lat/lng como String (incluso con coma final,
    // p. ej. "14.609184161164723,") en vez de número → parseo defensivo.
    final lat = _toDouble(j['lat']);
    final lng = _toDouble(j['lng']);
    venues.add(Venue(
      id: '${j['id']}',
      name: (j['nombre'] as String?)?.trim() ?? '',
      address: (j['direccion'] as String?)?.trim() ?? '',
      lat: lat,
      lng: lng,
      // Heurística: la sede con coordenadas es el recinto físico principal.
      isPrimary: lat != null && lng != null,
      plans: _plansFrom(j['planos']),
    ));
  }
  return venues;
}

/// Convierte a double aceptando num o String; tolera coma final/espacios
/// ("14.6091," → 14.6091). Devuelve null si no es parseable.
double? _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) {
    return double.tryParse(v.trim().replaceAll(RegExp(r'[,\s]+$'), ''));
  }
  return null;
}

List<VenuePlan> _plansFrom(dynamic raw) {
  if (raw is! List) return const [];
  final out = <VenuePlan>[];
  for (final p in raw) {
    if (p is! Map) continue;
    final m = p.cast<String, dynamic>();
    final img = absoluteUrlOrNull(m['imagen'] as String?);
    if (img == null) continue; // sin imagen válida no hay plano que mostrar
    out.add(VenuePlan(
      id: '${m['id']}',
      title: (m['titulo'] as String?)?.trim() ?? '',
      imageUrl: img,
    ));
  }
  return out;
}
