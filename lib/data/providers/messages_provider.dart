import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../models/networking_card.dart';
import '../models/networking_message.dart';
import 'content_providers.dart';
import 'networking_provider.dart';

/// Mis conversaciones. Depende de la compuerta de networking: si está cerrada no
/// se gasta una petición (la pantalla muestra el motivo, nunca la lista).
///
/// `autoDispose` a propósito: es una bandeja de entrada, no contenido estático.
/// Cacheada para siempre se quedaría mostrando un preview viejo hasta que el
/// usuario hiciera pull-to-refresh, porque nadie avisa de los mensajes entrantes.
/// Así se recarga cada vez que se abre la pantalla.
final conversationsProvider = FutureProvider.autoDispose<List<ConversationSummary>>((
  ref,
) async {
  final access = await ref.watch(networkingAccessProvider.future);
  if (!access.isOpen) return const [];
  return ref.watch(networkingServiceProvider).conversations();
});

typedef ThreadState = ({
  NetworkingCard counterpart,
  List<NetworkingMessage> messages,

  /// Motivo, dicho por el backend, por el que ya no se puede escribir (hoy solo
  /// "el congreso ya finalizó"). Se queda pegado una vez que aparece.
  String? closedReason,
});

/// Hilo con un asistente.
///
/// Es el primer notifier *family* del proyecto: `autoDispose` es importante —
/// sin él el hilo seguiría vivo (y refrescándose) después de salir de la pantalla.
class MessageThreadNotifier
    extends AutoDisposeFamilyAsyncNotifier<ThreadState, String> {
  @override
  Future<ThreadState> build(String userId) async {
    final thread = await ref.watch(networkingServiceProvider).thread(userId);
    return (
      counterpart: thread.counterpart,
      messages: thread.messages,
      closedReason: null,
    );
  }

  /// Refresco silencioso (polling y pull-to-refresh).
  ///
  /// **Nunca** pasa a `AsyncLoading`: eso vaciaría la conversación que el usuario
  /// está leyendo. Un fallo se traga a propósito — un poll caído no debe cambiar
  /// una conversación legible por una pantalla de error.
  Future<void> refresh() async {
    final current = state.valueOrNull;
    try {
      final fresh = await ref.read(networkingServiceProvider).thread(arg);
      // Conserva las burbujas que aún no confirma el servidor.
      final pendientes = (current?.messages ?? const <NetworkingMessage>[])
          .where((m) => m.pending)
          .toList();
      state = AsyncData((
        counterpart: fresh.counterpart,
        messages: [...fresh.messages, ...pendientes],
        closedReason: current?.closedReason,
      ));
    } catch (_) {
      // se reintenta en el siguiente ciclo
    }
  }

  /// Envía con burbuja optimista y **adopta el mensaje que devuelve el servidor**
  /// (id y fecha reales) en vez de quedarse con la copia local. Si falla, quita la
  /// burbuja y relanza para que la pantalla devuelva el texto al campo.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    final current = state.valueOrNull;
    if (trimmed.isEmpty || current == null) return;

    final tempId = 'tmp:${DateTime.now().microsecondsSinceEpoch}';
    state = AsyncData((
      counterpart: current.counterpart,
      messages: [
        ...current.messages,
        NetworkingMessage(
          id: tempId,
          isMine: true,
          text: trimmed,
          sentAt: DateTime.now(),
          pending: true,
        ),
      ],
      closedReason: current.closedReason,
    ));

    try {
      final enviado = await ref
          .read(networkingServiceProvider)
          .sendMessage(arg, trimmed);
      final base = state.valueOrNull ?? current;
      state = AsyncData((
        counterpart: base.counterpart,
        messages: [
          for (final m in base.messages)
            if (m.id == tempId) enviado else m,
        ],
        closedReason: base.closedReason,
      ));
      ref.invalidate(conversationsProvider); // refresca el preview de la lista
    } catch (e) {
      final base = state.valueOrNull ?? current;
      // El backend es la única autoridad sobre "el congreso ya terminó": no se
      // deduce de OvumEvent.endDate, que es copy de UI y puede diverger.
      final cerrado = e is ApiException &&
              e.isValidation &&
              e.message.toLowerCase().contains('finaliz')
          ? e.message
          : base.closedReason;
      state = AsyncData((
        counterpart: base.counterpart,
        messages: base.messages.where((m) => m.id != tempId).toList(),
        closedReason: cerrado,
      ));
      rethrow;
    }
  }
}

final messageThreadProvider = AsyncNotifierProvider.autoDispose
    .family<MessageThreadNotifier, ThreadState, String>(
      MessageThreadNotifier.new,
    );
