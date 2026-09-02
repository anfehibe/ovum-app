import 'social_links.dart';

/// Usuario logueado (perfil propio). Puede ser un usuario real de la API o el
/// modo invitado ([guest] / [isGuest]). Se persiste localmente vía [toJson].
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

  /// Datos de la API que aún no se muestran, pero se conservan.
  final String? mobile;
  final int? countryId;
  final int? tenantId;

  /// `true` cuando la sesión es de invitado (sin token; acceso limitado).
  final bool isGuest;

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
    this.mobile,
    this.countryId,
    this.tenantId,
    this.isGuest = false,
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
      mobile: mobile,
      countryId: countryId,
      tenantId: tenantId,
      isGuest: isGuest,
    );
  }

  /// Serialización para persistencia local (claves propias de la app).
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      position: json['position'] as String? ?? '',
      company: json['company'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String? ?? '',
      city: json['city'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      interests:
          (json['interests'] as List?)?.map((e) => e as String).toList() ?? const [],
      services:
          (json['services'] as List?)?.map((e) => e as String).toList() ?? const [],
      socials: SocialLinks.fromJson(json['socials'] as Map<String, dynamic>?),
      mobile: json['mobile'] as String?,
      countryId: (json['countryId'] as num?)?.toInt(),
      tenantId: (json['tenantId'] as num?)?.toInt(),
      isGuest: json['isGuest'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'position': position,
    'company': company,
    'email': email,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'bio': bio,
    'city': city,
    'sector': sector,
    'interests': interests,
    'services': services,
    'socials': socials.toJson(),
    if (mobile != null) 'mobile': mobile,
    if (countryId != null) 'countryId': countryId,
    if (tenantId != null) 'tenantId': tenantId,
    'isGuest': isGuest,
  };

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
    isGuest: true,
  );
}
