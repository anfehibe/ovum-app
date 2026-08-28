import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/iterable_ext.dart';
import '../models/models.dart';
import '../repositories/ovum_repository.dart';

/// Repositorio de datos (mock por ahora). Punto único para cambiar a API.
final ovumRepositoryProvider = Provider<OvumRepository>(
  (ref) => const MockOvumRepository(),
);

// ── Listados de contenido (cargados una vez y cacheados por Riverpod) ──────

final sessionsProvider = FutureProvider<List<Session>>(
  (ref) => ref.watch(ovumRepositoryProvider).getSessions(),
);

final speakersProvider = FutureProvider<List<Speaker>>(
  (ref) => ref.watch(ovumRepositoryProvider).getSpeakers(),
);

final sponsorsProvider = FutureProvider<List<Sponsor>>(
  (ref) => ref.watch(ovumRepositoryProvider).getSponsors(),
);

final exhibitorsProvider = FutureProvider<List<Exhibitor>>(
  (ref) => ref.watch(ovumRepositoryProvider).getExhibitors(),
);

final attendeesProvider = FutureProvider<List<Attendee>>(
  (ref) => ref.watch(ovumRepositoryProvider).getAttendees(),
);

final venuesProvider = FutureProvider<List<Venue>>(
  (ref) => ref.watch(ovumRepositoryProvider).getVenues(),
);

final hotelsProvider = FutureProvider<List<Hotel>>(
  (ref) => ref.watch(ovumRepositoryProvider).getHotels(),
);

final organizersProvider = FutureProvider<List<Organizer>>(
  (ref) => ref.watch(ovumRepositoryProvider).getOrganizers(),
);

final infoItemsProvider = FutureProvider<List<InfoItem>>(
  (ref) => ref.watch(ovumRepositoryProvider).getInfoItems(),
);

final pollsProvider = FutureProvider<List<Poll>>(
  (ref) => ref.watch(ovumRepositoryProvider).getPolls(),
);

// ── Sesiones derivadas ─────────────────────────────────────────────────────

/// Sesiones "de agenda" (excluye otras actividades), ordenadas por hora.
final agendaSessionsProvider = Provider<List<Session>>((ref) {
  final all = ref.watch(sessionsProvider).valueOrNull ?? const [];
  final list = all.where((s) => !s.isOtherActivity).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  return list;
});

/// Otras actividades, ordenadas por hora.
final otherActivitiesProvider = Provider<List<Session>>((ref) {
  final all = ref.watch(sessionsProvider).valueOrNull ?? const [];
  final list = all.where((s) => s.isOtherActivity).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  return list;
});

// ── Búsquedas por id ───────────────────────────────────────────────────────

final speakerByIdProvider = Provider.family<Speaker?, String>((ref, id) {
  final list = ref.watch(speakersProvider).valueOrNull ?? const [];
  return list.firstWhereOrNull((s) => s.id == id);
});

final sessionByIdProvider = Provider.family<Session?, String>((ref, id) {
  final list = ref.watch(sessionsProvider).valueOrNull ?? const [];
  return list.firstWhereOrNull((s) => s.id == id);
});

final attendeeByIdProvider = Provider.family<Attendee?, String>((ref, id) {
  final list = ref.watch(attendeesProvider).valueOrNull ?? const [];
  return list.firstWhereOrNull((a) => a.id == id);
});

/// Sesiones en las que participa un speaker.
final sessionsForSpeakerProvider = Provider.family<List<Session>, String>((ref, speakerId) {
  final list = ref.watch(sessionsProvider).valueOrNull ?? const [];
  return list.where((s) => s.speakerIds.contains(speakerId)).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
});

/// Speakers que participan en una sesión.
final speakersForSessionProvider = Provider.family<List<Speaker>, String>((ref, sessionId) {
  final session = ref.watch(sessionByIdProvider(sessionId));
  final speakers = ref.watch(speakersProvider).valueOrNull ?? const [];
  if (session == null) return const [];
  return session.speakerIds
      .map((id) => speakers.firstWhereOrNull((s) => s.id == id))
      .whereType<Speaker>()
      .toList();
});

/// Encuestas asociadas a una sesión.
final pollsForSessionProvider = Provider.family<List<Poll>, String>((ref, sessionId) {
  final polls = ref.watch(pollsProvider).valueOrNull ?? const [];
  return polls.where((p) => p.sessionId == sessionId).toList();
});
