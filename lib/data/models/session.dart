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
  final DateTime endDate;
  final List<String> speakerIds;

  final String? sponsorName;
  final String? sponsorLogo;
  final String? imageUrl;

  final bool isOtherActivity;

  /// Grupo de agenda al que pertenece la sesión. El API TRIVVO no tiene un
  /// campo que separe el programa científico de la agenda general: usa el
  /// agrupamiento de `data[]` (sedes) para eso — la sede "Programa Científico"
  /// no tiene dirección ni coordenadas, es un contenedor lógico.
  /// Vacío en el mock y en las otras actividades.
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

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      shortDescription: json['short_description'] as String? ?? '',
      room: json['room'] as String? ?? '',
      track: json['track'] as String? ?? 'General',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      speakerIds:
          (json['speaker_ids'] as List?)?.map((e) => e as String).toList() ?? const [],
      sponsorName: json['sponsor_name'] as String?,
      sponsorLogo: json['sponsor_logo'] as String?,
      imageUrl: json['image_url'] as String?,
      isOtherActivity: json['is_other_activity'] as bool? ?? false,
      agendaGroup: json['agenda_group'] as String? ?? '',
      photos: (json['photos'] as List?)?.map((e) => e as String).toList() ?? const [],
      hasQuestions: json['has_questions'] as bool? ?? false,
      hasPolls: json['has_polls'] as bool? ?? false,
    );
  }
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
