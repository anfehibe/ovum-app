import '../../core/utils/date_ext.dart';
import 'networking_card.dart';

/// Estados de una reunión (`reuniones.estatus` del backend).
///
/// Para **mostrar** se usa el `estado` que manda el servidor
/// ([NetworkingMeeting.stateLabel]), no estas etiquetas: el backend es dueño de esa
/// copy y puede agregar estados sin avisar. Este enum existe solo para decidir
/// color y agrupación.
enum MeetingState {
  deleted(0),
  pending(1),
  confirmed(2),
  declined(3),
  rescheduled(4),
  expired(5),
  unknown(-1);

  const MeetingState(this.code);
  final int code;

  static MeetingState fromCode(Object? raw) {
    final code = raw is num ? raw.toInt() : int.tryParse('$raw');
    return values.firstWhere((e) => e.code == code, orElse: () => unknown);
  }
}

/// Resultado de responder una reunión (`POST .../meetings/{id}/respond`) o de
/// cancelarla (`POST .../meetings/{id}/cancel`).
///
/// Al **aceptar**, el backend auto-asigna mesa y devuelve dónde quedó; al
/// rechazar o cancelar no manda `lugar` ni `mesa`.
typedef MeetingOutcome = ({
  String id,
  MeetingState state,
  String stateLabel,
  String? place,
  int table,
});

/// Dónde quedó la reunión tras aceptarla, o `null` si no se asignó lugar.
String? outcomePlaceLabel(MeetingOutcome o) {
  if (o.place == null || o.place!.isEmpty) return null;
  return o.table > 0 ? 'Mesa ${o.table} · ${o.place}' : o.place;
}

/// Quién canceló una reunión **que ya estaba confirmada**, y cuándo
/// (`cancelacion` del listado). El backend solo lo registra en ese caso: una
/// pendiente cancelada llega sin este dato, y la tarjeta dice solo "Cancelada".
class MeetingCancellation {
  final String byId;
  final String byName;

  /// Instante de la cancelación, ya en hora **local** (ver el mapper).
  final DateTime? at;

  const MeetingCancellation({required this.byId, this.byName = '', this.at});
}

/// "Cancelada por Ana Pérez el 10 nov a las 08:00".
///
/// [myId] convierte el nombre en "ti"; [now] existe para los tests.
String cancellationLabel(MeetingCancellation c, {String? myId, DateTime? now}) {
  final who = myId != null && c.byId == myId
      ? 'ti'
      : (c.byName.isEmpty ? 'la otra persona' : c.byName);
  final at = c.at;
  if (at == null) return 'Cancelada por $who';
  final day = at.sameDay(now ?? DateTime.now())
      ? 'hoy'
      : 'el ${at.monthDayShort}';
  return 'Cancelada por $who $day a las ${at.hm}';
}

/// Reunión de networking (`GET /networking/meetings`).
class NetworkingMeeting {
  final String id;
  final MeetingState state;

  /// Etiqueta de estado tal cual la manda el backend (`estado`).
  final String stateLabel;

  /// `true` cuando el usuario es el destinatario (`soy == 'destinatario'`).
  final bool isIncoming;

  /// La contraparte (`con`). Ojo: su `isFavorite` siempre llega `false` en este
  /// endpoint, así que no sirve para sembrar el estado de favoritos.
  final NetworkingCard counterpart;

  final String message;
  final String reply;
  final DateTime? date;
  final String? startTime;
  final String? endTime;

  /// Sala asignada (`lugar`). La mandan tanto el listado (desde `2723473`) como
  /// la respuesta de aceptar; `null` mientras no se haya asignado.
  final String? place;

  /// Mesa asignada. `0` significa "sin mesa numerada" (espacio abierto) o
  /// "pendiente de asignar" — se distingue por si hay [place].
  final int table;

  /// Quién la canceló y cuándo. Solo viene si estaba confirmada al cancelarla.
  final MeetingCancellation? cancellation;

  const NetworkingMeeting({
    required this.id,
    required this.state,
    required this.stateLabel,
    required this.isIncoming,
    required this.counterpart,
    this.message = '',
    this.reply = '',
    this.date,
    this.startTime,
    this.endTime,
    this.place,
    this.table = 0,
    this.cancellation,
  });

  bool get hasSchedule => date != null || (startTime?.isNotEmpty ?? false);

  /// Dónde es la reunión, o `null` si todavía no se sabe (la copy de ese caso
  /// vive en la UI). Tres formas posibles: con mesa numerada, espacio abierto
  /// (sala sin mesa), o nada asignado.
  String? get placeLabel {
    if (place == null || place!.isEmpty) return null;
    return table > 0 ? 'Mesa $table · $place' : place;
  }

