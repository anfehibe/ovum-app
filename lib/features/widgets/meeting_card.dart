import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';

class MeetingCard extends ConsumerWidget {
  const MeetingCard({super.key, required this.meeting, this.onAccept, this.onDecline});

  final Meeting meeting;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final attendee = ref.watch(attendeeByIdProvider(meeting.attendeeId));
    final name = attendee?.name ?? 'Asistente';
    final showActions = meeting.incoming &&
        meeting.status == MeetingStatus.pending &&
        onAccept != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: name, imageUrl: attendee?.photoUrl, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    if (attendee != null)
                      Text('${attendee.position} · ${attendee.company}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              _StatusChip(status: meeting.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(meeting.subject, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          _row(context, PhosphorIconsRegular.calendarBlank,
              '${meeting.date.monthDay} · ${meeting.startTime} – ${meeting.endTime}'),
          const SizedBox(height: 2),
          _row(context, PhosphorIconsRegular.mapPin, meeting.place),
          if (showActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onAccept,
                    icon: const Icon(PhosphorIconsRegular.check, size: 16),
                    label: const Text(AppStrings.accept),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDecline,
                    icon: const Icon(PhosphorIconsRegular.x, size: 16),
                    label: const Text(AppStrings.decline),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    final scheme = context.scheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final MeetingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MeetingStatus.confirmed => context.ovum.success,
      MeetingStatus.declined => context.scheme.error,
      MeetingStatus.pending => context.ovum.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(status.label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
