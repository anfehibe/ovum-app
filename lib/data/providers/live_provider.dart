import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'content_providers.dart';

// ── Encuestas: respuesta del usuario por encuesta (pollId -> optionId) ──────

class PollAnswersNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    // Semilla con el voto previo del servidor (mi_voto) de cada encuesta cargada.
    final polls = ref.watch(pollsProvider).valueOrNull ?? const [];
    return {
      for (final p in polls)
        if (p.myVoteIndex != null) p.id: '${p.myVoteIndex}',
    };
  }

  /// Registra el voto: actualiza local (optimista) y lo envía al servidor. Si el
  /// POST falla, revierte y relanza para que la UI avise. Las opciones mock (no
  /// numéricas) solo se guardan en memoria.
  Future<void> answer(String pollId, String optionId) async {
    if (state.containsKey(pollId)) return; // no se puede cambiar la respuesta
    state = {...state, pollId: optionId};
    final index = int.tryParse(optionId);
    if (index == null) return;
    try {
      await ref.read(ovumRepositoryProvider).votePoll(pollId, index);
    } catch (_) {
      state = {...state}..remove(pollId);
      rethrow;
    }
  }
}

final pollAnswersProvider =
    NotifierProvider<PollAnswersNotifier, Map<String, String>>(PollAnswersNotifier.new);

// ── Q&A por sesión (moderado) ───────────────────────────────────────────────

/// Preguntas **aprobadas** (con respuesta si existe) de una sesión.
/// El envío de preguntas nuevas va por [ovumRepositoryProvider].askQuestion y
/// queda pendiente de moderación (no aparece hasta que el organizador la aprueba).
final sessionQuestionsProvider =
    FutureProvider.family<List<LiveQuestion>, String>((ref, sessionId) {
  return ref.watch(ovumRepositoryProvider).getSessionQuestions(sessionId);
});
