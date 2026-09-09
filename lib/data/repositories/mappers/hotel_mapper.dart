import '../../../core/utils/url_ext.dart';
import '../../models/hotel.dart';

/// Mapea un hotel del API TRIVVO (`GET /events/{id}/hotels`) al modelo [Hotel].
///
/// Shape real: `{id, nombre, direccion, telefono, email, contacto, web,
/// reservar, agotado, descripcion, imagen, habitaciones:[…]}`.
/// `reservar`/`habitaciones` pueden venir vacíos (contrato listo, datos aún no).
Hotel hotelFromJson(Map<String, dynamic> j) {
  final rooms = _roomsFrom(j['habitaciones']);
  return Hotel(
    id: '${j['id']}',
    name: (j['nombre'] as String?)?.trim() ?? '',
    description: (j['descripcion'] as String?)?.trim() ?? '',
    address: (j['direccion'] as String?)?.trim() ?? '',
    imageUrl: absoluteUrlOrNull(j['imagen'] as String?),
    web: _clean(j['web']),
    phone: _clean(j['telefono']),
    email: _clean(j['email']),
    contact: _clean(j['contacto']),
    bookingUrl: _clean(j['reservar']),
    soldOut: j['agotado'] == true,
    rooms: rooms,
    priceFrom: _cheapest(rooms),
    // Todos los del endpoint son opciones curadas por el organizador; el sello
    // relevante aquí es "AGOTADO", no "oficial" (por eso isOfficial queda false).
  );
}

List<HotelRoom> _roomsFrom(dynamic raw) {
  if (raw is! List) return const [];
  final out = <HotelRoom>[];
  for (final r in raw) {
    if (r is! Map) continue;
    final m = r.cast<String, dynamic>();
    out.add(HotelRoom(
      id: '${m['id']}',
      name: (m['nombre'] as String?)?.trim() ?? '',
      code: _clean(m['codigo']),
      price: _clean(m['precio']),
      capacity: _toInt(m['capacidad']),
      available: _toInt(m['disponibles']),
      from: _clean(m['desde']),
      to: _clean(m['hasta']),
    ));
  }
  return out;
}

/// Precio "desde" = la tarifa más baja de las habitaciones (o `null` si no hay).
String? _cheapest(List<HotelRoom> rooms) {
  double? min;
  String? label;
  for (final r in rooms) {
    final p = double.tryParse(r.price ?? '');
    if (p == null) continue;
    if (min == null || p < min) {
      min = p;
      label = r.price;
    }
  }
  return label;
}

String? _clean(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// int desde num o String (el backend a veces manda números como texto).
int? _toInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
