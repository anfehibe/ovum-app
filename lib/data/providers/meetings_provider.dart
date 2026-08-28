import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'content_providers.dart';

/// Solicitudes de reunión de networking (mock, en memoria; sembradas del repo).
class MeetingsNotifier extends AsyncNotifier<List<Meeting>> {
  @override
  Future<List<Meeting>> build() async {
    return ref.watch(ovumRepositoryProvider).getSeedMeetings();
  }

  void add(Meeting meeting) {
    final current = state.valueOrNull ?? const [];
    state = AsyncData([meeting, ...current]);
  }

  void setStatus(String id, MeetingStatus status) {
    final current = state.valueOrNull ?? const [];
    state = AsyncData([
      for (final m in current) if (m.id == id) m.copyWith(status: status) else m,
    ]);
  }
}

final meetingsProvider =
    AsyncNotifierProvider<MeetingsNotifier, List<Meeting>>(MeetingsNotifier.new);

/// Contadores por estado y dirección, para el dashboard de networking.
typedef MeetingCounts = ({int received, int sent, int confirmed, int pending, int declined});

final meetingCountsProvider = Provider<MeetingCounts>((ref) {
  final list = ref.watch(meetingsProvider).valueOrNull ?? const [];
  return (
    received: list.where((m) => m.incoming).length,
    sent: list.where((m) => !m.incoming).length,
    confirmed: list.where((m) => m.status == MeetingStatus.confirmed).length,
    pending: list.where((m) => m.status == MeetingStatus.pending).length,
    declined: list.where((m) => m.status == MeetingStatus.declined).length,
  );
});
