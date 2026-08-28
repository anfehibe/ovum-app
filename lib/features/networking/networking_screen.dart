import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers/meetings_provider.dart';
import '../widgets/meeting_card.dart';

class NetworkingScreen extends ConsumerWidget {
  const NetworkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(meetingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navNetworking)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const ErrorView(),
        data: (meetings) => _content(context, ref, meetings),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, List<Meeting> meetings) {
    final counts = ref.watch(meetingCountsProvider);
    final received = meetings.where((m) => m.incoming).toList();
    final sent = meetings.where((m) => !m.incoming).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _actions(context),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatTile(label: 'Recibidas', value: counts.received, color: context.scheme.primary),
            const SizedBox(width: 10),
            _StatTile(label: 'Confirmadas', value: counts.confirmed, color: context.ovum.success),
            const SizedBox(width: 10),
            _StatTile(label: 'Pendientes', value: counts.pending, color: context.ovum.warning),
          ],
        ),
        const SizedBox(height: 24),
        Text('Solicitudes recibidas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (received.isEmpty)
          _emptyHint(context, 'No tienes solicitudes recibidas')
        else
          for (final m in received)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MeetingCard(
                meeting: m,
                onAccept: () => ref.read(meetingsProvider.notifier).setStatus(m.id, MeetingStatus.confirmed),
                onDecline: () => ref.read(meetingsProvider.notifier).setStatus(m.id, MeetingStatus.declined),
              ),
            ),
        const SizedBox(height: 24),
        Text('Enviadas por ti', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (sent.isEmpty)
          _emptyHint(context, 'Aún no has enviado solicitudes')
        else
          for (final m in sent)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MeetingCard(meeting: m),
            ),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: PhosphorIconsRegular.usersThree,
            label: 'Ver asistentes',
            onTap: () => context.push(R.attendees),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: PhosphorIconsRegular.chatsCircle,
            label: 'Mis chats',
            onTap: () => context.push(R.chats),
          ),
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
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: scheme.onPrimaryContainer),
              const SizedBox(height: 8),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
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
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w800)),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
