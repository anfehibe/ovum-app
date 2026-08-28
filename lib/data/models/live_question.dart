/// Pregunta enviada en una sesión (módulo "Preguntas en vivo").
class LiveQuestion {
  final String id;
  final String sessionId;
  final String text;
  final String authorName;
  final int upvotes;

  const LiveQuestion({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.authorName,
    this.upvotes = 0,
  });

  LiveQuestion copyWith({int? upvotes}) => LiveQuestion(
        id: id,
        sessionId: sessionId,
        text: text,
        authorName: authorName,
        upvotes: upvotes ?? this.upvotes,
      );

  factory LiveQuestion.fromJson(Map<String, dynamic> json) => LiveQuestion(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        text: json['text'] as String,
        authorName: json['author_name'] as String? ?? 'Anónimo',
        upvotes: json['upvotes'] as int? ?? 0,
      );
}
