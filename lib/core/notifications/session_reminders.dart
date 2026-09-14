import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/session.dart';
import '../router/route_paths.dart';
import '../utils/date_ext.dart';
import 'notification_service.dart';

/// iOS solo conserva 64 notificaciones pendientes por app; dejamos margen.
const _maxPendientes = 40;

/// Id estable para el recordatorio de una sesión.
///
/// **No se usa `String.hashCode`**: en Dart no está garantizado que sea el mismo
/// entre ejecuciones ni plataformas, y un id que cambia dejaría notificaciones
/// huérfanas imposibles de cancelar. FNV-1a de 32 bits, siempre positivo.
int reminderIdFor(String sessionId) {
  var hash = 0x811c9dc5;
  for (final unit in sessionId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Programa y cancela los recordatorios de las sesiones favoritas.
class SessionReminders {
  const SessionReminders(this._fln);

  final FlutterLocalNotificationsPlugin _fln;

  AndroidFlutterLocalNotificationsPlugin? get _android => _fln
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Momento en que debe sonar el recordatorio de [session].
  ///
  /// Usa [wallClock] —el mismo criterio que el botón de calendario— para que el
  /// aviso coincida con la hora que la agenda muestra en pantalla. Ver la nota
  /// de zona horaria en `date_ext.dart`.
  tz.TZDateTime scheduledAt(Session session, int leadMinutes) {
    final wall = wallClock(session.startDate);
    return tz.TZDateTime(
      tz.local,
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
    ).subtract(Duration(minutes: leadMinutes));
  }

  Future<void> schedule(Session session, {required int leadMinutes}) async {
    final when = scheduledAt(session, leadMinutes);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return; // ya pasó

    // Se evita a propósito declarar SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM: en
    // Android 14 la primera se deniega por defecto y exige justificarla en Play
    // Console, y la segunda está reservada a apps de alarma/calendario. Usamos
    // el modo exacto solo cuando el sistema ya lo permite; si no, inexacto (el
    // aviso puede llegar unos minutos tarde bajo Doze, aceptable para 15 min).
    final exacto = Platform.isAndroid
        ? (await _android?.canScheduleExactNotifications() ?? false)
        : true;

    try {
      await _fln.zonedSchedule(
        id: reminderIdFor(session.id),
        title: 'Empieza en $leadMinutes min',
        body: session.room.isEmpty
            ? session.title
            : '${session.title} · ${session.room}',
        scheduledDate: when,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationService.reminderChannel.id,
            NotificationService.reminderChannel.name,
            channelDescription: NotificationService.reminderChannel.description,
            icon: '@drawable/ic_stat_ovum',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: exacto
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: R.session(session.id),
      );
    } catch (e) {
      debugPrint('No se pudo programar el recordatorio de ${session.id}: $e');
    }
  }

  Future<void> cancel(String sessionId) =>
      _fln.cancel(id: reminderIdFor(sessionId));

  /// Reprograma todo desde cero a partir de las sesiones favoritas.
  ///
  /// Cancelar y volver a programar es idempotente y barato (decenas de sesiones),
  /// y evita llevar un diff del estado anterior.
  Future<void> rescheduleAll(
    List<Session> favoritas, {
    required int leadMinutes,
  }) async {
    await cancelAll();
    final ahora = DateTime.now().toUtc();
    final futuras = favoritas
        .where((s) => s.startDate.toUtc().isAfter(ahora))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    for (final s in futuras.take(_maxPendientes)) {
      await schedule(s, leadMinutes: leadMinutes);
    }
  }

  Future<void> cancelAll() async {
    for (final p in await _fln.pendingNotificationRequests()) {
      await _fln.cancel(id: p.id);
    }
  }
}
