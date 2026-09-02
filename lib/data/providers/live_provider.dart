import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'content_providers.dart';
import 'user_provider.dart';

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

// ── Preguntas en vivo por sesión ────────────────────────────────────────────

class QuestionsNotifier extends AsyncNotifier<List<LiveQuestion>> {
  @override
  Future<List<LiveQuestion>> build() async {
    return ref.watch(ovumRepositoryProvider).getSeedQuestions();
  }

  void add(String sessionId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final author = ref.read(currentUserProvider)?.name ?? 'Anónimo';
    final current = state.valueOrNull ?? const [];
    final q = LiveQuestion(
      id: 'q${DateTime.now().microsecondsSinceEpoch}',
      sessionId: sessionId,
      text: trimmed,
      authorName: author,
      upvotes: 0,
    );
    state = AsyncData([q, ...current]);
  }

  void upvote(String id) {
    final current = state.valueOrNull ?? const [];
    state = AsyncData([
      for (final q in current)
        if (q.id == id) q.copyWith(upvotes: q.upvotes + 1) else q,
    ]);
  }
}

final questionsProvider =
    AsyncNotifierProvider<QuestionsNotifier, List<LiveQuestion>>(QuestionsNotifier.new);

/// Preguntas de una sesión, ordenadas por votos (desc).
final questionsForSessionProvider = Provider.family<List<LiveQuestion>, String>((ref, sessionId) {
  final all = ref.watch(questionsProvider).valueOrNull ?? const [];
  return all.where((q) => q.sessionId == sessionId).toList()
    ..sort((a, b) => b.upvotes.compareTo(a.upvotes));
});
