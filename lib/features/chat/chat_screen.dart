import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/chat_provider.dart';
import '../../data/providers/content_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.attendeeId});
  final String attendeeId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(chatProvider.notifier).send(widget.attendeeId, text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final attendee = ref.watch(attendeeByIdProvider(widget.attendeeId));
    final messages = ref.watch(conversationProvider(widget.attendeeId));
    final scheme = context.scheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            InitialsAvatar(name: attendee?.name ?? '?', imageUrl: attendee?.photoUrl, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(attendee?.name ?? 'Chat',
                      style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  if (attendee != null)
                    Text(attendee.company,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const EmptyState(
                    message: 'Escribe el primer mensaje',
                    icon: PhosphorIconsRegular.chatCircleText,
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[messages.length - 1 - i];
                      return _Bubble(message: msg);
                    },
                  ),
          ),
          _InputBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final mine = message.sentByMe;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: mine ? scheme.onPrimary : scheme.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              message.time.hm,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: (mine ? scheme.onPrimary : scheme.onSurfaceVariant).withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

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
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Mensaje…'),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: scheme.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onSend,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(PhosphorIconsRegular.paperPlaneRight, color: scheme.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
