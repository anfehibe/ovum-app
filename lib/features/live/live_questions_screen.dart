import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/live_provider.dart';
import '../../data/providers/user_provider.dart';

class LiveQuestionsScreen extends ConsumerStatefulWidget {
  const LiveQuestionsScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<LiveQuestionsScreen> createState() => _LiveQuestionsScreenState();
}

class _LiveQuestionsScreenState extends ConsumerState<LiveQuestionsScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(ovumRepositoryProvider).askQuestion(widget.sessionId, text);
      _controller.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        _toast('Tu pregunta fue enviada. Aparecerá cuando el organizador la apruebe.');
      }
      // Por si el backend la auto-aprueba, refrescamos la lista.
      ref.invalidate(sessionQuestionsProvider(widget.sessionId));
    } on ApiException catch (e) {
      if (mounted) {
        _toast(e.isUnauthorized
            ? 'Inicia sesión para enviar tu pregunta.'
            : 'No se pudo enviar la pregunta. Intenta de nuevo.');
      }
    } catch (_) {
      if (mounted) _toast('No se pudo enviar la pregunta. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionByIdProvider(widget.sessionId));
    final async = ref.watch(sessionQuestionsProvider(widget.sessionId));
    final isGuest = ref.watch(isGuestProvider);

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
            child: async.when(
              loading: () => const LoadingView(),
              error: (_, _) => const ErrorView(),
              data: (questions) => RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(sessionQuestionsProvider(widget.sessionId).future),
                child: questions.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          SizedBox(height: 72),
                          EmptyState(
                            message:
                                'Aún no hay preguntas aprobadas.\nEnvía la tuya al ponente.',
                            icon: PhosphorIconsRegular.chatCircleText,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: questions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _QuestionCard(question: questions[i]),
                      ),
              ),
            ),
          ),
          if (isGuest)
            const _GuestNote()
          else
            _InputBar(controller: _controller, onSend: _send, sending: _sending),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});
  final LiveQuestion question;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(PhosphorIconsRegular.chatCircleText, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(question.question,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (question.isAnswered) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Respuesta',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(question.answer!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(PhosphorIconsRegular.clock, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('En espera de respuesta',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Aviso para invitados: el envío de preguntas requiere sesión iniciada.
class _GuestNote extends StatelessWidget {
  const _GuestNote();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(PhosphorIconsRegular.info, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Inicia sesión para enviar tus preguntas al ponente.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend, required this.sending});
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
                maxLines: 3,
                enabled: !sending,
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
                onTap: sending ? null : onSend,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: sending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.onPrimary),
                        )
                      : Icon(PhosphorIconsRegular.paperPlaneRight, color: scheme.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
