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
}
