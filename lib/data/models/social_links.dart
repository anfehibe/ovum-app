/// Enlaces a redes sociales / web, compartido por speakers, asistentes y sponsors.
class SocialLinks {
  final String? web;
  final String? linkedin;
  final String? twitter;
  final String? instagram;
  final String? facebook;

  const SocialLinks({
    this.web,
    this.linkedin,
    this.twitter,
    this.instagram,
    this.facebook,
  });

  factory SocialLinks.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SocialLinks();
    return SocialLinks(
      web: json['web'] as String?,
      linkedin: json['linkedin'] as String?,
      twitter: json['twitter'] as String?,
      instagram: json['instagram'] as String?,
      facebook: json['facebook'] as String?,
    );
  }

  bool get hasAny =>
      [web, linkedin, twitter, instagram, facebook].any((e) => e != null && e.isNotEmpty);

  Map<String, dynamic> toJson() => {
    if (web != null) 'web': web,
    if (linkedin != null) 'linkedin': linkedin,
    if (twitter != null) 'twitter': twitter,
    if (instagram != null) 'instagram': instagram,
    if (facebook != null) 'facebook': facebook,
  };
}
