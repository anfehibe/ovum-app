import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../data/models/networking_meeting.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/networking_provider.dart';
import '../../data/providers/user_provider.dart';

/// Texto de un error al **editar o cancelar** una reunión. El backend manda los
/// 403/422 en español ("ya pasó", "ya no se puede editar"…); el 404 llega vacío.
String meetingChangeErrorText(ApiException e) {
  if (e.isNotFound) return 'Esa reunión ya no existe.';
  return e.message.isEmpty ? 'No se pudo completar la acción.' : e.message;
}

/// Tarjeta de una solicitud de reunión.
///
/// Si es **entrante y pendiente**, deja aceptarla o rechazarla. El backend solo
/// admite responder mientras siga pendiente (si no, 422), y al aceptar asigna la
/// mesa él mismo; por eso no hay actualización optimista: la respuesta trae datos
/// que el cliente no puede adivinar.
///
/// Si es **mía**, deja editarla y cancelarla mientras siga viva; si es entrante y
/// ya la acepté, solo cancelarla. Una cancelada se queda en la lista, atenuada.
class MeetingCard extends ConsumerStatefulWidget {
  const MeetingCard({super.key, required this.meeting});

  final NetworkingMeeting meeting;

  @override
  ConsumerState<MeetingCard> createState() => _MeetingCardState();
}

class _MeetingCardState extends ConsumerState<MeetingCard> {
  bool _busy = false;

  NetworkingMeeting get _m => widget.meeting;

  String get _counterpartName =>
      _m.counterpart.name.isEmpty ? 'la otra persona' : _m.counterpart.name;

  /// Llamada al backend con el manejo común de la tarjeta: un solo `_busy`, el
  /// messenger capturado antes del primer await y la misma lectura de errores.
  /// [action] devuelve el texto del aviso de éxito.
  Future<void> _run(
    Future<String> Function() action, {
    required String failure,
    required String Function(ApiException e) errorText,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final text = await action();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized || e.isForbidden) {
        // 403 cubre dos causas (networking cerrado o la reunión no es tuya);
        // el texto del backend las distingue. Re-sondear la compuerta es barato
        // y se autocorrige si en realidad seguía abierta.
        ref.invalidate(networkingAccessProvider);
      } else {
        // 422 ("ya fue respondida", "ya pasó"…) o 404: el listado está
        // desactualizado.
        ref.invalidate(networkingMeetingsProvider);
      }
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(failure)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    if (!accept &&
        !await _confirm(
          title: '¿Rechazar esta solicitud?',
          body: 'Se le avisará por correo a quien la envió.',
          dismiss: 'Cancelar',
          confirm: 'Rechazar',
        )) {
      return;
    }
    if (!mounted) return;
    await _run(
      () async {
        final res = await ref
            .read(networkingServiceProvider)
            .respondMeeting(_m.id, accept: accept);
        ref.read(meetingResponsesProvider.notifier).record(res.outcome);
        ref.invalidate(networkingMeetingsProvider);
        final donde = accept
            ? (outcomePlaceLabel(res.outcome) ??
                  'La mesa la asignará el organizador.')
            : null;
        return [res.message, ?donde].join(' ');
      },
      failure: 'No se pudo responder la reunión.',
      errorText: (e) => e.isNotFound ? 'Esa reunión ya no existe.' : e.message,
    );
  }

  Future<void> _cancel() async {
    if (_busy) return;
    // Solo la confirmada avisa a la otra persona (push y correo); la pendiente
    // simplemente deja de poder aceptarse.
    final ok = await _confirm(
      title: '¿Cancelar esta reunión?',
      body: _m.state == MeetingState.confirmed
          ? 'Le avisaremos a $_counterpartName. Si tenía mesa asignada, se '
                'liberará.'
          : '$_counterpartName ya no podrá aceptarla.',
      dismiss: 'Volver',
      confirm: 'Cancelar reunión',
    );
    if (!ok || !mounted) return;
    await _run(
      () async {
        final res = await ref
            .read(networkingServiceProvider)
            .cancelMeeting(_m.id);
        ref.read(meetingResponsesProvider.notifier).record(res.outcome);
        ref.invalidate(networkingMeetingsProvider);
        return res.message;
      },
      failure: 'No se pudo cancelar la reunión.',
      errorText: meetingChangeErrorText,
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String dismiss,
    required String confirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(dismiss),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirm),
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
    final today = DateTime.now();
    final puedeResponder = _m.isIncoming && _m.state == MeetingState.pending;
    final puedeEditar = AppConfig.meetingEdits && _m.canEditOn(today);
    final puedeCancelar = AppConfig.meetingEdits && _m.canCancelOn(today);
    final cancelada = _m.state == MeetingState.deleted;
    final cancellation = _m.cancellation;
    // El backend dice "Eliminada" (es la misma etiqueta que deja el borrado de
    // cuenta); para quien la ve en su lista, lo que pasó es que se canceló.
    final label = cancelada ? 'Cancelada' : _m.stateLabel;

    return Opacity(
      opacity: cancelada ? 0.7 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(
                  name: card.name,
                  imageUrl: card.photoUrl,
                  size: 42,
                ),
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
                if (label.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    // La etiqueta la manda el backend: es dueño de esa copy
                    // (salvo "Cancelada", ver arriba).
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            // Nota y respuesta son texto libre del otro asistente (pueden llegar
            // desde la web): dependen de `AppConfig.userContent`.
            if (AppConfig.userContent && _m.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_m.message, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (AppConfig.userContent && _m.reply.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Respuesta: ${_m.reply}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            _row(context, PhosphorIconsRegular.calendarBlank, _schedule()),
            if (_m.state == MeetingState.confirmed) ...[
              const SizedBox(height: 2),
              // Sin lugar asignado todavía, "por asignar" es lo honesto: la app
              // genuinamente no lo sabe.
              _row(
                context,
                PhosphorIconsRegular.mapPin,
                _m.placeLabel ?? 'Mesa por asignar',
              ),
            ],
            // Solo viene si estaba confirmada: ahí cualquiera de los dos pudo
            // cancelarla, y saber quién importa.
            if (cancelada && cancellation != null) ...[
              const SizedBox(height: 2),
              _row(
                context,
                PhosphorIconsRegular.calendarX,
                cancellationLabel(
                  cancellation,
                  myId: ref.watch(sessionUserIdProvider),
                ),
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
                          ? const _Spinner()
                          : const Icon(PhosphorIconsRegular.check, size: 16),
                      label: const Text('Aceptar'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _respond(false),
                      icon: const Icon(PhosphorIconsRegular.x, size: 16),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (puedeEditar || puedeCancelar) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (puedeEditar)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => context.push(R.editMeetingFor(_m.id)),
                        icon: const Icon(
                          PhosphorIconsRegular.pencilSimple,
                          size: 16,
                        ),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  if (puedeEditar && puedeCancelar) const SizedBox(width: 10),
                  if (puedeCancelar)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _busy ? null : _cancel,
                        icon: _busy
                            ? const _Spinner()
                            : const Icon(
                                PhosphorIconsRegular.calendarX,
                                size: 16,
                              ),
                        label: const Text('Cancelar reunión'),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
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
    MeetingState.declined => context.scheme.error,
    MeetingState.rescheduled => context.scheme.tertiary,
    MeetingState.deleted ||
    MeetingState.expired ||
    MeetingState.unknown => context.scheme.onSurfaceVariant,
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
