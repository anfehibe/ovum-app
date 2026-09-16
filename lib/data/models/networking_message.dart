import 'networking_card.dart';

/// Un mensaje del chat 1 a 1 entre asistentes.
class NetworkingMessage {
  final String id;

  /// `true` si lo envió el usuario actual (`mio` del API).
  final bool isMine;
  final String text;

  /// Hora local. **Ojo:** aquí sí se convierte a local, a diferencia de la agenda
  /// (ver `wallClock` en `date_ext.dart`); el backend corre en `America/Bogota` y
  /// un mensaje recién enviado se vería con horas de diferencia sin convertir.
  final DateTime? sentAt;

  /// Burbuja optimista: ya se pintó pero el servidor aún no la confirma. El mapper
  /// nunca lo pone en `true`; solo lo usa el envío mientras espera respuesta.
  final bool pending;

  const NetworkingMessage({
    required this.id,
    required this.text,
    this.isMine = false,
    this.sentAt,
    this.pending = false,
  });
}

/// Resumen de una conversación para la lista de chats.
class ConversationSummary {
  final NetworkingCard counterpart;

  /// Vista previa del último mensaje. **Ya viene recortada por el servidor**
  /// (120 caracteres, sin HTML): no es el texto completo y no hay que recortarla más.
  final String lastText;
  final bool lastIsMine;
  final DateTime? lastAt;

  /// Total de mensajes de la conversación. **No es un contador de no leídos** —
  /// el backend no guarda estado de lectura, así que no sirve para un badge.
  final int total;

  const ConversationSummary({
    required this.counterpart,
    this.lastText = '',
    this.lastIsMine = false,
    this.lastAt,
    this.total = 0,
  });
}

/// Hilo completo con un asistente.
typedef MessageThread = ({
  NetworkingCard counterpart,
  List<NetworkingMessage> messages,
});
