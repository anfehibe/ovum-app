import 'package:intl/intl.dart';

import '../../data/models/networking_meeting.dart';
import '../constants/ovum_event.dart';
import 'date_ext.dart';

/// Rejilla de horas para solicitar reuniones y ocupación de la agenda propia.
///
/// Todo esto es lógica pura a propósito: las reglas de solapamiento son el valor
/// real de la pantalla y así se prueban sin `pumpWidget`.

/// Un slot de la rejilla de reuniones. Hora de pared, sin zona horaria
/// (ver el doc de [MeetingHours]).
class MeetingSlot {
  const MeetingSlot(this.minuteOfDay);

  /// Minutos desde medianoche; siempre múltiplo de [MeetingHours.stepMinutes].
  final int minuteOfDay;

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  /// `"HH:mm"` — es a la vez la etiqueta visible y el valor que viaja en
  /// `hora_inicio`, así que no hay dos formatos que mantener sincronizados.
  String get label => _hhmm(minuteOfDay);

  @override
  bool operator ==(Object other) =>
      other is MeetingSlot && other.minuteOfDay == minuteOfDay;

  @override
  int get hashCode => minuteOfDay.hashCode;

  @override
  String toString() => 'MeetingSlot($label)';
}

/// Por qué un slot no está del todo libre.
///
/// [slotStates] nunca devuelve [free]: lo que no está en el mapa lo está. El
/// valor existe para que quien lo consulte escriba `states[slot] ?? free`.
enum SlotState {
  free,

  /// Solicitud **recibida** que el usuario todavía no ha respondido. Avisa, pero
  /// no bloquea: no choca en el servidor, y si bloqueara, cualquiera podría
  /// tapar una agenda ajena a base de solicitudes.
  tentative,

  /// Reunión confirmada (en cualquier dirección) o solicitud enviada aún viva.
  taken,
}

/// Slots en los que puede **empezar** una reunión de [durationMinutes] sin
/// pasarse de [MeetingHours.closingMinute].
List<MeetingSlot> meetingSlots({
  int durationMinutes = MeetingHours.defaultDuration,
}) {
  final last = MeetingHours.closingMinute - durationMinutes;
  return [
    for (var m = MeetingHours.openingMinute;
        m <= last;
        m += MeetingHours.stepMinutes)
      MeetingSlot(m),
  ];
}

/// Estado de cada slot de [day] según las reuniones del usuario.
///
/// Solo mira la agenda propia: el API no expone la del destinatario (ver
/// `docs/API-PENDIENTES.md`). [excludeMeetingId] libera la reunión que se está
/// editando; hoy nadie lo usa, lo necesitará el día que haya reprogramación.
Map<MeetingSlot, SlotState> slotStates(
  List<NetworkingMeeting> meetings,
  DateTime day, {
  String? excludeMeetingId,
}) {
  final states = <MeetingSlot, SlotState>{};

  for (final m in meetings) {
    if (excludeMeetingId != null && m.id == excludeMeetingId) continue;

    final date = m.date;
    if (date == null || !date.sameDay(day)) continue;

    final severity = _severityOf(m);
    if (severity == null) continue;

    // Una hora ilegible no puede tumbar la pantalla: se ignora la reunión.
    final start = minuteOfDayOf(m.startTime);
    if (start == null) continue;

    // El panel web permite horas fuera de la rejilla (09:15). Se ancla hacia
    // atrás para que bloqueen el slot que las contiene.
    final anchored = start - start % MeetingHours.stepMinutes;
    final span = minutesBetween(m.startTime, m.endTime) ?? 0;
    final end = start + (span > 0 ? span : MeetingHours.stepMinutes);

    for (var at = anchored; at < end; at += MeetingHours.stepMinutes) {
      final slot = MeetingSlot(at);
      // `taken` gana: dos reuniones en el mismo slot se resuelven por la peor.
      if (states[slot] != SlotState.taken) states[slot] = severity;
    }
  }

  return states;
}

/// `true` si una reunión de [durationMinutes] que empiece en [slot] cabe antes
/// del cierre y ningún slot que ocuparía está [SlotState.taken].
///
/// Lo segundo es lo que evita reservar 60′ a las 09:00 teniendo las 09:30
/// tomadas.
bool slotFits(
  MeetingSlot slot,
  int durationMinutes,
  Map<MeetingSlot, SlotState> states,
) {
  if (slot.minuteOfDay < MeetingHours.openingMinute) return false;
  if (slot.minuteOfDay + durationMinutes > MeetingHours.closingMinute) {
    return false;
  }
  for (var at = slot.minuteOfDay;
      at < slot.minuteOfDay + durationMinutes;
      at += MeetingHours.stepMinutes) {
    if (states[MeetingSlot(at)] == SlotState.taken) return false;
  }
  return true;
}

/// Hora de fin `"HH:mm"`. Aritmética pura, **sin `% 24`**: antes 23:45 + 60′
/// devolvía `00:45`, o sea un fin anterior al inicio. Fuera de la rejilla puede
/// dar `24:45`, que es imposible de alcanzar porque [meetingSlots] acota el
/// inicio — y visiblemente roto es mejor que silenciosamente al revés.
String endLabel(MeetingSlot slot, int durationMinutes) =>
    _hhmm(slot.minuteOfDay + durationMinutes);

/// `"HH:mm"` o `"HH:mm:ss"` → minutos desde medianoche; `null` si no parsea.
int? minuteOfDayOf(String? hhmm) {
  if (hhmm == null) return null;
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// Minutos entre dos horas `"HH:mm[:ss]"`; `null` si alguna no parsea.
int? minutesBetween(String? start, String? end) {
  final s = minuteOfDayOf(start);
  final e = minuteOfDayOf(end);
  if (s == null || e == null) return null;
  return e - s;
}

/// `"yyyy-MM-dd"` para el cuerpo del POST.
String apiDate(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

/// Cuánto estorba una reunión, o `null` si no estorba.
///
/// Espeja la regla del propio backend (`Web/ReunionController::horarios`): el
/// remitente se bloquea con `estatus in (1,2)`; el destinatario, solo con
/// `estatus == 2`.
SlotState? _severityOf(NetworkingMeeting m) => switch (m.state) {
  MeetingState.confirmed => SlotState.taken,
  MeetingState.pending ||
  MeetingState.rescheduled => m.isIncoming ? SlotState.tentative : SlotState.taken,
  MeetingState.declined ||
  MeetingState.expired ||
  MeetingState.deleted ||
  MeetingState.unknown => null,
};

String _hhmm(int minuteOfDay) {
  final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
  final m = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$h:$m';
}
