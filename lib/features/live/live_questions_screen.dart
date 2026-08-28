import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/live_provider.dart';

class LiveQuestionsScreen extends ConsumerStatefulWidget {
  const LiveQuestionsScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<LiveQuestionsScreen> createState() => _LiveQuestionsScreenState();
}

class _LiveQuestionsScreenState extends ConsumerState<LiveQuestionsScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(questionsProvider.notifier).add(widget.sessionId, text);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionByIdProvider(widget.sessionId));
    final questions = ref.watch(questionsForSessionProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.liveQuestions),
        bottom: session == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                  child: Text(session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: context.scheme.onSurfaceVariant)),
                ),
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: questions.isEmpty
                ? const EmptyState(
                    message: 'Sé el primero en preguntar',
                    icon: PhosphorIconsRegular.chatCircleText,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: questions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _QuestionCard(question: questions[i]),
                  ),
          ),
          _InputBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

class _QuestionCard extends ConsumerWidget {
  const _QuestionCard({required this.question});
  final LiveQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question.text, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(question.authorName,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => ref.read(questionsProvider.notifier).upvote(question.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(PhosphorIconsRegular.thumbsUp, size: 16, color: scheme.onPrimaryContainer),
                  Text('${question.upvotes}',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
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
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Escribe tu pregunta…'),
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
