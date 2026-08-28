import 'social_links.dart';

/// Usuario logueado (perfil propio). En esta versión es mock y editable localmente.
class AppUser {
  final String id;
  final String name;
  final String position;
  final String company;
  final String email;
  final String? photoUrl;
  final String bio;
  final String city;
  final String sector;
  final List<String> interests;
  final List<String> services;
  final SocialLinks socials;

  const AppUser({
    required this.id,
    required this.name,
    required this.position,
    required this.company,
    required this.email,
    this.photoUrl,
    this.bio = '',
    this.city = '',
    this.sector = '',
    this.interests = const [],
    this.services = const [],
    this.socials = const SocialLinks(),
  });

  AppUser copyWith({
    String? name,
    String? position,
    String? company,
    String? email,
    String? bio,
    String? city,
    String? sector,
    List<String>? interests,
    List<String>? services,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      position: position ?? this.position,
      company: company ?? this.company,
      email: email ?? this.email,
      photoUrl: photoUrl,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      sector: sector ?? this.sector,
      interests: interests ?? this.interests,
      services: services ?? this.services,
      socials: socials,
    );
  }

  static const AppUser guest = AppUser(
    id: 'me',
    name: 'Invitado OVUM',
    position: 'Asistente',
    company: 'OVUM 2026',
    email: '',
    bio: 'Participante del XXIX Congreso Latinoamericano de Avicultura.',
    city: 'Ciudad de Guatemala',
    sector: 'Avicultura',
    interests: ['Nutrición', 'Genética', 'Bioseguridad'],
    services: ['Networking'],
  );
}
