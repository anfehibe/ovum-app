import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ovum/core/network/api_client.dart';
import 'package:ovum/core/notifications/notification_routes.dart';
import 'package:ovum/data/models/networking_card.dart';
import 'package:ovum/data/models/networking_meeting.dart';
import 'package:ovum/data/providers/networking_provider.dart';
import 'package:ovum/data/providers/user_provider.dart';
import 'package:ovum/data/services/networking_service.dart';

/// Registra cada llamada y devuelve [reply] en lugar de salir a la red.
class _FakeApi implements ApiClient {
  final calls = <({String verb, String path, Object? body, Map<String, dynamic>? query})>[];
  Object? reply;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add((verb: 'GET', path: path, body: null, query: query));
    return reply;
  }

  @override
  Future<dynamic> post(String path, {Object? body}) async {
    calls.add((verb: 'POST', path: path, body: body, query: null));
    return reply;
  }

  @override
  Future<dynamic> put(String path, {Object? body}) async {
    calls.add((verb: 'PUT', path: path, body: body, query: null));
    return reply;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NetworkingMeeting _meeting({
  String id = '1',
  MeetingState state = MeetingState.pending,
  bool incoming = false,
  DateTime? date,
}) => NetworkingMeeting(
  id: id,
  state: state,
  stateLabel: '',
  isIncoming: incoming,
  counterpart: const NetworkingCard(id: '9'),
  date: date ?? DateTime(2026, 11, 11),
  startTime: '10:00',
  endTime: '10:30',
);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('NetworkingService · editar y cancelar', () {
    late _FakeApi api;
    late NetworkingService service;

    setUp(() {
      api = _FakeApi();
      service = NetworkingService(api, eventId: () async => '94');
    });

    test('updateMeeting hace PUT con el horario y devuelve la reunión', () async {
      api.reply = {
        'data': {
          'id': 12,
          'estatus': 1,
          'estado': 'Pendiente',
          'soy': 'remitente',
          'fecha': '2026-11-12',
          'hora_inicio': '11:00:00',
          'hora_fin': '12:00:00',
        },
        'message': 'Reunión reprogramada: debe confirmarla de nuevo.',
      };
      final res = await service.updateMeeting(
        '12',
        date: '2026-11-12',
        startTime: '11:00',
        endTime: '12:00',
      );
      final call = api.calls.single;
      expect(call.verb, 'PUT');
      expect(call.path, '/events/94/networking/meetings/12');
      // Sin nota no se manda la clave: el backend conserva la que había.
      expect(call.body, {'fecha': '2026-11-12', 'hora_inicio': '11:00', 'hora_fin': '12:00'});
      expect(res.meeting.state, MeetingState.pending);
      expect(res.meeting.startTime, '11:00');
      expect(res.message, 'Reunión reprogramada: debe confirmarla de nuevo.');
    });

    test('updateMeeting manda la nota si viene (aunque sea vacía, para borrarla)', () async {
      api.reply = {'data': {'id': 12}};
      await service.updateMeeting('12', date: 'd', startTime: 's', endTime: 'e', message: '');
      expect((api.calls.single.body as Map)['mensaje'], '');
    });

    test('updateMeeting sin message del servidor usa el texto por defecto', () async {
      api.reply = {'data': {'id': 12}};
      final res = await service.updateMeeting('12', date: 'd', startTime: 's', endTime: 'e');
      expect(res.message, 'Reunión actualizada.');
    });

    test('cancelMeeting hace POST a /cancel y devuelve el estado nuevo', () async {
      api.reply = {
        'data': {'id': 12, 'estatus': 0, 'estado': 'Eliminada'},
        'message': 'Reunión cancelada.',
      };
      final res = await service.cancelMeeting('12');
      final call = api.calls.single;
      expect(call.verb, 'POST');
      expect(call.path, '/events/94/networking/meetings/12/cancel');
      expect(res.outcome.id, '12');
      expect(res.outcome.state, MeetingState.deleted);
      expect(res.message, 'Reunión cancelada.');
    });

    test('availability manda `exclude` solo si hay reunión que excluir', () async {
      api.reply = {'data': {'slots': []}};
      await service.availability('2026-11-11', userId: '9', excludeMeetingId: '12');
      await service.availability('2026-11-11', userId: '9');
      expect(api.calls[0].query?['exclude'], '12');
      expect(api.calls[1].query?.containsKey('exclude'), isFalse);
    });
  });

  group('NetworkingMeeting · qué se puede hacer', () {
    final today = DateTime(2026, 11, 11, 9);

    test('enviada pendiente o confirmada: editar y cancelar', () {
      for (final state in [MeetingState.pending, MeetingState.confirmed]) {
        final m = _meeting(state: state);
        expect(m.canEditOn(today), isTrue, reason: '$state');
        expect(m.canCancelOn(today), isTrue, reason: '$state');
      }
    });

    test('recibida: nunca se edita; se cancela solo si ya la acepté', () {
      final pendiente = _meeting(incoming: true);
      final confirmada = _meeting(incoming: true, state: MeetingState.confirmed);
      expect(pendiente.canEditOn(today), isFalse);
      expect(pendiente.canCancelOn(today), isFalse); // se rechaza, no se cancela
      expect(confirmada.canEditOn(today), isFalse);
      expect(confirmada.canCancelOn(today), isTrue);
    });

    test('rechazada, cancelada, reprogramada, vencida o desconocida: nada', () {
      for (final state in [
        MeetingState.deleted,
        MeetingState.declined,
        MeetingState.rescheduled,
        MeetingState.expired,
        MeetingState.unknown,
      ]) {
        for (final incoming in [false, true]) {
          final m = _meeting(state: state, incoming: incoming);
          expect(m.canEditOn(today), isFalse, reason: '$state');
          expect(m.canCancelOn(today), isFalse, reason: '$state');
        }
      }
    });

    test('pasada (día anterior): nada; el mismo día todavía sí', () {
      final ayer = _meeting(state: MeetingState.confirmed, date: DateTime(2026, 11, 10));
      final hoy = _meeting(state: MeetingState.confirmed, date: DateTime(2026, 11, 11));
      expect(ayer.isPastOn(today), isTrue);
      expect(ayer.canEditOn(today), isFalse);
      expect(ayer.canCancelOn(today), isFalse);
      // La hora exacta la valida el backend.
      expect(hoy.canEditOn(today), isTrue);
    });

    test('sin fecha no cuenta como pasada', () {
      const m = NetworkingMeeting(
        id: '1',
        state: MeetingState.pending,
        stateLabel: '',
        isIncoming: false,
        counterpart: NetworkingCard(id: '9'),
      );
      expect(m.isPastOn(today), isFalse);
      expect(m.canEditOn(today), isTrue);
    });
  });

  group('cancellationLabel', () {
    final now = DateTime(2026, 11, 11, 15);

    test('otro día: nombre, fecha corta y hora', () {
      final c = MeetingCancellation(
        byId: '45',
        byName: 'Andres Higuera',
        at: DateTime(2026, 11, 10, 8),
      );
      expect(cancellationLabel(c, myId: '7', now: now), 'Cancelada por Andres Higuera el 10 nov a las 08:00');
    });

    test('hoy y por mí', () {
      final c = MeetingCancellation(byId: '7', byName: 'Carla Demo', at: DateTime(2026, 11, 11, 9, 30));
      expect(cancellationLabel(c, myId: '7', now: now), 'Cancelada por ti hoy a las 09:30');
    });

    test('sin nombre ni fecha no deja huecos', () {
      const c = MeetingCancellation(byId: '45');
      expect(cancellationLabel(c, now: now), 'Cancelada por la otra persona');
    });
  });

  group('overlay de respuestas', () {
    test('se vacía cuando llega la lista nueva del servidor', () async {
      var server = [_meeting(id: '5', incoming: true)];
      final container = ProviderContainer(overrides: [
        sessionUserIdProvider.overrideWithValue('1'),
        networkingMeetingsProvider.overrideWith((ref) async => server),
      ]);
      addTearDown(container.dispose);
      container.listen(overlaidMeetingsProvider, (_, _) {});
      await container.read(networkingMeetingsProvider.future);

      // Acepto: el overlay pinta "Confirmada" mientras llega el refetch.
      container.read(meetingResponsesProvider.notifier).record((
        id: '5',
        state: MeetingState.confirmed,
        stateLabel: 'Confirmada',
        place: 'Salón A',
        table: 3,
      ));
      container.invalidate(networkingMeetingsProvider);
      expect(container.read(overlaidMeetingsProvider).single.state, MeetingState.confirmed);

      // Después el remitente cambia la hora y el servidor la devuelve a
      // pendiente: eso es lo que hay que ver, no la respuesta vieja.
      server = [_meeting(id: '5', incoming: true)];
      await container.read(networkingMeetingsProvider.future);
      expect(container.read(meetingResponsesProvider), isEmpty);
      expect(container.read(overlaidMeetingsProvider).single.state, MeetingState.pending);
    });

    test('las canceladas no cuentan como enviadas ni recibidas', () async {
      final container = ProviderContainer(overrides: [
        sessionUserIdProvider.overrideWithValue('1'),
        networkingMeetingsProvider.overrideWith(
          (ref) async => [
            _meeting(id: '1'),
            _meeting(id: '2', state: MeetingState.deleted),
            _meeting(id: '3', incoming: true, state: MeetingState.deleted),
          ],
        ),
      ]);
      addTearDown(container.dispose);
      container.listen(meetingCountsProvider, (_, _) {});
      await container.read(networkingMeetingsProvider.future);
      final counts = container.read(meetingCountsProvider);
      expect(counts.sent, 1);
      expect(counts.received, 0);
    });
  });

  test('isMeetingNotification reconoce los alias de reunión', () {
    expect(isMeetingNotification({'tipo': 'reunion', 'id': '5'}), isTrue);
    expect(isMeetingNotification({'type': 'Meeting'}), isTrue);
    expect(isMeetingNotification({'tipo': 'chat', 'id': '5'}), isFalse);
    expect(isMeetingNotification({'origen': 'panel'}), isFalse);
  });
}
