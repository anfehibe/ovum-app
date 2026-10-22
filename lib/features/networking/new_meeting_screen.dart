import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/ovum_event.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_ext.dart';
import '../../core/utils/meeting_slots.dart';
import '../../data/models/networking_meeting.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/states.dart';
import '../../data/providers/content_providers.dart';
import '../../data/providers/networking_provider.dart';
import '../widgets/meeting_card.dart' show meetingChangeErrorText;
import '../widgets/meeting_slot_picker.dart';

/// Solicitud de reunión a otro asistente, o edición de una que ya envié
/// ([editing]).
///
/// El API solo acepta `mensaje`, `fecha`, `hora_inicio` y `hora_fin` — **no hay
/// asunto ni lugar**. Todos son opcionales del lado servidor, y tampoco valida
/// las horas: la rejilla de [MeetingHours] y la ocupación de la agenda propia
/// solo existen aquí. La nota (`mensaje`) depende de `AppConfig.userContent` y
/// vacía no se envía.
///
/// **Al editar** se precarga el horario actual y la reunión deja de ocupar su
/// propio hueco. Si estaba confirmada y cambia la hora, el backend la devuelve a
/// pendiente y libera la mesa (ver `docs/API-PENDIENTES.md` §A6).
class NewMeetingScreen extends ConsumerStatefulWidget {
  const NewMeetingScreen({super.key, required this.attendeeId, this.editing});

  final String attendeeId;

  /// La reunión que se está editando, o `null` para una solicitud nueva.
  final NetworkingMeeting? editing;

  @override
  ConsumerState<NewMeetingScreen> createState() => _NewMeetingScreenState();
}

/// Ruta de edición: busca la reunión en el listado y abre [NewMeetingScreen] en
/// modo edición. Solo se llega desde su tarjeta, así que el listado ya está
/// cargado; si no aparece es que dejó de existir (o la canceló el otro).
class EditMeetingScreen extends ConsumerWidget {
  const EditMeetingScreen({super.key, required this.meetingId});

  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkingMeetingsProvider);
    final meeting = ref
        .watch(overlaidMeetingsProvider)
        .where((m) => m.id == meetingId)
        .firstOrNull;
    if (meeting != null && meeting.canEdit) {
      return NewMeetingScreen(
        attendeeId: meeting.counterpart.id,
        editing: meeting,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.newMeetingEditTitle)),
      body: async.isLoading && !async.hasValue
          ? const LoadingView()
          : EmptyState(
              icon: PhosphorIconsRegular.calendarX,
              message: context.l10n.newMeetingCannotEdit,
            ),
    );
  }
}

class _NewMeetingScreenState extends ConsumerState<NewMeetingScreen> {
  final _messageCtrl = TextEditingController();

