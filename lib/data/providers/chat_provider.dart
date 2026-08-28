import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'content_providers.dart';

/// Mensajería 1-a-1 (mock, en memoria). Guarda todos los mensajes y expone
/// vistas derivadas por conversación.
class ChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  @override
  Future<List<ChatMessage>> build() async {
    final seed = await ref.watch(ovumRepositoryProvider).getSeedChatMessages();
    return [...seed]..sort((a, b) => a.time.compareTo(b.time));
  }

  void send(String attendeeId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = state.valueOrNull ?? const [];
    final msg = ChatMessage(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      attendeeId: attendeeId,
      text: trimmed,
      sentByMe: true,
      time: DateTime.now(),
    );
    state = AsyncData([...current, msg]);
  }
}

final chatProvider =
    AsyncNotifierProvider<ChatNotifier, List<ChatMessage>>(ChatNotifier.new);

/// Mensajes de una conversación concreta, en orden cronológico.
final conversationProvider = Provider.family<List<ChatMessage>, String>((ref, attendeeId) {
  final all = ref.watch(chatProvider).valueOrNull ?? const [];
  return all.where((m) => m.attendeeId == attendeeId).toList()
    ..sort((a, b) => a.time.compareTo(b.time));
});

/// Ids de asistentes con los que existe conversación (para la lista de chats).
final conversationPartnersProvider = Provider<List<String>>((ref) {
  final all = ref.watch(chatProvider).valueOrNull ?? const [];
  final seen = <String>[];
  for (final m in all) {
    if (!seen.contains(m.attendeeId)) seen.add(m.attendeeId);
  }
  return seen;
});
