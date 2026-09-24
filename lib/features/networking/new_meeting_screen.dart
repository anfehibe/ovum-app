import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/ovum_event.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/utils/meeting_slots.dart';
import '../../data/models/networking_meeting.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/networking_provider.dart';
import '../widgets/meeting_slot_picker.dart';

/// Solicitud de reunión a otro asistente.
///
/// El API solo acepta `mensaje`, `fecha`, `hora_inicio` y `hora_fin` — **no hay
/// asunto ni lugar**. Todos son opcionales del lado servidor, y tampoco valida
/// las horas: la rejilla de [MeetingHours] y la ocupación de la agenda propia
/// solo existen aquí. La nota (`mensaje`) va oculta mientras
/// `AppConfig.userContent` esté apagado: es texto libre que lee el otro
/// asistente (App Store 1.2), y vacía no se envía.
class NewMeetingScreen extends ConsumerStatefulWidget {
  const NewMeetingScreen({super.key, required this.attendeeId});

  final String attendeeId;

  @override
  ConsumerState<NewMeetingScreen> createState() => _NewMeetingScreenState();
}

class _NewMeetingScreenState extends ConsumerState<NewMeetingScreen> {
  final _messageCtrl = TextEditingController();

  late DateTime _date = OvumEvent.agendaDays.first;
  MeetingSlot? _slot;
  int _durationMin = MeetingHours.defaultDuration;
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(
    List<MeetingSlot> slots,
    Map<MeetingSlot, SlotState> states,
  ) async {
    final picked = await showMeetingTimePicker(
      context,
      slots: slots,
      states: states,
      durationMinutes: _durationMin,
      initial: _slot,
    );
    if (picked != null) setState(() => _slot = picked);
  }