  late DateTime _date = OvumEvent.agendaDays.first;
  MeetingSlot? _slot;
  int _durationMin = MeetingHours.defaultDuration;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final m = widget.editing;
    if (m == null) return;
    final day = m.date;
    if (day != null) {
      for (final d in OvumEvent.agendaDays) {
        if (d.sameDay(day)) _date = d;
      }
    }
    final start = m.startTime;
    _slot = start == null ? null : slotFromLabel(start);
    final span = minutesBetween(m.startTime, m.endTime);
    if (span != null && MeetingHours.durations.contains(span)) {
      _durationMin = span;
    }
    if (AppConfig.userContent) {
      _messageCtrl.text = m.message;
      // Solo para reevaluar "Guardar cambios" al escribir.
      _messageCtrl.addListener(_onMessageChanged);
    }
  }

  @override
  void dispose() {
    _messageCtrl.removeListener(_onMessageChanged);
    _messageCtrl.dispose();
    super.dispose();
  }

  void _onMessageChanged() => setState(() {});

  /// El horario elegido difiere del que tenía la reunión que se edita.
  bool get _scheduleChanged {
    final m = widget.editing;
    final slot = _slot;
    if (m == null || slot == null) return true;
    final sameDay = m.date?.sameDay(_date) ?? false;
    return !sameDay ||
        slot.label != m.startTime ||
        endLabel(slot, _durationMin) != m.endTime;
  }

  /// Hay algo que guardar. Una solicitud nueva siempre lo tiene.
  bool get _hasChanges {
    final m = widget.editing;
    if (m == null) return true;
    return _scheduleChanged ||
        (AppConfig.userContent && _messageCtrl.text.trim() != m.message);
  }

  /// Minutos `[desde, hasta)` que ocupa la reunión que se edita en el día
  /// elegido, o `null` si no aplica. Misma normalización que `slotStates`.
  (int, int)? _editedSpan() {
    final m = widget.editing;
    final day = m?.date;
    if (m == null || day == null || !day.sameDay(_date)) return null;
    final start = minuteOfDayOf(m.startTime);
    if (start == null) return null;
    final span = minutesBetween(m.startTime, m.endTime) ?? 0;
    return (
      start - start % MeetingHours.stepMinutes,
      start + (span > 0 ? span : MeetingHours.stepMinutes),
    );
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
    final service = ref.read(networkingServiceProvider);
    final editing = widget.editing;
    try {
      final String message;
      if (editing == null) {
        message = await service.requestMeeting(
          widget.attendeeId,
          message: _messageCtrl.text.trim(),
          date: apiDate(_date),
          startTime: slot.label,
          endTime: endLabel(slot, _durationMin),
        );
      } else {
        final res = await service.updateMeeting(
          editing.id,
          date: apiDate(_date),
          startTime: slot.label,
          endTime: endLabel(slot, _durationMin),
          // Con la nota oculta no se manda: el backend conserva la que había.
          message: AppConfig.userContent ? _messageCtrl.text.trim() : null,
        );
        message = res.message;
      }
      // Refresca la ocupación: la reunión recién creada (o movida) debe salir
      // tomada en su hora nueva.
      ref.invalidate(networkingMeetingsProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(message)));
      navigator.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (editing != null) {
        // 422 ("ya no se puede editar", "ya pasó") o 404: la lista que trajo
        // hasta aquí está desactualizada.
        if (!e.isForbidden) ref.invalidate(networkingMeetingsProvider);
        messenger.showSnackBar(
          SnackBar(content: Text(meetingChangeErrorText(context.l10n, e))),
        );
      } else {
        // 422 cubre la auto-solicitud; el backend ya manda el texto en español.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              e.isNotFound
                  ? context.l10n.newMeetingAttendeeUnavailable
                  : e.message,
            ),
          ),
        );
      }
      if (e.isForbidden) navigator.pop();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              editing == null
                  ? context.l10n.newMeetingSendError
                  : context.l10n.newMeetingSaveError,
            ),
          ),
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
  ///
  /// Al editar, la reunión no puede ocupar su propio hueco. Un backend con
  /// `exclude` ya no la cuenta; uno sin él sí, y aquí se compensa: se libera mi
  /// agenda en ese tramo y, **solo si estaba confirmada**, también la del otro
  /// (para él solo cuentan las confirmadas; si no, su "ocupado" es de verdad).
  (List<MeetingSlot>, Map<MeetingSlot, SlotState>) _fromServer(
    MeetingAvailability a,
  ) {
    final edited = _editedSpan();
    final editedWasConfirmed = widget.editing?.state == MeetingState.confirmed;
    final slots = <MeetingSlot>[];
    final states = <MeetingSlot, SlotState>{};
    for (final s in a.slots) {
      final slot = slotFromLabel(s.start);
      if (slot == null) continue;
      slots.add(slot);
      final from = slot.minuteOfDay;
      final to = minuteOfDayOf(s.end) ?? from + _durationMin;
      final own = edited != null && from < edited.$2 && to > edited.$1;
      if (s.busyOther == true && !(own && editedWasConfirmed)) {
        states[slot] = SlotState.otherBusy;
      } else if (s.selfState != SlotState.free && !own) {
        states[slot] = s.selfState;
      }
    }
    return (slots, states);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final editing = widget.editing;
    // Al editar ya se tiene la ficha, y su id puede venir vacío (invitación
    // solo por correo): no hay que pedirla.
    final card = editing != null
        ? editing.counterpart
        : ref.watch(networkingAttendeeProvider(widget.attendeeId)).valueOrNull;

    // Rejilla del servidor: es la única que sabe de `horarios`, de mesas y de si
    // el OTRO está ocupado. Ver `availabilityFromJson`.
    final availability = ref.watch(
      meetingAvailabilityProvider((
        date: apiDate(_date),
        userId: widget.attendeeId,
        period: _durationMin,
        exclude: editing?.id,
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
        slotStates(overlaid, _date, excludeMeetingId: editing?.id),
      ),
    };

    // Mientras no haya veredicto no se puede afirmar que algo esté libre.
    final checking = availability.isLoading && !availability.hasValue ||
        (usingFallback && meetingsAsync.isLoading && !meetingsAsync.hasValue);
    final checkFailed = usingFallback && meetingsAsync.hasError && !meetingsAsync.hasValue;
    final noneFree = !slots.any((s) => slotFits(s, _durationMin, states));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing == null
              ? context.l10n.newMeetingRequestTitle
              : context.l10n.newMeetingEditTitle,
        ),
      ),
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
            _label(context, context.l10n.newMeetingTopicLabel),
            TextField(
              controller: _messageCtrl,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.l10n.newMeetingMessageHint,
              ),
            ),
            const SizedBox(height: 8),
          ],
          _label(context, context.l10n.newMeetingProposedDay),
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
                    _label(context, context.l10n.newMeetingStartTime),
                    OutlinedButton.icon(
                      onPressed: checking ? null : () => _pickTime(slots, states),
                      icon: const Icon(PhosphorIconsRegular.clock, size: 18),
                      label: Text(_slot?.label ?? context.l10n.newMeetingChooseTime),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(context, context.l10n.newMeetingDuration),
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
            onPressed: (_sending || _slot == null || checking || !_hasChanges)
                ? null
                : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    editing == null
                        ? PhosphorIconsRegular.handshake
                        : PhosphorIconsRegular.check,
                    size: 18,
                  ),
            label: Text(
              editing == null
                  ? context.l10n.newMeetingSendRequest
                  : context.l10n.newMeetingSaveChanges,
            ),
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
        context.l10n.newMeetingAgendaUnavailable,
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
          line(context.l10n.newMeetingCheckingMeetings, scheme.onSurfaceVariant),
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
            context.l10n.newMeetingCheckFailed,
            context.ovum.warning,
          ),
          TextButton(
            onPressed: () => ref.invalidate(networkingMeetingsProvider),
            child: Text(context.l10n.networkingRetry),
          ),
        ],
      );
    }

    if (noneFree) {
      return line(
        context.l10n.newMeetingNoFreeTime,
        context.ovum.warning,
      );
    }

    final slot = _slot;
    if (slot == null) {
      return line(context.l10n.newMeetingPickStartTime, scheme.onSurfaceVariant);
    }

    final editing = widget.editing;
    final endsAt = endLabel(slot, _durationMin);
    final name = editing == null || editing.counterpart.name.isEmpty
        ? context.l10n.newMeetingOtherPerson
        : editing.counterpart.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(
          editing == null
              ? context.l10n.newMeetingEndsAndRequest(endsAt)
              : context.l10n.newMeetingEndsAndNotify(endsAt),
          scheme.onSurfaceVariant,
        ),
        // Lo que cuesta mover una confirmada: el otro tiene que volver a decir
        // que sí, y la mesa que tenía queda libre para cualquiera.
        if (editing?.state == MeetingState.confirmed && _scheduleChanged) ...[
          const SizedBox(height: 4),
          line(
            context.l10n.newMeetingReconfirm(name),
            context.ovum.warning,
          ),
        ],
        if (states[slot] == SlotState.tentative) ...[
          const SizedBox(height: 4),
          line(
            context.l10n.newMeetingPendingAtTime,
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
