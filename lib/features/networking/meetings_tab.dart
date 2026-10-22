import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/states.dart';
import '../../data/models/networking_meeting.dart';
import '../../data/providers/networking_provider.dart';
import '../widgets/meeting_card.dart';
import 'networking_tab_error.dart';

/// Mis reuniones: tablero de conteos + recibidas / enviadas.
class MeetingsTab extends ConsumerWidget {
  const MeetingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkingMeetingsProvider);
    // Se pinta desde el overlay (respuestas recién dadas ya aplicadas) para que
    // las tarjetas y los contadores no se contradigan mientras llega el refetch.
    final meetings = ref.watch(overlaidMeetingsProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => NetworkingTabError(error: e),
      data: (_) => RefreshIndicator(
        onRefresh: () => ref.refresh(networkingMeetingsProvider.future),
        child: _content(context, ref, meetings),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    List<NetworkingMeeting> meetings,
  ) {
    final counts = ref.watch(meetingCountsProvider);
    // Lo accionable primero: una solicitud pendiente no debe quedar debajo de
    // reuniones ya resueltas, y las canceladas, que ya no son nada, al final.
    // `sort` es estable en Dart: dentro de cada grupo se respeta el orden del
    // servidor (la más reciente primero).
    int rank(NetworkingMeeting m) => switch (m.state) {
      MeetingState.pending => 0,
      MeetingState.deleted => 2,
      _ => 1,
    };
    final received = meetings.where((m) => m.isIncoming).toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    final sent = meetings.where((m) => !m.isIncoming).toList()
      ..sort(
        (a, b) => (a.state == MeetingState.deleted ? 1 : 0).compareTo(
          b.state == MeetingState.deleted ? 1 : 0,
        ),
      );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Row(
          children: [
            _StatTile(
              label: context.l10n.networkingMeetingsReceived,
              value: counts.received,
              color: context.scheme.primary,
            ),
            const SizedBox(width: 10),
            _StatTile(
              label: context.l10n.networkingMeetingsConfirmed,
              value: counts.confirmed,
              color: context.ovum.success,
            ),
            const SizedBox(width: 10),
            _StatTile(
              label: context.l10n.networkingMeetingsPending,
              value: counts.pending,
              color: context.ovum.warning,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(context.l10n.networkingRequestsReceived, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (received.isEmpty)
          _emptyHint(context, context.l10n.networkingNoRequestsReceived)
        else
          for (final m in received)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MeetingCard(meeting: m),
            ),
        const SizedBox(height: 24),
        Text(context.l10n.networkingSentByYou, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (sent.isEmpty)
          _emptyHint(context, context.l10n.networkingNoRequestsSent)
        else
          for (final m in sent)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MeetingCard(meeting: m),
            ),
      ],
    );
  }

  Widget _emptyHint(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.handshake,
            size: 18,
            color: context.scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
