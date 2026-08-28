/// Nivel de patrocinio, con etiqueta y orden de prioridad para agrupar.
enum SponsorTier {
  diamante('Diamante', 0),
  oro('Oro', 1),
  plata('Plata', 2),
  bronce('Bronce', 3);

  const SponsorTier(this.label, this.order);
  final String label;
  final int order;

  static SponsorTier fromKey(String? key) =>
      values.firstWhere((e) => e.name == key, orElse: () => bronce);
}

/// Patrocinador del congreso.
class Sponsor {
  final String id;
  final String name;
  final SponsorTier tier;
  final String description;
  final String? logoUrl;
  final String? booth;
  final String? web;
  final String? email;
  final String? phone;

  const Sponsor({
    required this.id,
    required this.name,
    required this.tier,
    this.description = '',
    this.logoUrl,
    this.booth,
    this.web,
    this.email,
    this.phone,
  });

  factory Sponsor.fromJson(Map<String, dynamic> json) {
    return Sponsor(
      id: json['id'] as String,
      name: json['name'] as String,
      tier: SponsorTier.fromKey(json['tier'] as String?),
      description: json['description'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      booth: json['booth'] as String?,
      web: json['web'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}
