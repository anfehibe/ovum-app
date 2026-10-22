import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/data/models/networking_card.dart';
import 'package:ovum/data/models/networking_meeting.dart';
import 'package:ovum/data/providers/networking_provider.dart';
import 'package:ovum/data/providers/user_provider.dart';
import 'package:ovum/features/networking/new_meeting_screen.dart';

const _luis = NetworkingCard(id: '9', firstName: 'Luis', lastName: 'Paz');

NetworkingMeeting _meeting(MeetingState state) => NetworkingMeeting(
  id: '12',
  state: state,
  stateLabel: '',
  isIncoming: false,
  counterpart: _luis,
  date: DateTime(2026, 11, 12),
  startTime: '10:00',
  endTime: '10:30',
);

/// Rejilla de un backend **sin** `exclude`: la propia reunión sale ocupando
/// las 10:00 en mi agenda y, si estaba confirmada, también en la del otro (para
/// él solo cuentan las confirmadas).
MeetingAvailability _staleGrid(MeetingState state) => MeetingAvailability(
  slots: [
    for (final h in ['09:30', '10:00', '10:30', '11:00'])
      AvailabilitySlot(
        start: h,
        end: '',
        available: h != '10:00',
        selfState: h == '10:00' ? SlotState.taken : SlotState.free,
        busyOther: h == '10:00' && state == MeetingState.confirmed,
      ),
  ],
);

Future<List<AvailabilityKey>> _pump(WidgetTester tester, NetworkingMeeting m) async {
  final keys = <AvailabilityKey>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionUserIdProvider.overrideWithValue('7'),
        networkingMeetingsProvider.overrideWith((ref) async => [m]),
        meetingAvailabilityProvider.overrideWith((ref, key) async {
          keys.add(key);
          return _staleGrid(m.state);
        }),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NewMeetingScreen(attendeeId: m.counterpart.id, editing: m),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return keys;
}

FilledButton _save(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar cambios'));

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('precarga el horario y pide la rejilla excluyendo la reunión', (tester) async {
    final keys = await _pump(tester, _meeting(MeetingState.pending));
    expect(find.text('Editar reunión'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget); // hora de inicio precargada
    expect(keys.last, (date: '2026-11-12', userId: '9', period: 30, exclude: '12'));
    // Su propio hueco no cuenta como ocupado aunque el servidor lo diga.
    expect(find.textContaining('Termina a las 10:30'), findsOneWidget);
    // Sin cambios no hay nada que guardar.
    expect(_save(tester).onPressed, isNull);
  });

  testWidgets('cambiar la duración habilita Guardar y avisa si estaba confirmada', (tester) async {
    await _pump(tester, _meeting(MeetingState.confirmed));
    expect(find.textContaining('tendrá que confirmarla de nuevo'), findsNothing);

    await tester.tap(find.text('60′'));
    await tester.pumpAndSettle();
    expect(_save(tester).onPressed, isNotNull);
    expect(
      find.text('Luis Paz tendrá que confirmarla de nuevo y se liberará la mesa.'),
      findsOneWidget,
    );
  });

  testWidgets('una pendiente movida no lleva el aviso de la mesa', (tester) async {
    await _pump(tester, _meeting(MeetingState.pending));
    await tester.tap(find.text('60′'));
    await tester.pumpAndSettle();
    expect(_save(tester).onPressed, isNotNull);
    expect(find.textContaining('tendrá que confirmarla de nuevo'), findsNothing);
    expect(find.textContaining('le avisaremos del cambio'), findsOneWidget);
  });
}
