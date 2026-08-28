import 'social_links.dart';

/// Conferencista / expositor académico.
class Speaker {
  final String id;
  final String name;
  final String role;
  final String company;
  final String bio;
  final String? photoUrl;
  final SocialLinks socials;
  final bool isKeynote;

  const Speaker({
    required this.id,
    required this.name,
    required this.role,
    required this.company,
    required this.bio,
    this.photoUrl,
    this.socials = const SocialLinks(),
    this.isKeynote = false,
  });

  factory Speaker.fromJson(Map<String, dynamic> json) {
    return Speaker(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String? ?? '',
      company: json['company'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      socials: SocialLinks.fromJson(json['socials'] as Map<String, dynamic>?),
      isKeynote: json['is_keynote'] as bool? ?? false,
    );
  }
}
