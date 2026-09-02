import '../../models/poll.dart';

/// Mapea una encuesta en vivo del API TRIVVO (`GET /events/{id}/polls`) al
/// modelo [Poll] de la app.
///
/// Shape real: `{id, pregunta, program_id, activa,
/// opciones:[{indice, texto, votos}], mi_voto}`. `program_id` liga la encuesta a
/// la sesión; `mi_voto` es el índice ya votado por el usuario (o null).
Poll pollFromJson(Map<String, dynamic> j) {
  final opciones = j['opciones'];
  final options = <PollOption>[
    if (opciones is List)
      for (final o in opciones)
        if (o is Map)
          PollOption(
            id: '${o['indice']}',
            text: o['texto'] as String? ?? '',
            seedVotes: (o['votos'] as num?)?.toInt() ?? 0,
          ),
  ];

  final programId = j['program_id'];
  return Poll(
    id: '${j['id']}',
    sessionId: programId == null ? '' : '$programId',
    question: j['pregunta'] as String? ?? '',
    options: options,
    myVoteIndex: (j['mi_voto'] as num?)?.toInt(),
  );
}
