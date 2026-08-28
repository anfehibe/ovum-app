/// Mensaje de una conversación 1-a-1 (chat mock en memoria).
class ChatMessage {
  final String id;
  final String attendeeId; // interlocutor
  final String text;
  final bool sentByMe;
  final DateTime time;

  const ChatMessage({
    required this.id,
    required this.attendeeId,
    required this.text,
    required this.sentByMe,
    required this.time,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        attendeeId: json['attendee_id'] as String,
        text: json['text'] as String,
        sentByMe: json['sent_by_me'] as bool? ?? false,
        time: DateTime.parse(json['time'] as String),
      );
}
