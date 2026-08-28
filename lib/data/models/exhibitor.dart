/// Expositor de la feria comercial (recinto ferial).
class Exhibitor {
  final String id;
  final String name;
  final String shortDescription;
  final String description;
  final String? logoUrl;
  final String booth;
  final String category;
  final String? web;
  final String? email;
  final String? phone;

  const Exhibitor({
    required this.id,
    required this.name,
    this.shortDescription = '',
    this.description = '',
    this.logoUrl,
    this.booth = '',
    this.category = '',
    this.web,
    this.email,
    this.phone,
  });

  /// Primera letra para agrupación alfabética.
  String get initial => name.trim().isEmpty ? '#' : name.trim()[0].toUpperCase();

  factory Exhibitor.fromJson(Map<String, dynamic> json) {
    return Exhibitor(
      id: json['id'] as String,
      name: json['name'] as String,
      shortDescription: json['short_description'] as String? ?? '',
      description: json['description'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      booth: json['booth'] as String? ?? '',
      category: json['category'] as String? ?? '',
      web: json['web'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}
