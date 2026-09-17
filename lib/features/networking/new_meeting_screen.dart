import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/ovum_event.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/networking_provider.dart';

/// Solicitud de reunión a otro asistente.
///
/// El API solo acepta `mensaje`, `fecha`, `hora_inicio` y `hora_fin` — **no hay
/// asunto ni lugar**, así que el mensaje es el campo principal. Todos son
/// opcionales del lado servidor.
class NewMeetingScreen extends ConsumerStatefulWidget {
  const NewMeetingScreen({super.key, required this.attendeeId});

  final String attendeeId;

  @override
  ConsumerState<NewMeetingScreen> createState() => _NewMeetingScreenState();
}

class _NewMeetingScreenState extends ConsumerState<NewMeetingScreen> {
  final _messageCtrl = TextEditingController();

  late DateTime _date = OvumEvent.agendaDays.first;
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  int _durationMin = 30;
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get _endTime {
    final total = _start.hour * 60 + _start.minute + _durationMin;
    final h = (total ~/ 60) % 24;
    final m = total % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String get _dateString =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final message = await ref
          .read(networkingServiceProvider)
          .requestMeeting(
            widget.attendeeId,
            message: _messageCtrl.text.trim(),
            date: _dateString,
            startTime: _fmt(_start),
            endTime: _endTime,
          );
      ref.invalidate(networkingMeetingsProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(message)));
      navigator.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      // 422 cubre la auto-solicitud; el backend ya manda el texto en español.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.isNotFound
                ? 'Ese asistente ya no está disponible para reuniones.'
                : e.message,
          ),
        ),
      );
      if (e.isForbidden) navigator.pop();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la solicitud.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final card = ref.watch(networkingAttendeeProvider(widget.attendeeId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar reunión')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (card != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  InitialsAvatar(name: card.name, imageUrl: card.photoUrl, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.name, style: Theme.of(context).textTheme.titleSmall),
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
                ],
              ),
            ),
          const SizedBox(height: 20),
          _label(context, '¿De qué te gustaría hablar?'),
          TextField(
            controller: _messageCtrl,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Cuéntale brevemente el motivo de la reunión',
            ),
          ),
          const SizedBox(height: 8),
          _label(context, 'Día propuesto'),
          Wrap(
            spacing: 8,
            children: [
              for (final d in OvumEvent.agendaDays)
                ChoiceChip(
                  label: Text('${d.dayNameShort} ${d.dayNumber}'),
                  selected: _date.sameDay(d),
                  onSelected: (_) => setState(() => _date = d),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(context, 'Hora de inicio'),
                    OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(PhosphorIconsRegular.clock, size: 18),
                      label: Text(_fmt(_start)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(context, 'Duración'),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 15, label: Text('15′')),
                        ButtonSegment(value: 30, label: Text('30′')),
                        ButtonSegment(value: 60, label: Text('60′')),
                      ],
                      selected: {_durationMin},
                      onSelectionChanged: (s) => setState(() => _durationMin = s.first),
                      showSelectedIcon: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Termina a las $_endTime · le llegará la solicitud para aceptarla o rechazarla.',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(PhosphorIconsRegular.handshake, size: 18),
            label: const Text('Enviar solicitud'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
