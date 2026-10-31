/// Opción de una encuesta en vivo. [seedVotes] son los votos que ya trae el
/// servidor (`votos`); el del usuario se suma aparte en la UI.
class PollOption {
  final String id;
  final String text;
  final int seedVotes;

  const PollOption({
    required this.id,
    required this.text,
    this.seedVotes = 0,
  });
}

/// Encuesta en vivo asociada a una sesión.
class Poll {
  final String id;
  final String sessionId;
  final String question;
  final List<PollOption> options;

  /// Índice de la opción ya votada por el usuario (del servidor), o `null`.
  final int? myVoteIndex;

  const Poll({
    required this.id,
    required this.sessionId,
    required this.question,
    this.options = const [],
    this.myVoteIndex,
  });
}
