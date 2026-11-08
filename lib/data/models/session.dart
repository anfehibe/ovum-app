/// Sesión de agenda (o "otra actividad" cuando [isOtherActivity] es true).
class Session {
  final String id;
  final String title;
  final String description;
  final String shortDescription;
  final String room;

  /// Track temático; usado para codificar por color en la UI.
  final String track;

  final DateTime startDate;

  /// Fin de la sesión. Si el organizador no indicó hora de fin ([hasEndTime]
  /// `false`), vale lo mismo que [startDate] y la UI muestra solo el inicio.
  final DateTime endDate;

  /// `false` cuando el API no trae hora de fin (los tours de "Otras
  /// actividades" llegan con `fin: null`).
  final bool hasEndTime;
  final List<String> speakerIds;

  final String? sponsorName;
  final String? sponsorLogo;
  final String? imageUrl;

  final bool isOtherActivity;

  /// Grupo de agenda al que pertenece la sesión. El API TRIVVO no tiene un
  /// campo que separe el programa científico de la agenda general: usa el
  /// agrupamiento de `data[]` (sedes) para eso — la sede "Programa Científico"
  /// no tiene dirección ni coordenadas, es un contenedor lógico.
  /// Vacío en las otras actividades.
  final String agendaGroup;

  final List<String> photos;
  final bool hasQuestions;
  final bool hasPolls;

  const Session({
    required this.id,
    required this.title,
    required this.description,
    required this.shortDescription,
    required this.room,
    required this.track,
    required this.startDate,
    required this.endDate,
    this.hasEndTime = true,
    this.speakerIds = const [],
    this.sponsorName,
    this.sponsorLogo,
    this.imageUrl,
    this.isOtherActivity = false,
    this.agendaGroup = '',
    this.photos = const [],
    this.hasQuestions = false,
    this.hasPolls = false,
  });

  Duration get duration => endDate.difference(startDate);

  /// Fecha normalizada al día (sin hora), para agrupar/filtrar por jornada.
  DateTime get day => DateTime(startDate.year, startDate.month, startDate.day);

  bool get hasGallery => photos.isNotEmpty;
}

/// Grupos de agenda distintos presentes en [sessions], en orden de primera
/// aparición — que es el orden de `data[]` (el backend ya ordena las sedes por
/// `order`). Ignora otras actividades y sesiones sin grupo.
List<String> agendaGroupsOf(Iterable<Session> sessions) {
  final out = <String>[];
  for (final s in sessions) {
    if (s.isOtherActivity || s.agendaGroup.isEmpty) continue;
    if (!out.contains(s.agendaGroup)) out.add(s.agendaGroup);
  }
  return out;
}