  /// Pendiente o confirmada: las únicas que todavía se pueden tocar.
  bool get isActive =>
      state == MeetingState.pending || state == MeetingState.confirmed;

  /// El día de la reunión ya pasó. Es a nivel de **día** a propósito: la hora
  /// exacta la valida el backend (422 "ya pasó"), y comparar horas aquí obligaría
  /// a resolver la zona del congreso contra la del dispositivo.
  bool isPastOn(DateTime today) {
    final d = date;
    if (d == null) return false;
    return DateTime(
      d.year,
      d.month,
      d.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  /// Solo quien la envió puede cambiarla, mientras siga viva.
  bool canEditOn(DateTime today) => !isIncoming && isActive && !isPastOn(today);

  /// Quien la envió puede retirarla pendiente o confirmada; quien la recibió,
  /// solo una vez aceptada (la pendiente se **rechaza**, no se cancela).
  bool canCancelOn(DateTime today) =>
      isActive &&
      !isPastOn(today) &&
      (!isIncoming || state == MeetingState.confirmed);

  bool get canEdit => canEditOn(DateTime.now());
  bool get canCancel => canCancelOn(DateTime.now());

  NetworkingMeeting applyOutcome(MeetingOutcome outcome) => NetworkingMeeting(
    id: id,
    state: outcome.state,
    stateLabel: outcome.stateLabel.isEmpty ? stateLabel : outcome.stateLabel,
    isIncoming: isIncoming,
    counterpart: counterpart,
    message: message,
    reply: reply,
    date: date,
    startTime: startTime,
    endTime: endTime,
    place: outcome.place ?? place,
    table: outcome.table,
    cancellation: cancellation,
  );
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

  /// **El otro asistente** está ocupado a esa hora. Solo lo sabe el servidor
  /// (`ocupado_usuario` de `/availability`); el cálculo local nunca lo produce.
  /// Bloquea igual que [taken], pero el motivo que se enseña es distinto.
  otherBusy,
}

/// Un hueco de la rejilla de reuniones, tal como lo calcula el servidor.
///
/// Sustituye a la rejilla que la app se inventaba: aquí `busyOther` es lo que
/// **no** se podía saber en el cliente — si la otra persona ya está ocupada.
class AvailabilitySlot {
  /// `"HH:mm"`; es a la vez la etiqueta visible y lo que viaja en `hora_inicio`.
  final String start;
  final String end;

  /// Veredicto del servidor: hay sitio, nadie choca y queda mesa. Es lo que
  /// decide si el hueco se puede elegir; los demás campos solo explican por qué.
  final bool available;

  /// Choque en **mi** agenda. `tentative` avisa pero no bloquea (una solicitud
  /// recibida sin responder), igual que el cálculo local que había antes.
  final SlotState selfState;

  /// `true` si el otro asistente ya está ocupado a esa hora. **`null` cuando no
  /// se pidió con `user`**, que no es lo mismo que "está libre".
  final bool? busyOther;

  /// Mesas libres en ese hueco, o `null` si el congreso no tiene rejilla cargada.
  final int? freeTables;

  const AvailabilitySlot({
    required this.start,
    required this.end,
    this.available = false,
    this.selfState = SlotState.free,
    this.busyOther,
    this.freeTables,
  });

  /// Motivo por el que no se puede elegir, para enseñárselo al usuario. `null`
  /// si está disponible.
  String? get blockedReason {
    if (available) return null;
    if (busyOther == true) return 'La otra persona no está libre a esta hora';
    if (selfState == SlotState.taken) return 'Ya tienes algo a esta hora';
    if (freeTables == 0) return 'No quedan mesas libres';
    return 'No disponible';
  }
}

/// Respuesta de `GET /networking/availability`.
class MeetingAvailability {
  final List<AvailabilitySlot> slots;

  /// `true` si la rejilla salió de filas reales de `horarios`; `false` si el
  /// servidor cayó a su ventana por defecto (08:00–18:00) porque no hay ninguna.
  /// Se conserva para poder avisar de que las mesas no están configuradas.
  final bool fromSchedule;

  /// El congreso admite reuniones sin mesa numerada.
  final bool openSpace;

  /// Minutos por hueco (30 o 60), como los devolvió el servidor.
  final int periodMinutes;

  const MeetingAvailability({
    this.slots = const [],
    this.fromSchedule = false,
    this.openSpace = false,
    this.periodMinutes = 30,
  });

  bool get isEmpty => slots.isEmpty;
}