  Future<void> _submit() async {
    final slot = _slot;
    if (_sending || slot == null) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final message = await ref
          .read(networkingServiceProvider)
          .requestMeeting(
            widget.attendeeId,
            message: _messageCtrl.text.trim(),
            date: apiDate(_date),
            startTime: slot.label,
            endTime: endLabel(slot, _durationMin),
          );
      // Refresca la ocupación: la reunión recién creada debe salir tomada.
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

  /// Traduce la respuesta del servidor al par `(slots, states)` que ya consumen
  /// el picker y `slotFits`, para no cambiar su API por esto.
  ///
  /// El mapa solo lleva lo que **no** está libre: `slotStates` se comporta igual
  /// y los consumidores hacen `states[slot] ?? free`.
  (List<MeetingSlot>, Map<MeetingSlot, SlotState>) _fromServer(
    MeetingAvailability a,
  ) {
    final slots = <MeetingSlot>[];
    final states = <MeetingSlot, SlotState>{};
    for (final s in a.slots) {
      final slot = slotFromLabel(s.start);
      if (slot == null) continue;
      slots.add(slot);
      if (s.busyOther == true) {
        states[slot] = SlotState.otherBusy;
      } else if (s.selfState != SlotState.free) {
        states[slot] = s.selfState;
      }
    }
    return (slots, states);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final card = ref
        .watch(networkingAttendeeProvider(widget.attendeeId))
        .valueOrNull;

    // Rejilla del servidor: es la única que sabe de `horarios`, de mesas y de si
    // el OTRO está ocupado. Ver `availabilityFromJson`.
    final availability = ref.watch(
      meetingAvailabilityProvider((
        date: apiDate(_date),
        userId: widget.attendeeId,
        period: _durationMin,
      )),
    );

    // Respaldo: si el endpoint falla (sin red, 404 en un backend viejo), se sigue
    // pudiendo pedir la reunión con la rejilla local en vez de dejar la pantalla
    // inservible. Pierde la ocupación del otro, y por eso se avisa.
    final overlaid = ref.watch(overlaidMeetingsProvider);
    final meetingsAsync = ref.watch(networkingMeetingsProvider);
    final usingFallback = availability.hasError;

    final (slots, states) = switch (availability.valueOrNull) {
      final a? when a.slots.isNotEmpty => _fromServer(a),
      _ => (
        meetingSlots(durationMinutes: _durationMin),
        slotStates(overlaid, _date),
      ),
    };

    // Mientras no haya veredicto no se puede afirmar que algo esté libre.
    final checking = availability.isLoading && !availability.hasValue ||
        (usingFallback && meetingsAsync.isLoading && !meetingsAsync.hasValue);
    final checkFailed = usingFallback && meetingsAsync.hasError && !meetingsAsync.hasValue;
    final noneFree = !slots.any((s) => slotFits(s, _durationMin, states));

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
          if (AppConfig.userContent) ...[
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
          ],
          _label(context, 'Día propuesto'),
          Wrap(
            spacing: 8,
            children: [
              for (final d in OvumEvent.agendaDays)
                ChoiceChip(
                  label: Text('${d.dayNameShort} ${d.dayNumber}'),
                  selected: _date.sameDay(d),
                  // La ocupación es por día: la hora elegida el 11 no significa
                  // nada el 12.
                  onSelected: (_) => setState(() {
                    _date = d;
                    _slot = null;
                  }),
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
                      onPressed: checking ? null : () => _pickTime(slots, states),
                      icon: const Icon(PhosphorIconsRegular.clock, size: 18),
                      label: Text(_slot?.label ?? 'Elegir hora'),
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
                        ButtonSegment(value: 30, label: Text('30′')),
                        ButtonSegment(value: 60, label: Text('60′')),
                      ],
                      selected: {_durationMin},
                      onSelectionChanged: (s) => setState(() {
                        _durationMin = s.first;
                        // Lo que cabía con 30′ puede no caber con 60′.
                        final slot = _slot;
                        if (slot != null && !slotFits(slot, _durationMin, states)) {
                          _slot = null;
                        }
                      }),
                      showSelectedIcon: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _status(
            context,
            checking: checking,
            failed: checkFailed,
            noneFree: noneFree,
            states: states,
            fallback: usingFallback,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_sending || _slot == null || checking) ? null : _submit,
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

  /// Línea bajo los selectores: estado de la comprobación de agenda, o el
  /// resumen de la hora elegida.
  Widget _status(
    BuildContext context, {
    required bool checking,
    required bool failed,
    required bool noneFree,
    required Map<MeetingSlot, SlotState> states,
    required bool fallback,
  }) {
    final scheme = context.scheme;
    final style = Theme.of(context).textTheme.labelMedium;
    Widget line(String text, Color color) =>
        Text(text, style: style?.copyWith(color: color));

    // Sin la rejilla del servidor no se sabe si el otro está libre: decirlo es
    // mejor que ofrecer horas con falsa confianza.
    if (fallback && !checking) {
      return line(
        'No se pudo consultar la agenda del congreso: se muestran horas '
        'orientativas y puede que la otra persona no esté libre.',
        context.ovum.warning,
      );
    }

    if (checking) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          line('Comprobando tus reuniones…', scheme.onSurfaceVariant),
        ],
      );
    }

    // Se falla abierto: un fallo de red no puede bloquear la acción principal,
    // y el servidor no valida las horas de todas formas.
    if (failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(
            'No pudimos comprobar tus reuniones; revisa que no se te cruce.',
            context.ovum.warning,
          ),
          TextButton(
            onPressed: () => ref.invalidate(networkingMeetingsProvider),
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    if (noneFree) {
      return line(
        'No te queda ninguna hora libre ese día. Prueba con otro.',
        context.ovum.warning,
      );
    }

    final slot = _slot;
    if (slot == null) {
      return line('Elige una hora de inicio.', scheme.onSurfaceVariant);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(
          'Termina a las ${endLabel(slot, _durationMin)} · le llegará la '
              'solicitud para aceptarla o rechazarla.',
          scheme.onSurfaceVariant,
        ),
        if (states[slot] == SlotState.tentative) ...[
          const SizedBox(height: 4),
          line(
            'Tienes una solicitud sin responder a esa hora.',
            context.ovum.warning,
          ),
        ],
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
