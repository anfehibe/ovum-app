import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/notifications/notification_routes.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/models/networking_message.dart';
import '../../data/providers/messages_provider.dart';
import '../../data/providers/notifications_provider.dart';
import '../networking/networking_gate.dart';
import '../networking/networking_tab_error.dart';

/// Conversación 1 a 1 con otro asistente.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.attendeeId});

  final String attendeeId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  Timer? _poll;
  StreamSubscription<Map<String, dynamic>>? _pushSub;
  bool _sending = false;
  bool _markedRead = false;

  /// Se guarda en `initState` en vez de leerse en `dispose`: leer un provider
  /// mientras el scope se desmonta puede lanzar.
  late final NotificationService _notifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    _listenPush();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _pushSub?.cancel();
    // Solo se suelta si sigue siendo este hilo: al encadenar dos chats el
    // `initState` del nuevo corre antes que el `dispose` del viejo.
    if (_notifications.activeChatId == widget.attendeeId) {
      _notifications.activeChatId = null;
    }
    _controller.dispose();
    super.dispose();
  }

  /// Una push de mensaje nuevo refresca el hilo al instante, sin esperar al
  /// poll. Se usa `refresh()` (silencioso) y no `invalidate`: invalidar
  /// reconstruiría el notifier y la conversación parpadearía en `LoadingView`.
  void _listenPush() {
    _notifications = ref.read(notificationServiceProvider);
    _notifications.activeChatId = widget.attendeeId; // no notificar lo ya visible
    _pushSub = _notifications.onDataMessage.listen((data) {
      if (chatCounterpartId(data) == widget.attendeeId) _refresh();
    });
  }

  /// El polling solo corre en primer plano: en background no gasta radio ni batería.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _startPolling();
    } else {
      _poll?.cancel();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    final seconds = AppConfig.messagePollSeconds;
    if (seconds <= 0) return; // apagado por configuración
    _poll = Timer.periodic(Duration(seconds: seconds), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    ref.read(messageThreadProvider(widget.attendeeId).notifier).refresh();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(messageThreadProvider(widget.attendeeId).notifier)
          .send(text);
    } catch (e) {
      if (!mounted) return;
      // Devuelve el texto al campo: nada de perder lo que el usuario escribió.
      _controller.text = text;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'No se pudo enviar el mensaje.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NetworkingGate(
      signInMessage: 'Inicia sesión para escribirte con otros asistentes.',
      builder: (context) => _thread(context),
    );
  }

  Widget _thread(BuildContext context) {
    final async = ref.watch(messageThreadProvider(widget.attendeeId));
    final scheme = context.scheme;
    final card = async.valueOrNull?.counterpart;

    // Pedir el hilo es lo que marca los mensajes como leídos en el servidor, así
    // que en cuanto llega la respuesta el contador de la bandeja quedó viejo.
    // Una sola vez: los refrescos del polling no cambian nada ya leído.
    //
    // No se usa `ref.listen`: este cuerpo corre dentro del `builder` de
    // NetworkingGate, o sea el build de OTRO widget, y Riverpod lo rechaza. El
    // post-frame además saca el `invalidate` de la fase de build, donde también
    // sería ilegal. Hacerlo aquí y no en `build()` mantiene el provider creado
    // solo cuando la compuerta está abierta.
    if (!_markedRead && async.hasValue) {
      _markedRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(conversationsProvider);
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            InitialsAvatar(
              name: card?.name ?? '?',
              imageUrl: card?.photoUrl,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card?.name.isNotEmpty == true ? card!.name : 'Chat',
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (card != null && card.subtitle.isNotEmpty)
                    Text(
                      card.subtitle,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => NetworkingTabError(error: e),
        data: (thread) => Column(
          children: [
            Expanded(
              child: thread.messages.isEmpty
                  ? const EmptyState(
                      message: 'Escribe el primer mensaje',
                      icon: PhosphorIconsRegular.chatCircleText,
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: thread.messages.length,
                        itemBuilder: (context, i) => _Bubble(
                          message: thread.messages[thread.messages.length - 1 - i],
                        ),
                      ),
                    ),
            ),
            if (thread.closedReason != null)
              _closed(context, thread.closedReason!)
            else
              _InputBar(
                controller: _controller,
                onSend: _send,
                sending: _sending,
              ),
          ],
        ),
      ),
    );
  }

  Widget _closed(BuildContext context, String reason) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIconsRegular.info,
              size: 18,
              color: context.scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reason,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final NetworkingMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final mine = message.isMine;
    final onBubble = mine ? scheme.onPrimary : scheme.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        // La burbuja optimista se ve atenuada hasta que el servidor la confirma.
        opacity: message.pending ? 0.6 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          decoration: BoxDecoration(
            color: mine ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.text,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: onBubble),
              ),
              const SizedBox(height: 2),
              message.pending
                  ? Icon(
                      PhosphorIconsRegular.clock,
                      size: 12,
                      color: onBubble.withValues(alpha: 0.7),
                    )
                  : Text(
                      message.sentAt?.hm ?? '',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: onBubble.withValues(alpha: 0.7)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.sending,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Mensaje…',
                  counterText: '', // el tope importa, el contador estorba
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: scheme.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: sending ? null : onSend,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: sending
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Icon(
                          PhosphorIconsRegular.paperPlaneRight,
                          color: scheme.onPrimary,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
