/// Plano / mapa del recinto (una sede puede tener varios, con título).
class VenuePlan {
  final String id;
  final String title;
  final String imageUrl;

  const VenuePlan({required this.id, required this.title, required this.imageUrl});
}

/// Sede o recinto del congreso (principal o de actividades especiales).
class Venue {
  final String id;
  final String name;
  final String description;
  final String address;
  final String? imageUrl;
  final String? mapImageUrl;
  final double? lat;
  final double? lng;
  final bool isPrimary;

  /// Planos/mapas del recinto (`sede.planos[]` de la agenda del API).
  final List<VenuePlan> plans;

  const Venue({
    required this.id,
    required this.name,
    this.description = '',
    this.address = '',
    this.imageUrl,
    this.mapImageUrl,
    this.lat,
    this.lng,
    this.isPrimary = false,
    this.plans = const [],
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      mapImageUrl: json['map_image_url'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}
