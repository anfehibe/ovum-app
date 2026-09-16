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
