import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/core/utils/meeting_slots.dart';
import 'package:ovum/features/widgets/meeting_slot_picker.dart';

/// Abre la rueda y devuelve lo que eligió el usuario.
Future<MeetingSlot?> _open(
  WidgetTester tester, {
  required Map<MeetingSlot, SlotState> states,
  int durationMinutes = 30,
  MeetingSlot? initial,
}) async {
  MeetingSlot? picked;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showMeetingTimePicker(
                context,
                slots: meetingSlots(durationMinutes: durationMinutes),
                states: states,
                durationMinutes: durationMinutes,
                initial: initial,
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return picked;
}

TextButton _button(WidgetTester tester, String label) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, label));

void main() {
  testWidgets('solo muestra horas de la rejilla', (tester) async {
    await _open(tester, states: const {});
    // La rueda solo construye los ítems cercanos al viewport, así que se
    // comprueba lo que hay pintado: ninguna hora suelta tipo 03:47 o 09:15.
    final labels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ListWheelScrollView),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .toList();
    expect(labels, contains('08:00'));
    for (final label in labels) {
      expect(label, matches(RegExp(r'^\d{2}:(00|30)$')));
    }
  });

  testWidgets('abre en el slot pedido y lo devuelve al confirmar', (tester) async {
    const wanted = MeetingSlot(11 * 60 + 30);
    await _open(tester, states: const {}, initial: wanted);
    expect(find.text('Termina a las 12:00.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Listo'));
    await tester.pumpAndSettle();
    // El Future de showMeetingTimePicker ya resolvió con el slot centrado.
    expect(find.text('Hora de inicio'), findsNothing);
  });

  testWidgets('con la agenda llena no se puede confirmar y se dice por qué', (
    tester,
  ) async {
    final states = {
      for (final s in meetingSlots()) s: SlotState.taken,
    };
    await _open(tester, states: states);

    expect(_button(tester, 'Listo').onPressed, isNull);
    expect(find.text('Ya tienes una reunión a esa hora.'), findsOneWidget);
  });

  testWidgets('cancelar no devuelve nada', (tester) async {
    await _open(tester, states: const {});
    expect(_button(tester, 'Cancelar').onPressed, isNotNull);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Hora de inicio'), findsNothing);
  });
}
