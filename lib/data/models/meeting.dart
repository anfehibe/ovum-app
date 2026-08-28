/// Estado de una solicitud de reunión de networking.
enum MeetingStatus {
  pending('Pendiente'),
  confirmed('Confirmada'),
  declined('Rechazada');

  const MeetingStatus(this.label);
  final String label;
}

/// Solicitud de reunión entre el usuario y otro asistente.
/// [incoming] = true cuando la recibió el usuario; false cuando la envió.
class Meeting {
  final String id;
  final String attendeeId;
  final String subject;
  final String message;
  final String place;
  final DateTime date;
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"
  final MeetingStatus status;
  final bool incoming;

  const Meeting({
    required this.id,
    required this.attendeeId,
    required this.subject,
    this.message = '',
    required this.place,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.status = MeetingStatus.pending,
    this.incoming = false,
  });

  Meeting copyWith({MeetingStatus? status}) => Meeting(
        id: id,
        attendeeId: attendeeId,
        subject: subject,
        message: message,
        place: place,
        date: date,
        startTime: startTime,
        endTime: endTime,
        status: status ?? this.status,
        incoming: incoming,
      );

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
        id: json['id'] as String,
        attendeeId: json['attendee_id'] as String,
        subject: json['subject'] as String? ?? '',
        message: json['message'] as String? ?? '',
        place: json['place'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        startTime: json['start_time'] as String? ?? '',
        endTime: json['end_time'] as String? ?? '',
        status: MeetingStatus.values
            .firstWhere((e) => e.name == json['status'], orElse: () => MeetingStatus.pending),
        incoming: json['incoming'] as bool? ?? false,
      );
}
