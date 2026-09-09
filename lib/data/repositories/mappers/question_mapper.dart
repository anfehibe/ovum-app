import '../../models/live_question.dart';

/// Extrae las preguntas aprobadas (Q&A) del detalle de una sesión del API TRIVVO.
///
/// `GET /events/{id}/program/{programId}` responde
/// `{ data: { ...sesión..., preguntas: [ {id, pregunta, respuesta} ] } }`.
List<LiveQuestion> questionsFromProgramJson(dynamic data, String sessionId) {
  final root = data is Map ? data['data'] : null;
  final preguntas = root is Map ? root['preguntas'] : null;
  if (preguntas is! List) return const [];
  final out = <LiveQuestion>[];
  for (final p in preguntas) {
    if (p is! Map) continue;
    final m = p.cast<String, dynamic>();
    final q = (m['pregunta'] as String?)?.trim() ?? '';
    if (q.isEmpty) continue;
    final a = (m['respuesta'] as String?)?.trim();
    out.add(LiveQuestion(
      id: '${m['id']}',
      sessionId: sessionId,
      question: q,
      answer: (a != null && a.isNotEmpty) ? a : null,
    ));
  }
  return out;
}
