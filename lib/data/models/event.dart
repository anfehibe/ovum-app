import '../../core/utils/url_ext.dart';

/// Evento del congreso, tal como lo devuelve el API TRIVVO
/// (`GET /events` y `GET /events/{id}`). La app es de un solo evento, así que
/// normalmente se usa la primera coincidencia por `codigo`.
class Event {
  final String id;
  final String code;
  final String name;
  final String edition;
  final String city;
  final String country;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? url;
  final String? logo;
  final String? banner;
  final String? description;
  final String? venueName;

  const Event({
    required this.id,
    required this.code,
    required this.name,
    this.edition = '',
    this.city = '',
    this.country = '',
    this.startDate,
    this.endDate,
    this.url,
    this.logo,
    this.banner,
    this.description,
    this.venueName,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    String? sedeName;
    final sede = json['sede'];
    if (sede is Map) {
      sedeName = sede['nombre'] as String?;
    } else if (sede is String) {
      sedeName = sede;
    }
    return Event(
      id: '${json['id']}',
      code: json['codigo'] as String? ?? '',
      name: json['nombre'] as String? ?? '',
      edition: json['edicion'] as String? ?? '',
      city: json['ciudad'] as String? ?? '',
      country: json['pais'] as String? ?? '',
      startDate: _date(json['fecha_desde']),
      endDate: _date(json['fecha_hasta']),
      url: json['url'] as String?,
      logo: absoluteUrlOrNull(json['logo'] as String?),
      banner: absoluteUrlOrNull(json['banner'] as String?),
      description: json['descripcion'] as String?,
      venueName: sedeName,
    );
  }

  static DateTime? _date(dynamic v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
