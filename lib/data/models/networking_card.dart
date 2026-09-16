/// Ficha de un asistente en el módulo de networking.
///
/// Es el shape compartido que el API devuelve en `directory`, `favorites`,
/// `attendees/{user}` y dentro de `con` en las reuniones. **No reutiliza
/// [Attendee]** a propósito: allí `sector` es un `String` y aquí es una lista de
/// tokens, y esta ficha carga `isFavorite`, que es estado del servidor por
/// espectador.
class NetworkingCard {
  final String id;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String company;
  final String position;
  final List<String> sectors;
  final List<String> interests;
  final String bio;
  final String? linkedin;
  final String country;
  final bool isFavorite;

  /// Solo los devuelve el detalle (`GET /networking/attendees/{user}`); en las
  /// listas llegan vacíos.
  final List<String> seeking;
  final List<String> solutions;
  final List<String> regions;

  const NetworkingCard({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.photoUrl,
    this.company = '',
    this.position = '',
    this.sectors = const [],
    this.interests = const [],
    this.bio = '',
    this.linkedin,
    this.country = '',
    this.isFavorite = false,
    this.seeking = const [],
    this.solutions = const [],
    this.regions = const [],
  });

  String get name =>
      [firstName, lastName].where((p) => p.trim().isNotEmpty).join(' ').trim();

  /// "Cargo · Empresa", omitiendo lo que falte.
  String get subtitle =>
      [position, company].where((p) => p.trim().isNotEmpty).join(' · ');
}

/// Una página del directorio, con su metadata de paginación.
typedef DirectoryPage = ({
  List<NetworkingCard> items,
  int page,
  int lastPage,
  int total,
});
