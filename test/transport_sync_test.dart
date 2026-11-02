import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/core/notifications/notification_service.dart';
import 'package:ovum/core/utils/event_clock.dart';
import 'package:ovum/data/models/bus_route.dart';
import 'package:ovum/data/providers/content_providers.dart';
import 'package:ovum/data/providers/notifications_provider.dart';
import 'package:ovum/data/providers/preferences.dart';
import 'package:ovum/data/providers/transport_follow_provider.dart';
import 'package:ovum/data/providers/transport_providers.dart';
import 'package:ovum/data/repositories/ovum_repository.dart';
import 'package:ovum/data/repositories/transport_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ruta = BusRoute(
  id: '1',
  name: 'Ruta A',
  stops: [
    RouteStop(id: '1', order: 1, kind: StopKind.hotel, name: 'Hotel'),
    RouteStop(id: '2', order: 2, kind: StopKind.venue, name: 'Sede'),
  ],
  departures: [RouteDeparture(id: '1', departTime: '07:00')],
);

/// Repositorio que responde con [_ruta] mientras [online] sea `true`.
class _FakeRepo implements OvumRepository {
  bool online = true;

  @override
  Future<List<BusRoute>> getBusRoutes() async {
    if (!online) throw Exception('sin red');
    return const [_ruta];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Servicio de notificaciones sin Firebase: anota cada operación de topic.
class _FakeNotifications extends NotificationService {
  final subscribed = <String>[];
  final unsubscribed = <String>[];

  /// Simula iOS antes de que llegue el token de APNs.
  bool apnsReady = true;

  @override
  Future<bool> subscribeTopic(String topic) async {
    if (!apnsReady) return false;
    subscribed.add(topic);
    return true;
  }

  @override
  Future<bool> unsubscribeTopic(String topic) async {
    if (!apnsReady) return false;
    unsubscribed.add(topic);
    return true;
  }

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

void main() {
  group('hora del evento', () {
    tearDown(() => eventClockSource = DateTime.now);

    test('eventNow da la hora de Guatemala sea cual sea la del teléfono', () {
      // 13:00 UTC = 07:00 en Guatemala (UTC-6, sin horario de verano). Se
      // fija como instante UTC, así que no depende de la zona de la máquina.
      eventClockSource = () => DateTime.utc(2026, 11, 11, 13, 0);
      expect(eventNow(), DateTime(2026, 11, 11, 7, 0));
    });

    test('cruza el día igual que el reloj de Guatemala', () {
      eventClockSource = () => DateTime.utc(2026, 11, 12, 3, 30);
      expect(eventNow(), DateTime(2026, 11, 11, 21, 30));
    });

    test('eventInstant convierte la hora de pared en el instante real', () {
      final instant = eventInstant(DateTime(2026, 11, 11, 7, 0));
      expect(instant.toUtc(), DateTime.utc(2026, 11, 11, 13, 0));
    });

    test('ida y vuelta entre pared e instante', () {
      final wall = DateTime(2026, 11, 12, 22, 30);
      expect(toEventWallClock(eventInstant(wall)), wall);
    });
  });

  group('caché de transporte', () {
    test('guarda y recupera las rutas con su hora', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = TransportCache(await SharedPreferences.getInstance());
      final savedAt = DateTime.utc(2026, 11, 11, 12, 45);
      await cache.save(const [_ruta], savedAt);

      final loaded = cache.load()!;
      expect(loaded.savedAt.isAtSameMomentAs(savedAt), isTrue);
      expect(loaded.routes.single.id, '1');
      expect(loaded.routes.single.stops.map((s) => s.name), ['Hotel', 'Sede']);
      expect(loaded.routes.single.departures.single.departTime, '07:00');
    });

    test('una caché corrupta se ignora en vez de romper', () async {
      SharedPreferences.setMockInitialValues({
        'transport_routes_cache_v1': '{no es json',
      });
      final cache = TransportCache(await SharedPreferences.getInstance());
      expect(cache.load(), isNull);
    });
  });

  group('busRoutesProvider', () {
    late _FakeRepo repo;
    late ProviderContainer container;

    Future<void> setUpContainer() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = _FakeRepo();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ovumRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
    }

    test('un refresco fallido conserva los horarios, marcados sin conexión',
        () async {
      await setUpContainer();
      final first = await container.read(busRoutesProvider.future);
      expect(first.offline, isFalse);

      repo.online = false;
      container.invalidate(busRoutesProvider);
      final second = await container.read(busRoutesProvider.future);
      expect(second.offline, isTrue);
      expect(second.routes.single.id, '1');
      // La hora es la de la copia, no la del intento fallido (la copia se
      // guarda con resolución de milisegundos).
      expect(
        second.savedAt.millisecondsSinceEpoch,
        first.savedAt.millisecondsSinceEpoch,
      );
    });

    test('sin copia guardada, el error llega a la pantalla', () async {
      await setUpContainer();
      repo.online = false;
      await expectLater(
        container.read(busRoutesProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('TransportTopicsController', () {
    late _FakeNotifications service;
    late ProviderContainer container;
    late SharedPreferences prefs;

    Future<void> setUpContainer({
      Map<String, Object> initial = const {},
    }) async {
      SharedPreferences.setMockInitialValues(initial);
      prefs = await SharedPreferences.getInstance();
      service = _FakeNotifications();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationServiceProvider.overrideWithValue(service),
          notificationsInitProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);
      await container.read(notificationsInitProvider.future);
    }

    Future<void> sync({bool force = false}) =>
        container.read(transportTopicsProvider.notifier).sync(force: force);

    List<String> synced() =>
        prefs.getStringList('push_transport_topics') ?? const [];

    test('seguir una ruta suscribe su topic', () async {
      await setUpContainer();
      container.read(followedRoutesProvider.notifier).toggle('1');
      await sync();

      expect(service.subscribed, ['transporte_ruta_1']);
      expect(synced(), ['transporte_ruta_1']);
      // Espejo del backend: AvisosTransporte.php publica en este topic.
      expect(transportTopic('1'), 'transporte_ruta_1');
    });

    test('dejar de seguirla da de baja el topic', () async {
      await setUpContainer();
      final followed = container.read(followedRoutesProvider.notifier);
      followed.toggle('1');
      await sync();
      followed.toggle('1');
      await sync();

      expect(service.unsubscribed, ['transporte_ruta_1']);
      expect(synced(), isEmpty);
    });

    test('con los avisos apagados en Perfil no se suscribe nada', () async {
      await setUpContainer(
        initial: {
          'notif_push_enabled': false,
          'notif_transport_routes': ['1'],
          'push_transport_topics': ['transporte_ruta_1'],
        },
      );
      await sync();

      expect(service.subscribed, isEmpty);
      expect(service.unsubscribed, ['transporte_ruta_1']);
      expect(synced(), isEmpty);
      // La intención del usuario se conserva para cuando los vuelva a encender.
      expect(container.read(followedRoutesProvider), {'1'});
    });

    test('sin APNs no da por suscrito el topic y lo reintenta después',
        () async {
      await setUpContainer();
      service.apnsReady = false;
      container.read(followedRoutesProvider.notifier).toggle('1');
      await sync();
      expect(synced(), isEmpty);

      service.apnsReady = true;
      await sync();
      expect(service.subscribed, ['transporte_ruta_1']);
      expect(synced(), ['transporte_ruta_1']);
    });

    test('forzado vuelve a suscribir lo que ya figuraba (reinstalación)',
        () async {
      await setUpContainer(
        initial: {
          'notif_transport_routes': ['1'],
          'push_transport_topics': ['transporte_ruta_1'],
        },
      );
      await sync();
      expect(service.subscribed, isEmpty);

      await sync(force: true);
      expect(service.subscribed, ['transporte_ruta_1']);
    });

    test('antes de inicializar las notificaciones no hace nada', () async {
      SharedPreferences.setMockInitialValues({
        'notif_transport_routes': ['1'],
      });
      prefs = await SharedPreferences.getInstance();
      service = _FakeNotifications();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationServiceProvider.overrideWithValue(service),
          notificationsInitProvider.overrideWith(
            (ref) => Completer<void>().future,
          ),
        ],
      );
      addTearDown(container.dispose);

      await sync();
      expect(service.subscribed, isEmpty);
    });
  });
}
