import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/chat_provider.dart';
import '../../data/providers/content_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partners = ref.watch(conversationPartnersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.chat)),
      body: partners.isEmpty
          ? const EmptyState(
              message: 'No tienes conversaciones.\nEscríbele a un asistente desde su perfil.',
              icon: PhosphorIconsRegular.chatsCircle,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: partners.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ConversationTile(attendeeId: partners[i]),
            ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.attendeeId});
  final String attendeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final attendee = ref.watch(attendeeByIdProvider(attendeeId));
    final messages = ref.watch(conversationProvider(attendeeId));
    final last = messages.isNotEmpty ? messages.last : null;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(R.chatWith(attendeeId)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              InitialsAvatar(name: attendee?.name ?? '?', imageUrl: attendee?.photoUrl, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(attendee?.name ?? 'Asistente',
                              style: Theme.of(context).textTheme.titleSmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (last != null)
                          Text(last.time.hm,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (last != null)
                      Text(
                        '${last.sentByMe ? 'Tú: ' : ''}${last.text}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
