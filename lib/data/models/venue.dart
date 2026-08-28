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
