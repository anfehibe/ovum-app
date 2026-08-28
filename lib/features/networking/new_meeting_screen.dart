import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/constants/ovum_event.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../data/models/models.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/meetings_provider.dart';

class NewMeetingScreen extends ConsumerStatefulWidget {
  const NewMeetingScreen({super.key, required this.attendeeId});
  final String attendeeId;

  @override
  ConsumerState<NewMeetingScreen> createState() => _NewMeetingScreenState();
}

class _NewMeetingScreenState extends ConsumerState<NewMeetingScreen> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _placeCtrl = TextEditingController(text: 'Sala de networking');

  late DateTime _date = OvumEvent.agendaDays.first;
  TimeOfDay _start = const TimeOfDay(hour: 10, minute: 0);
  int _durationMin = 30;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    _placeCtrl.dispose();
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  void _submit() {
    if (_subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un asunto para la reunión')),
      );
      return;
    }
    ref.read(meetingsProvider.notifier).add(
          Meeting(
            id: 'm${DateTime.now().microsecondsSinceEpoch}',
            attendeeId: widget.attendeeId,
            subject: _subjectCtrl.text.trim(),
            message: _messageCtrl.text.trim(),
            place: _placeCtrl.text.trim(),
            date: _date,
            startTime: _fmt(_start),
            endTime: _endTime,
            status: MeetingStatus.pending,
            incoming: false,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud de reunión enviada')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final attendee = ref.watch(attendeeByIdProvider(widget.attendeeId));
    final scheme = context.scheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar reunión')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (attendee != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  InitialsAvatar(name: attendee.name, imageUrl: attendee.photoUrl, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(attendee.name, style: Theme.of(context).textTheme.titleSmall),
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
                ],
              ),
            ),
          const SizedBox(height: 20),
          _label(context, 'Asunto'),
          TextField(controller: _subjectCtrl, decoration: const InputDecoration(hintText: 'Tema de la reunión')),
          const SizedBox(height: 18),
          _label(context, 'Día'),
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
          Text('Termina a las $_endTime',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          _label(context, 'Lugar'),
          TextField(controller: _placeCtrl, decoration: const InputDecoration(hintText: 'Lugar de la reunión')),
          const SizedBox(height: 18),
          _label(context, 'Mensaje (opcional)'),
          TextField(
            controller: _messageCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Cuéntale de qué te gustaría hablar'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(PhosphorIconsRegular.handshake, size: 18),
            label: const Text('Enviar solicitud'),
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
