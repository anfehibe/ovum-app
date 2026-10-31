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
}
