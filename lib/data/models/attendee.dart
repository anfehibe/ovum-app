import 'social_links.dart';

/// Asistente al congreso (perfil público, para networking).
class Attendee {
  final String id;
  final String name;
  final String position;
  final String company;
  final String? photoUrl;
  final String bio;
  final String sector;
  final String city;
  final String country;
  final List<String> interests;
  final List<String> services;
  final SocialLinks socials;

  const Attendee({
    required this.id,
    required this.name,
    required this.position,
    required this.company,
    this.photoUrl,
    this.bio = '',
    this.sector = '',
    this.city = '',
    this.country = '',
    this.interests = const [],
    this.services = const [],
    this.socials = const SocialLinks(),
  });

  factory Attendee.fromJson(Map<String, dynamic> json) {
    return Attendee(
      id: json['id'] as String,
      name: json['name'] as String,
      position: json['position'] as String? ?? '',
      company: json['company'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      bio: json['bio'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      interests: (json['interests'] as List?)?.map((e) => e as String).toList() ?? const [],
      services: (json['services'] as List?)?.map((e) => e as String).toList() ?? const [],
      socials: SocialLinks.fromJson(json['socials'] as Map<String, dynamic>?),
    );
  }
}
