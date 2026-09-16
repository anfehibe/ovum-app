import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../models/networking_card.dart';
import '../models/networking_catalog.dart';
import '../models/networking_meeting.dart';
import '../models/networking_profile.dart';
import 'content_providers.dart';
import 'favorites_provider.dart';
import 'preferences.dart';
import 'user_provider.dart';

// ── Compuerta de disponibilidad ─────────────────────────────────────────────

/// Motivo por el que el networking no está disponible.
enum NetworkingBlock {
  /// Invitado o sesión vencida: hace falta iniciar sesión.
  signInRequired,

  /// Apagado desde [AppConfig.useApiNetworking].
  disabled,

  /// 403 del backend: el organizador no abrió el networking, o el usuario no es
  /// asistente confirmado con networking activo.
  closed,

  /// Falló la petición (red, 500…).
  failed,
}

/// Resultado de la sonda de disponibilidad.
///
/// No existe endpoint que informe si el networking está abierto, así que se usa
/// `GET /networking/me` como sonda: es el endpoint guardado más barato y de paso
/// trae el perfil propio, que hace falta igual.
class NetworkingAccess {
  const NetworkingAccess._(this.profile, this.block, this.message);

  /// Perfil propio; solo viene cuando el acceso está abierto.
  final NetworkingProfile? profile;
  final NetworkingBlock? block;

  /// Mensaje del backend (se muestra tal cual: distingue las dos causas del 403).
  final String message;

  NetworkingAccess.open(NetworkingProfile profile) : this._(profile, null, '');
  const NetworkingAccess.signInRequired()
    : this._(null, NetworkingBlock.signInRequired, '');
  const NetworkingAccess.disabled() : this._(null, NetworkingBlock.disabled, '');
  const NetworkingAccess.closed(String message)
    : this._(null, NetworkingBlock.closed, message);
  const NetworkingAccess.failed(String message)
    : this._(null, NetworkingBlock.failed, message);

  bool get isOpen => block == null;
}

/// Sonda única por sesión. El flag apagado cae al mismo camino degradado que un
/// 403, para tener un solo estado que mantener.
final networkingAccessProvider = FutureProvider<NetworkingAccess>((ref) async {
  if (!AppConfig.useApiNetworking) return const NetworkingAccess.disabled();
  if (ref.watch(isGuestProvider)) return const NetworkingAccess.signInRequired();
  try {
    return NetworkingAccess.open(await ref.watch(networkingServiceProvider).me());
  } on ApiException catch (e) {
    if (e.isUnauthorized) return const NetworkingAccess.signInRequired();
    if (e.isForbidden) return NetworkingAccess.closed(e.message);
    return NetworkingAccess.failed(e.message);
  } catch (_) {
    return const NetworkingAccess.failed('No se pudo cargar el networking.');
  }
});

// ── Catálogo ────────────────────────────────────────────────────────────────

/// Vocabulario del evento. Se cachea toda la vida de la app (como los ponentes).
final networkingCatalogProvider = FutureProvider<NetworkingCatalog>(
  (ref) => ref.watch(networkingServiceProvider).catalog(),
);

// ── Perfil propio ───────────────────────────────────────────────────────────

class MyNetworkingProfileNotifier extends AsyncNotifier<NetworkingProfile?> {
  @override
  Future<NetworkingProfile?> build() async {
    // Reusa el perfil que ya trajo la sonda; no repite el GET.
    return (await ref.watch(networkingAccessProvider.future)).profile;
  }

  /// Guarda y **relee** el perfil: el `PUT` no devuelve datos, recorta en silencio
  /// a los topes y no escribe nada si el usuario no tiene ficha base. Adoptar la
  /// respuesta del servidor es la única forma de mostrar lo que quedó de verdad.
  ///
  /// Devuelve el `message` del backend. Ante un fallo revierte y relanza.
  Future<String> save({
    required List<String> sectors,
    required List<String> interests,
    required List<String> seeking,
    required List<String> solutions,
    required List<String> regions,
  }) async {
    final previous = state.valueOrNull;
    final catalog = ref.read(networkingCatalogProvider).valueOrNull;
    state = AsyncData(
      previous?.copyWith(
        sectors: sectors,
        interests: interests,
        seeking: seeking,
        solutions: solutions,
        regions: regions,
      ),
    );
    try {
      final service = ref.read(networkingServiceProvider);
      final message = await service.saveMe(
        sectors: sectors,
        interests: interests,
        seeking: seeking,
        solutions: solutions,
        regions: regions,
        catalog: catalog,
      );
      state = AsyncData(await service.me());
      return message;
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final myNetworkingProfileProvider =
    AsyncNotifierProvider<MyNetworkingProfileNotifier, NetworkingProfile?>(
      MyNetworkingProfileNotifier.new,
    );

// ── Directorio: búsqueda con debounce + paginación ──────────────────────────

typedef DirectoryQuery = ({String search, String? sector});

class DirectoryQueryNotifier extends Notifier<DirectoryQuery> {
  Timer? _debounce;

  @override
  DirectoryQuery build() {
    ref.onDispose(() => _debounce?.cancel());
    return (search: '', sector: null);
  }

  /// Teclear dispara una sola petición 350 ms después de la última tecla.
  void setSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      state = (search: value.trim(), sector: state.sector);
    });
  }

