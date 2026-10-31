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
}
