/// Hotel recomendado / oficial para el alojamiento.
class Hotel {
  final String id;
  final String name;
  final String description;
  final String address;
  final String distance;
  final String? priceFrom;
  final String? imageUrl;
  final String? web;
  final String? phone;
  final bool isOfficial;

  const Hotel({
    required this.id,
    required this.name,
    this.description = '',
    this.address = '',
    this.distance = '',
    this.priceFrom,
    this.imageUrl,
    this.web,
    this.phone,
    this.isOfficial = false,
  });

  factory Hotel.fromJson(Map<String, dynamic> json) {
    return Hotel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      priceFrom: json['price_from'] as String?,
      imageUrl: json['image_url'] as String?,
      web: json['web'] as String?,
      phone: json['phone'] as String?,
      isOfficial: json['is_official'] as bool? ?? false,
    );
  }
}