  /// Tocar un chip es intencional: se aplica de inmediato.
  void setSector(String? sector) {
    _debounce?.cancel();
    state = (search: state.search, sector: sector);
  }
}

final directoryQueryProvider =
    NotifierProvider<DirectoryQueryNotifier, DirectoryQuery>(
      DirectoryQueryNotifier.new,
    );

typedef DirectoryState = ({
  List<NetworkingCard> items,
  int page,
  int lastPage,
  int total,
  bool loadingMore,
});

class DirectoryNotifier extends AsyncNotifier<DirectoryState> {
  @override
  Future<DirectoryState> build() async {
    // Al cambiar la query, Riverpod re-ejecuta build → vuelve a página 1 solo.
    final query = ref.watch(directoryQueryProvider);
    final page = await ref
        .watch(networkingServiceProvider)
        .directory(search: query.search, sector: query.sector);
    return (
      items: page.items,
      page: page.page,
      lastPage: page.lastPage,
      total: page.total,
      loadingMore: false,
    );
  }

  /// Carga la siguiente página y la anexa. Nunca pasa a `AsyncLoading`: eso
  /// vaciaría la lista que el usuario está mirando.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || current.page >= current.lastPage) {
      return;
    }
    final query = ref.read(directoryQueryProvider);
    state = AsyncData((
      items: current.items,
      page: current.page,
      lastPage: current.lastPage,
      total: current.total,
      loadingMore: true,
    ));
    try {
      final next = await ref
          .read(networkingServiceProvider)
          .directory(
            search: query.search,
            sector: query.sector,
            page: current.page + 1,
          );
      // Guardia de carrera: si la búsqueda cambió mientras se pedía la página,
      // `build()` ya reinició la lista y anexar aquí mezclaría resultados viejos.
      if (ref.read(directoryQueryProvider) != query) return;
      final base = state.valueOrNull ?? current;
      state = AsyncData((
        items: [...base.items, ...next.items],
        page: next.page,
        lastPage: next.lastPage,
        total: next.total,
        loadingMore: false,
      ));
    } catch (_) {
      final base = state.valueOrNull ?? current;
      state = AsyncData((
        items: base.items,
        page: base.page,
        lastPage: base.lastPage,
        total: base.total,
        loadingMore: false,
      ));
      rethrow;
    }
  }
}

final directoryProvider =
    AsyncNotifierProvider<DirectoryNotifier, DirectoryState>(
      DirectoryNotifier.new,
    );

/// Ficha individual (`GET /networking/attendees/{id}`). 404 si esa persona ya no
/// participa del networking.
final networkingAttendeeProvider = FutureProvider.family<NetworkingCard, String>(
  (ref, userId) => ref.watch(networkingServiceProvider).attendee(userId),
);

// ── Favoritos (servidor, con toggle optimista) ──────────────────────────────

final serverFavoritesProvider = FutureProvider<List<NetworkingCard>>(
  (ref) => ref.watch(networkingServiceProvider).favorites(),
);

/// Overrides locales `userId → valor` superpuestos a la verdad del servidor.
///
/// Es un mapa aparte y **no** un notifier que observe la lista de favoritos: si
/// `build()` dependiera de ese future, invalidarlo tras un toggle exitoso
/// reiniciaría el estado y borraría el optimismo en vuelo. Mismo patrón que
/// `PollAnswersNotifier`.
class NetworkingFavoritesNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => const {};

  Future<void> toggle(String userId, bool current) async {
    state = {...state, userId: !current};
    try {
      final server = await ref
          .read(networkingServiceProvider)
          .toggleFavorite(userId);
      state = {...state, userId: server}; // manda lo que diga el servidor
      ref.invalidate(serverFavoritesProvider);
    } catch (_) {
      state = {...state}..remove(userId); // revertir = volver a la verdad previa
      rethrow;
    }
  }
}

