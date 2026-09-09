/// Pregunta de una sesión (módulo Q&A). El flujo real del API es **moderado**:
/// el asistente envía la pregunta y el organizador la aprueba/responde; aquí solo
/// se listan las **aprobadas**, con su `answer` cuando ya fue respondida.
class LiveQuestion {
  final String id;
  final String sessionId;
  final String question;
  final String? answer;

  const LiveQuestion({
    required this.id,
    required this.sessionId,
    required this.question,
    this.answer,
  });

  bool get isAnswered => answer != null && answer!.trim().isNotEmpty;

  factory LiveQuestion.fromJson(Map<String, dynamic> json) => LiveQuestion(
        id: '${json['id']}',
        sessionId: (json['session_id'] as String?) ?? '',
        // Acepta el shape mock (`text`) y el del API (`question`/`pregunta`).
        question: (json['question'] ?? json['pregunta'] ?? json['text'] ?? '') as String,
        answer: (json['answer'] ?? json['respuesta']) as String?,
      );
}
