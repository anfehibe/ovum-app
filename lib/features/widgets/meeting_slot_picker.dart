import 'package:flutter/material.dart';

import '../../core/constants/ovum_event.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/meeting_slots.dart';

/// Rueda para elegir la hora de inicio de una reunión.
///
/// Solo ofrece la rejilla de [meetingSlots]; los slots que el usuario ya tiene
/// ocupados salen tachados y con "Listo" deshabilitado. A diferencia del
/// equivalente en FELABAN, debajo de la rueda se explica **por qué** no se puede
/// confirmar, para que el slot bloqueado no sea un callejón sin salida.
///
/// Devuelve el slot elegido, o `null` si se canceló.
Future<MeetingSlot?> showMeetingTimePicker(
  BuildContext context, {
  required List<MeetingSlot> slots,
  required Map<MeetingSlot, SlotState> states,
  required int durationMinutes,
  MeetingSlot? initial,
}) {
  if (slots.isEmpty) return Future.value();

  // Arranca donde estaba, si sigue siendo válido; si no, en la primera hora
  // libre, para no abrir sobre un slot que no se puede confirmar.
  var index = slots.indexWhere((s) => slotFits(s, durationMinutes, states));
  if (index < 0) index = 0;
  if (initial != null && slotFits(initial, durationMinutes, states)) {
    final at = slots.indexOf(initial);
    if (at >= 0) index = at;
  }

  return showModalBottomSheet<MeetingSlot>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MeetingTimeSheet(
      slots: slots,
      states: states,
      durationMinutes: durationMinutes,
      initialIndex: index,
    ),
  );
}

class _MeetingTimeSheet extends StatefulWidget {
  const _MeetingTimeSheet({
    required this.slots,
    required this.states,
    required this.durationMinutes,
    required this.initialIndex,
  });

  final List<MeetingSlot> slots;
  final Map<MeetingSlot, SlotState> states;
  final int durationMinutes;
  final int initialIndex;

  @override
  State<_MeetingTimeSheet> createState() => _MeetingTimeSheetState();
}

class _MeetingTimeSheetState extends State<_MeetingTimeSheet> {
  static const double _itemExtent = 48;

  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _fits(MeetingSlot slot) =>
      slotFits(slot, widget.durationMinutes, widget.states);

  /// Qué decir debajo de la rueda sobre el slot centrado.
  (String, bool) _caption(MeetingSlot slot) {
    if (slot.minuteOfDay + widget.durationMinutes > MeetingHours.closingMinute) {
      final closing = const MeetingSlot(MeetingHours.closingMinute).label;
      return ('Se pasa de las $closing.', true);
    }
    if (widget.states[slot] == SlotState.taken) {
      return ('Ya tienes una reunión a esa hora.', true);
    }
    if (!_fits(slot)) {
      return (
        'Con ${widget.durationMinutes}′ también necesitas libre la media hora '
            'siguiente.',
        true,
      );
    }
    final end = endLabel(slot, widget.durationMinutes);
    if (widget.states[slot] == SlotState.tentative) {
      return ('Termina a las $end · tienes una solicitud sin responder a esa hora.', true);
    }
    return ('Termina a las $end.', false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final slot = widget.slots[_current];
    final fits = _fits(slot);
    final (caption, isWarning) = _caption(slot);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                Text(
                  'Hora de inicio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: fits ? () => Navigator.pop(context, slot) : null,
                  child: const Text('Listo'),
                ),
              ],
            ),
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: _itemExtent,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.20),
                      ),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: _controller,
                    itemExtent: _itemExtent,
                    perspective: 0.003,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (i) => setState(() => _current = i),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.slots.length,
                      builder: (_, i) => _item(widget.slots[i], i == _current),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isWarning ? context.ovum.warning : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(MeetingSlot slot, bool selected) {
    final scheme = context.scheme;
    final fits = _fits(slot);

    final Color color;
    if (!fits) {
      color = scheme.onSurfaceVariant.withValues(alpha: 0.5);
    } else if (selected) {
      color = scheme.primary;
    } else if (widget.states[slot] == SlotState.tentative) {
      color = context.ovum.warning;
    } else {
      color = scheme.onSurface;
    }

    return Center(
      child: Text(
        slot.label,
        style: TextStyle(
          fontSize: selected ? 20 : 16,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: color,
          decoration: fits ? null : TextDecoration.lineThrough,
          decorationColor: color,
        ),
      ),
    );
  }
}