final networkingFavoritesProvider =
    NotifierProvider<NetworkingFavoritesNotifier, Map<String, bool>>(
      NetworkingFavoritesNotifier.new,
    );

/// Precedencia: mi override optimista → la lista del servidor → el flag que trajo
/// la ficha. Nunca el `favorito` de las reuniones, que el backend manda siempre
/// en `false`.
final isNetworkingFavoriteProvider = Provider.family<bool, NetworkingCard>((
  ref,
  card,
) {
  final override = ref.watch(networkingFavoritesProvider)[card.id];
  if (override != null) return override;
  final server = ref.watch(serverFavoritesProvider).valueOrNull;
  if (server != null) return server.any((c) => c.id == card.id);
  return card.isFavorite;
});

/// Migración, una sola vez, de los favoritos **locales** de asistentes al
/// servidor.
///
/// Los ids coinciden (ambos endpoints emiten el id del usuario), así que las
/// claves `attendee:<id>` de SharedPreferences se pueden subir tal cual. Es
/// best-effort y silenciosa: que falle un POST no puede romper el resto de los
/// favoritos del usuario. Se marca una bandera para no repetirla nunca.
final networkingFavoritesMigrationProvider = FutureProvider<void>((ref) async {
  const flag = 'favorites_attendees_migrated';
  final prefs = ref.read(sharedPreferencesProvider);
  if (prefs.getBool(flag) == true) return;

  try {
    final access = await ref.watch(networkingAccessProvider.future);
    if (!access.isOpen) return; // sin networking todavía no hay dónde migrar

    final prefix = '${FavKind.attendee.name}:';
    final locales = ref
        .read(favoritesProvider)
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toList();

    if (locales.isNotEmpty) {
      final enServidor = (await ref.read(serverFavoritesProvider.future))
          .map((c) => c.id)
          .toSet();
      final service = ref.read(networkingServiceProvider);
      for (final id in locales.take(25)) {
        if (enServidor.contains(id)) continue;
        try {
          await service.toggleFavorite(id);
        } catch (_) {
          // best-effort: si uno falla, seguimos con el resto
        }
      }
      ref.invalidate(serverFavoritesProvider);
    }

    ref.read(favoritesProvider.notifier).removeKind(FavKind.attendee);
    await prefs.setBool(flag, true);
  } catch (_) {
    // Se reintentará en la próxima apertura; nunca propaga a la UI.
  }
});

// ── Reuniones ───────────────────────────────────────────────────────────────

final networkingMeetingsProvider = FutureProvider<List<NetworkingMeeting>>(
  (ref) => ref.watch(networkingServiceProvider).meetings(),
);

/// Respuestas que el usuario acaba de dar, superpuestas al listado.
///
/// Va en un mapa aparte y **no** derivado del future de reuniones: si `build()`
/// dependiera de él, invalidar la lista tras responder borraría el overlay justo
/// cuando llega la mesa asignada — que el listado del backend todavía **no**
/// devuelve (`GET /meetings` no trae `lugar`/`mesa`), así que se perdería el dato.
class MeetingResponsesNotifier extends Notifier<Map<String, MeetingOutcome>> {
  @override
  Map<String, MeetingOutcome> build() => const {};

  void record(MeetingOutcome outcome) =>
      state = {...state, outcome.id: outcome};
}

final meetingResponsesProvider =
    NotifierProvider<MeetingResponsesNotifier, Map<String, MeetingOutcome>>(
      MeetingResponsesNotifier.new,
    );

/// Reuniones del servidor con las respuestas locales ya aplicadas, para que las
/// tarjetas y los contadores no se contradigan mientras llega el refetch.
final overlaidMeetingsProvider = Provider<List<NetworkingMeeting>>((ref) {
  final list = ref.watch(networkingMeetingsProvider).valueOrNull ?? const [];
  final overrides = ref.watch(meetingResponsesProvider);
  if (overrides.isEmpty) return list;
  return [
    for (final m in list)
      if (overrides[m.id] case final o?) m.applyOutcome(o) else m,
  ];
});

/// Contadores para el tablero. Conserva el shape del record anterior.
typedef MeetingCounts = ({
  int received,
  int sent,
  int confirmed,
  int pending,
  int declined,
});

final meetingCountsProvider = Provider<MeetingCounts>((ref) {
  final list = ref.watch(overlaidMeetingsProvider);
  return (
    received: list.where((m) => m.isIncoming).length,
    sent: list.where((m) => !m.isIncoming).length,
    confirmed: list.where((m) => m.state == MeetingState.confirmed).length,
    pending: list.where((m) => m.state == MeetingState.pending).length,
    declined: list.where((m) => m.state == MeetingState.declined).length,
  );
});
