import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ovum/core/network/api_client.dart';
import 'package:ovum/core/network/api_exception.dart';
import 'package:ovum/data/models/networking_card.dart';
import 'package:ovum/data/models/networking_meeting.dart';
import 'package:ovum/data/providers/content_providers.dart';
import 'package:ovum/data/providers/networking_provider.dart';
import 'package:ovum/data/providers/user_provider.dart';
import 'package:ovum/data/services/networking_service.dart';
import 'package:ovum/features/widgets/meeting_card.dart';

/// Responde a `/cancel` con [reply], o lanza [error] si lo hay.
class _FakeApi implements ApiClient {
  final posts = <String>[];
  Object? reply;
  ApiException? error;

  @override
  Future<dynamic> post(String path, {Object? body}) async {
    posts.add(path);
    if (error case final e?) throw e;
    return reply;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _tomorrow = DateTime.now().add(const Duration(days: 1));

NetworkingMeeting _meeting({
  MeetingState state = MeetingState.pending,
  bool incoming = false,
  MeetingCancellation? cancellation,
}) => NetworkingMeeting(
  id: '12',
  state: state,
  stateLabel: switch (state) {
    MeetingState.pending => 'Pendiente',
    MeetingState.confirmed => 'Confirmada',
    MeetingState.deleted => 'Eliminada',
    _ => '',
  },
  isIncoming: incoming,
  counterpart: const NetworkingCard(id: '9', firstName: 'Luis', lastName: 'Paz'),
  date: _tomorrow,
  startTime: '10:00',
  endTime: '10:30',
  cancellation: cancellation,
);

Future<_FakeApi> _pump(WidgetTester tester, NetworkingMeeting m) async {
  final api = _FakeApi();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('7'),
        networkingServiceProvider.overrideWithValue(
          NetworkingService(api, eventId: () async => '94'),
        ),
        networkingMeetingsProvider.overrideWith((ref) async => [m]),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: MeetingCard(meeting: m))),
      ),
    ),
  );
  return api;
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('enviada pendiente: Editar y Cancelar, sin Aceptar', (tester) async {
    await _pump(tester, _meeting());
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Cancelar reunión'), findsOneWidget);
    expect(find.text('Aceptar'), findsNothing);
  });

  testWidgets('recibida pendiente: Aceptar/Rechazar, sin Editar ni Cancelar', (tester) async {
    await _pump(tester, _meeting(incoming: true));
    expect(find.text('Aceptar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Cancelar reunión'), findsNothing);
  });

  testWidgets('recibida confirmada: solo Cancelar', (tester) async {
    await _pump(tester, _meeting(incoming: true, state: MeetingState.confirmed));
    expect(find.text('Cancelar reunión'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Aceptar'), findsNothing);
  });

  testWidgets('cancelada: etiqueta "Cancelada", quién y cuándo, y sin acciones', (tester) async {
    await _pump(
      tester,
      _meeting(
        state: MeetingState.deleted,
        cancellation: MeetingCancellation(
          byId: '9',
          byName: 'Luis Paz',
          at: DateTime(2020, 3, 5, 8),
        ),
      ),
    );
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('Eliminada'), findsNothing);
    expect(find.text('Cancelada por Luis Paz el 5 mar a las 08:00'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Cancelar reunión'), findsNothing);
  });

  testWidgets('cancelada estando pendiente: sin línea de atribución', (tester) async {
    await _pump(tester, _meeting(state: MeetingState.deleted));
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.textContaining('Cancelada por'), findsNothing);
  });

  testWidgets('cancelar pide confirmación y llama a /cancel', (tester) async {
    final api = await _pump(tester, _meeting(state: MeetingState.confirmed));
    api.reply = {
      'data': {'id': 12, 'estatus': 0, 'estado': 'Eliminada'},
      'message': 'Reunión cancelada.',
    };

    await tester.tap(find.text('Cancelar reunión'));
    await tester.pumpAndSettle();
    // La confirmada avisa a la otra persona; el diálogo lo dice.
    expect(find.textContaining('Le avisaremos a Luis Paz'), findsOneWidget);

    // "Volver" no hace nada.
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(api.posts, isEmpty);

    await tester.tap(find.text('Cancelar reunión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar reunión'));
    await tester.pumpAndSettle();
    expect(api.posts, ['/events/94/networking/meetings/12/cancel']);
    expect(find.text('Reunión cancelada.'), findsOneWidget);
  });

  testWidgets('una reunión que ya no existe (404) lo dice sin romperse', (tester) async {
    final api = await _pump(tester, _meeting());
    api.error = const ApiException('', statusCode: 404);

    await tester.tap(find.text('Cancelar reunión'));
    await tester.pumpAndSettle();
    expect(find.text('Luis Paz ya no podrá aceptarla.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar reunión'));
    await tester.pumpAndSettle();
    expect(find.text('Esa reunión ya no existe.'), findsOneWidget);
  });

  test('meetingChangeErrorText: 404, mensaje del backend o genérico', () {
    expect(
      meetingChangeErrorText(const ApiException('', statusCode: 404)),
      'Esa reunión ya no existe.',
    );
    expect(
      meetingChangeErrorText(const ApiException('Esta reunión ya pasó.', statusCode: 422)),
      'Esta reunión ya pasó.',
    );
    expect(
      meetingChangeErrorText(const ApiException('', statusCode: 500)),
      'No se pudo completar la acción.',
    );
  });
}
