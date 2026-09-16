/// Una opción seleccionable del catálogo de networking.
///
/// El API expone **dos shapes distintos**: `sectores`/`intereses` llegan como
/// `{es, en}` (sin `clave`, y el valor que se guarda ES la etiqueta en español),
/// mientras `buscando`/`soluciones`/`regiones` llegan como `{clave, es, en, icono}`.
/// El mapper normaliza ambos aquí: [value] es siempre lo que hay que **enviar** al
/// servidor y [es] siempre lo que hay que **mostrar**.
class CatalogOption {
  final String value;
  final String es;
  final String en;

  /// Clase de FontAwesome (p. ej. `fa-dna`). La app no incluye esa fuente, así que
  /// hoy solo se guarda; los chips se renderizan sin ícono.
  final String? icon;

  const CatalogOption({
    required this.value,
    required this.es,
    this.en = '',
    this.icon,
  });
}

/// Vocabulario de networking del evento (`GET /networking/catalog`).
class NetworkingCatalog {
  final List<CatalogOption> sectors;
  final List<CatalogOption> interests;
  final List<CatalogOption> seeking;
  final List<CatalogOption> solutions;
  final List<CatalogOption> regions;

  /// Topes que el servidor aplica **en silencio** al guardar; la UI los respeta
  /// para que el usuario no pierda selecciones sin enterarse.
  final int maxSectors;
  final int maxInterests;

  const NetworkingCatalog({
    this.sectors = const [],
    this.interests = const [],
    this.seeking = const [],
    this.solutions = const [],
    this.regions = const [],
    this.maxSectors = 3,
    this.maxInterests = 7,
  });
}
