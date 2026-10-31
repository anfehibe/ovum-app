/// Entidad organizadora del congreso (ANAVI, ALA, etc.).
class Organizer {
  final String id;
  final String name;
  final String description;
  final String? logoUrl;
  final String? web;

  const Organizer({
    required this.id,
    required this.name,
    this.description = '',
    this.logoUrl,
    this.web,
  });
}

/// Contenido de la pantalla de organizadores: la lista más un texto
/// introductorio opcional que el API envía junto a ella (`texto`).
class OrganizersContent {
  final List<Organizer> organizers;
  final String? texto;

  const OrganizersContent({required this.organizers, this.texto});
}
