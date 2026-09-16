import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../data/models/networking_meeting.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/networking_provider.dart';

/// Tarjeta de una solicitud de reunión.
///
/// Si es **entrante y pendiente**, deja aceptarla o rechazarla. El backend solo
/// admite responder mientras siga pendiente (si no, 422), y al aceptar asigna la
/// mesa él mismo; por eso no hay actualización optimista: la respuesta trae datos
/// que el cliente no puede adivinar.
class MeetingCard extends ConsumerStatefulWidget {
  const MeetingCard({super.key, required this.meeting});

  final NetworkingMeeting meeting;

  @override
  ConsumerState<MeetingCard> createState() => _MeetingCardState();
}

class _MeetingCardState extends ConsumerState<MeetingCard> {
  bool _busy = false;

  NetworkingMeeting get _m => widget.meeting;

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    // Se captura antes del diálogo para no usar el context tras un await.
    final messenger = ScaffoldMessenger.of(context);
    if (!accept && !await _confirmReject()) return;

    setState(() => _busy = true);
    try {
      final res = await ref
          .read(networkingServiceProvider)
          .respondMeeting(_m.id, accept: accept);
      ref.read(meetingResponsesProvider.notifier).record(res.outcome);
      ref.invalidate(networkingMeetingsProvider);
      if (!mounted) return;
      final donde = accept
          ? (outcomePlaceLabel(res.outcome) ?? 'La mesa la asignará el organizador.')
          : null;
      messenger.showSnackBar(
        SnackBar(content: Text([res.message, ?donde].join(' '))),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized || e.isForbidden) {
        // 403 cubre dos causas (networking cerrado o no eres el destinatario);
        // el texto del backend las distingue. Re-sondear la compuerta es barato
        // y se autocorrige si en realidad seguía abierta.
        ref.invalidate(networkingAccessProvider);
      } else {
        // 422 ("ya fue respondida") o 404: el listado está desactualizado.
        ref.invalidate(networkingMeetingsProvider);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.isNotFound ? 'Esa reunión ya no existe.' : e.message),
        ),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo responder la reunión.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmReject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Rechazar esta solicitud?'),
        content: const Text('Se le avisará por correo a quien la envió.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final card = _m.counterpart;
    final color = _stateColor(context);
    final puedeResponder = _m.isIncoming && _m.state == MeetingState.pending;

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
              InitialsAvatar(name: card.name, imageUrl: card.photoUrl, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name.isEmpty ? 'Asistente' : card.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (card.subtitle.isNotEmpty)
                      Text(
                        card.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (_m.stateLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  // La etiqueta la manda el backend: es dueño de esa copy.
                  child: Text(
                    _m.stateLabel,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          if (_m.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_m.message, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (_m.reply.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Respuesta: ${_m.reply}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 10),
          _row(context, PhosphorIconsRegular.calendarBlank, _schedule()),
          if (_m.state == MeetingState.confirmed) ...[
            const SizedBox(height: 2),
            // Si el listado no trae lugar/mesa (hoy no los devuelve), "por asignar"
            // es lo honesto: la app genuinamente no lo sabe.
            _row(
              context,
              PhosphorIconsRegular.mapPin,
              _m.placeLabel ?? 'Mesa por asignar',
            ),
          ],
          if (puedeResponder) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _respond(true),
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(PhosphorIconsRegular.check, size: 16),
                    label: const Text('Aceptar'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _respond(false),
                    icon: const Icon(PhosphorIconsRegular.x, size: 16),
                    label: const Text('Rechazar'),
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

  String _schedule() {
    if (!_m.hasSchedule) return 'Sin horario propuesto';
    final day = _m.date?.monthDay;
    final hours = [?_m.startTime, ?_m.endTime].join(' – ');
    return [?day, if (hours.isNotEmpty) hours].join(' · ');
  }

  Color _stateColor(BuildContext context) => switch (_m.state) {
    MeetingState.confirmed => context.ovum.success,
    MeetingState.pending => context.ovum.warning,
    MeetingState.declined || MeetingState.deleted => context.scheme.error,
    MeetingState.rescheduled => context.scheme.tertiary,
    MeetingState.expired || MeetingState.unknown => context.scheme.onSurfaceVariant,
  };

  Widget _row(BuildContext context, IconData icon, String text) {
    final scheme = context.scheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
