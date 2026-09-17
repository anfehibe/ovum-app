import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/models/networking_message.dart';
import '../../data/providers/messages_provider.dart';
import '../networking/networking_gate.dart';
import '../networking/networking_tab_error.dart';

/// Mis conversaciones.
///
/// El badge sale de `no_leidos`, que el backend calcula contra `mensajes.leido_at`
/// (no de `total`, que es el histórico). Se limpia solo: abrir el hilo marca los
/// mensajes como leídos en el servidor y `ChatScreen` invalida esta lista.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis chats')),
      body: NetworkingGate(
        signInMessage: 'Inicia sesión para escribirte con otros asistentes.',
        builder: (context) => _list(ref),
      ),
    );
  }

  Widget _list(WidgetRef ref) {
    final async = ref.watch(conversationsProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => NetworkingTabError(error: e),
      data: (conversations) => RefreshIndicator(
        onRefresh: () => ref.refresh(conversationsProvider.future),
        child: conversations.isEmpty
            // Dentro de un scrollable para que el pull-to-refresh funcione vacío.
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    message:
                        'No tienes conversaciones.\nEscríbele a alguien desde su ficha en el directorio.',
                    icon: PhosphorIconsRegular.chatsCircle,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: conversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    _ConversationTile(conversation: conversations[i]),
              ),
      ),
    );
  }
}

/// Contador de no leídos. A partir de 100 muestra "99+": el ancho del número no
/// puede empujar al nombre de la conversación.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final card = conversation.counterpart;
    // El servidor ya recorta el preview a 120 caracteres; no se recorta más.
    final preview = conversation.lastIsMine
        ? 'Tú: ${conversation.lastText}'
        : conversation.lastText;
    final unread = conversation.hasUnread;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(R.chatWith(card.id)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              InitialsAvatar(name: card.name, imageUrl: card.photoUrl, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name.isEmpty ? 'Asistente' : card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        // Con mensajes sin leer el preview se resalta: el badge
                        // solo no basta para escanear la lista de un vistazo.
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
                          fontWeight: unread ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (conversation.lastAt != null)
                    Text(
                      conversation.lastAt!.hm,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: unread ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  if (unread) ...[
                    const SizedBox(height: 6),
                    _UnreadBadge(count: conversation.unread),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
