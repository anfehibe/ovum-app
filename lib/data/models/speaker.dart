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
}
