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

/// Resultado de responder una reunión (`POST .../meetings/{id}/respond`).
///
/// Al **aceptar**, el backend auto-asigna mesa y devuelve dónde quedó; al
/// rechazar no manda `lugar` ni `mesa`.
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

  /// Sala asignada. **El listado de reuniones todavía NO la devuelve** (solo la
  /// respuesta de aceptar), así que normalmente llega `null`; se lee igual para
  /// que el día que el backend la agregue al listado funcione sin tocar código.
  final String? place;

  /// Mesa asignada. `0` significa "sin mesa numerada" (espacio abierto) o
  /// "pendiente de asignar" — se distingue por si hay [place].
  final int table;

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
  });

  bool get hasSchedule => date != null || (startTime?.isNotEmpty ?? false);

  /// Dónde es la reunión, o `null` si todavía no se sabe (la copy de ese caso
  /// vive en la UI). Tres formas posibles: con mesa numerada, espacio abierto
  /// (sala sin mesa), o nada asignado.
  String? get placeLabel {
    if (place == null || place!.isEmpty) return null;
    return table > 0 ? 'Mesa $table · $place' : place;
  }

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
