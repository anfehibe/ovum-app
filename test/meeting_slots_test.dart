import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/core/constants/ovum_event.dart';
import 'package:ovum/core/utils/meeting_slots.dart';
import 'package:ovum/data/models/networking_card.dart';
import 'package:ovum/data/models/networking_meeting.dart';

final _day = DateTime(2026, 11, 11);
final _otherDay = DateTime(2026, 11, 12);

/// Reunión mínima: solo se sobrescribe lo que el caso mira.
NetworkingMeeting _meeting({
  String id = 'm1',
  MeetingState state = MeetingState.pending,
  bool isIncoming = false,
  DateTime? date,
  String? startTime = '09:00',
  String? endTime = '09:30',
}) => NetworkingMeeting(
  id: id,
  state: state,
  stateLabel: '',
  isIncoming: isIncoming,
  counterpart: const NetworkingCard(id: ''),
  date: date ?? _day,
  startTime: startTime,
  endTime: endTime,
);

MeetingSlot _at(int hour, [int minute = 0]) => MeetingSlot(hour * 60 + minute);

void main() {
  group('meetingSlots', () {
    test('con 30 minutos va de 08:00 a 17:30', () {
      final slots = meetingSlots(durationMinutes: 30);
      expect(slots.length, 20);
      expect(slots.first.label, '08:00');
      expect(slots.last.label, '17:30');
    });

    test('con 60 minutos el último inicio es 17:00, para no pasar del cierre', () {
      final slots = meetingSlots(durationMinutes: 60);
      expect(slots.length, 19);
      expect(slots.last.label, '17:00');
      expect(endLabel(slots.last, 60), '18:00');
    });

    test('los slots van de 30 en 30 minutos', () {
      final slots = meetingSlots();
      for (var i = 1; i < slots.length; i++) {
        expect(
          slots[i].minuteOfDay - slots[i - 1].minuteOfDay,
          MeetingHours.stepMinutes,
        );
      }
    });
  });

  group('slotStates', () {
    test('una reunión de 60 minutos ocupa dos slots', () {
      final states = slotStates([
        _meeting(startTime: '09:00', endTime: '10:00'),
      ], _day);
      expect(states[_at(9)], SlotState.taken);
      expect(states[_at(9, 30)], SlotState.taken);
      expect(states[_at(10)], isNull);
    });

    test('una reunión de 90 minutos ocupa tres slots', () {
      final states = slotStates([
        _meeting(startTime: '09:00', endTime: '10:30'),
      ], _day);
      expect(states[_at(9)], SlotState.taken);
      expect(states[_at(9, 30)], SlotState.taken);
      expect(states[_at(10)], SlotState.taken);
      expect(states[_at(10, 30)], isNull);
    });

    test('las reuniones de otro día se ignoran', () {
      final states = slotStates([_meeting(date: _otherDay)], _day);
      expect(states, isEmpty);
    });

    test('rechazada, vencida y eliminada dejan el slot libre', () {
      for (final state in [
        MeetingState.declined,
        MeetingState.expired,
        MeetingState.deleted,
        MeetingState.unknown,
      ]) {
        expect(slotStates([_meeting(state: state)], _day), isEmpty);
      }
    });

    test('una solicitud enviada sin responder bloquea', () {
      final states = slotStates([
        _meeting(state: MeetingState.pending, isIncoming: false),
      ], _day);
      expect(states[_at(9)], SlotState.taken);
    });

    test('una solicitud recibida sin responder solo avisa', () {
      final states = slotStates([
        _meeting(state: MeetingState.pending, isIncoming: true),
      ], _day);
      expect(states[_at(9)], SlotState.tentative);
    });

    test('lo confirmado bloquea en las dos direcciones', () {
      for (final incoming in [true, false]) {
        final states = slotStates([
          _meeting(state: MeetingState.confirmed, isIncoming: incoming),
        ], _day);
        expect(states[_at(9)], SlotState.taken);
      }
    });

    test('taken gana a tentative en el mismo slot', () {
      final states = slotStates([
        _meeting(id: 'a', state: MeetingState.pending, isIncoming: true),
        _meeting(id: 'b', state: MeetingState.confirmed, isIncoming: false),
      ], _day);
      expect(states[_at(9)], SlotState.taken);
    });

    test('una hora ilegible no lanza y no marca nada', () {
      for (final bad in [null, '', '10', '99:99', 'mañana']) {
        expect(slotStates([_meeting(startTime: bad)], _day), isEmpty);
      }
    });

    test('sin hora de fin se ocupa un solo slot', () {
      final states = slotStates([
        _meeting(startTime: '09:00', endTime: null),
      ], _day);
      expect(states[_at(9)], SlotState.taken);
      expect(states[_at(9, 30)], isNull);
    });

    test('una hora fuera de la rejilla se ancla al slot que la contiene', () {
      final states = slotStates([
        _meeting(startTime: '09:15', endTime: '09:45'),
      ], _day);
      expect(states[_at(9)], SlotState.taken);
      expect(states[_at(9, 30)], SlotState.taken);
    });

    test('excludeMeetingId libera la reunión que se está editando', () {
      final states = slotStates(
        [_meeting(id: 'edit-me')],
        _day,
        excludeMeetingId: 'edit-me',
      );
      expect(states, isEmpty);
    });
  });

  group('slotFits', () {
    test('60 minutos no caben si la media hora siguiente está ocupada', () {
      final states = slotStates([
        _meeting(startTime: '09:30', endTime: '10:00'),
      ], _day);
      expect(slotFits(_at(9), 60, states), isFalse);
      expect(slotFits(_at(9), 30, states), isTrue);
    });

    test('nada puede terminar después del cierre', () {
      expect(slotFits(_at(17, 30), 30, const {}), isTrue);
      expect(slotFits(_at(17, 30), 60, const {}), isFalse);
    });

    test('un slot tentative sigue siendo elegible', () {
      final states = slotStates([
        _meeting(state: MeetingState.pending, isIncoming: true),
      ], _day);
      expect(states[_at(9)], SlotState.tentative);
      expect(slotFits(_at(9), 30, states), isTrue);
    });
  });

  group('endLabel, minutesBetween y apiDate', () {
    test('endLabel nunca da la vuelta al reloj', () {
      // Antes `(total ~/ 60) % 24` convertía 23:45 + 60' en 00:45, o sea un fin
      // anterior al inicio.
      expect(endLabel(MeetingSlot(23 * 60 + 45), 60), isNot('00:45'));
      expect(endLabel(_at(17), 60), '18:00');
      expect(endLabel(_at(9, 30), 30), '10:00');
    });

    test('minutesBetween acepta HH:mm y HH:mm:ss', () {
      expect(minutesBetween('10:00', '11:00'), 60);
      expect(minutesBetween('10:00:00', '11:30:00'), 90);
    });

    test('minutesBetween da null con horas ilegibles', () {
      expect(minutesBetween('10:00', null), isNull);
      expect(minutesBetween('mañana', '11:00'), isNull);
    });

    test('apiDate rellena mes y día de un dígito', () {
      expect(apiDate(DateTime(2026, 11, 3)), '2026-11-03');
      expect(apiDate(DateTime(2026, 1, 9)), '2026-01-09');
    });
  });
}
