import 'networking_card.dart';

/// Perfil de networking del usuario actual (`GET /networking/me`).
///
/// No se guarda el `activo` del API: `guard()` ya devuelve 403 cuando el usuario
/// no puede usar networking, así que en toda respuesta 200 llega `true` y no
/// aporta nada. El 403 es la única señal real.
class NetworkingProfile {
  /// Ficha propia. `isFavorite` siempre llega `false` en este endpoint.
  final NetworkingCard card;

  final List<String> sectors;
  final List<String> interests;
  final List<String> seeking;
  final List<String> solutions;
  final List<String> regions;

  const NetworkingProfile({
    required this.card,
    this.sectors = const [],
    this.interests = const [],
    this.seeking = const [],
    this.solutions = const [],
    this.regions = const [],
  });

  /// `true` si el usuario no ha elegido nada todavía.
  bool get isEmpty =>
      sectors.isEmpty &&
      interests.isEmpty &&
      seeking.isEmpty &&
      solutions.isEmpty &&
      regions.isEmpty;

  NetworkingProfile copyWith({
    NetworkingCard? card,
    List<String>? sectors,
    List<String>? interests,
    List<String>? seeking,
    List<String>? solutions,
    List<String>? regions,
  }) {
    return NetworkingProfile(
      card: card ?? this.card,
      sectors: sectors ?? this.sectors,
      interests: interests ?? this.interests,
      seeking: seeking ?? this.seeking,
      solutions: solutions ?? this.solutions,
      regions: regions ?? this.regions,
    );
  }
}
