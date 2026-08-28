import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/live_provider.dart';

class PollsScreen extends ConsumerWidget {
  const PollsScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionByIdProvider(sessionId));
    final polls = ref.watch(pollsForSessionProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.polls),
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
      body: polls.isEmpty
          ? const EmptyState(message: 'No hay encuestas en esta sesión', icon: PhosphorIconsRegular.chartBar)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: polls.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) => _PollCard(poll: polls[i]),
            ),
    );
  }
}

class _PollCard extends ConsumerWidget {
  const _PollCard({required this.poll});
  final Poll poll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final answers = ref.watch(pollAnswersProvider);
    final myAnswer = answers[poll.id];
    final answered = myAnswer != null;

    final totalVotes = poll.options.fold<int>(0, (s, o) => s + o.seedVotes) + (answered ? 1 : 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(poll.question, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          for (final option in poll.options) ...[
            if (answered)
              _resultBar(context, option, myAnswer, totalVotes)
            else
              _optionButton(context, ref, option),
            const SizedBox(height: 10),
          ],
          if (answered)
            Row(
              children: [
                Icon(PhosphorIconsRegular.check, size: 15, color: scheme.tertiary),
                const SizedBox(width: 6),
                Text('¡Gracias por participar!',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.tertiary)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _optionButton(BuildContext context, WidgetRef ref, PollOption option) {
    final scheme = context.scheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(pollAnswersProvider.notifier).answer(poll.id, option.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(option.text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }

  Widget _resultBar(BuildContext context, PollOption option, String myAnswer, int total) {
    final scheme = context.scheme;
    final votes = option.seedVotes + (myAnswer == option.id ? 1 : 0);
    final pct = total == 0 ? 0.0 : votes / total;
    final selected = myAnswer == option.id;
    final color = selected ? scheme.primary : scheme.secondary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 46,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: scheme.surfaceContainerHigh)),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: ColoredBox(color: color.withValues(alpha: 0.22)),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                children: [
                  if (selected) ...[
                    Icon(PhosphorIconsRegular.check, size: 16, color: color),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(option.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            )),
                  ),
                  Text('${(pct * 100).round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700, color: color)),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
