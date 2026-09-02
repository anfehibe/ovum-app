/// Opción de una encuesta en vivo. [seedVotes] simula votos previos.
class PollOption {
  final String id;
  final String text;
  final int seedVotes;

  const PollOption({
    required this.id,
    required this.text,
    this.seedVotes = 0,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
        id: json['id'] as String,
        text: json['text'] as String,
        seedVotes: json['seed_votes'] as int? ?? 0,
      );
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

  factory Poll.fromJson(Map<String, dynamic> json) => Poll(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        question: json['question'] as String,
        options: (json['options'] as List?)
                ?.map((e) => PollOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        myVoteIndex: json['my_vote_index'] as int?,
      );
}
