import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ovum_event.dart';
import '../../core/utils/event_clock.dart';
import '../../core/utils/iterable_ext.dart';
import '../models/bus_route.dart';
import '../repositories/transport_cache.dart';
import 'content_providers.dart';
import 'preferences.dart';

/// Rutas de transporte y de dónde salieron.
@immutable
class TransportData {
  const TransportData({
    required this.routes,
    required this.savedAt,
    this.offline = false,
  });

  final List<BusRoute> routes;

  /// Instante (absoluto) en que se obtuvieron del servidor.
  final DateTime savedAt;

  /// `true` si el servidor no respondió y esto es la copia guardada.
  final bool offline;
}

final transportCacheProvider = Provider<TransportCache>(
  (ref) => TransportCache(ref.watch(sharedPreferencesProvider)),
);

/// Rutas de bus del congreso (`GET /events/{id}/transport/routes`).
///
/// Si el servidor no responde, sirve la última copia buena guardada en el
/// teléfono (marcada como `offline`) en vez de un error: en el lobby del hotel,
/// con el wifi saturado, un horario de hace unas horas vale mucho más que una
/// pantalla de error. Solo falla si nunca se pudo cargar nada.
final busRoutesProvider = FutureProvider<TransportData>((ref) async {
  final cache = ref.watch(transportCacheProvider);
  try {
    final routes = await ref.watch(ovumRepositoryProvider).getBusRoutes();
    final now = DateTime.now();
    await cache.save(routes, now);
    return TransportData(routes: routes, savedAt: now);
  } catch (_) {
    final saved = cache.load();
    if (saved == null) rethrow;
    return TransportData(
      routes: saved.routes,
      savedAt: saved.savedAt,
      offline: true,
    );
  }
});

/// Antigüedad a partir de la cual los horarios se vuelven a pedir al volver a
/// la app o al entrar en Transporte.
const transportStaleAfter = Duration(minutes: 5);

/// Vuelve a pedir las rutas si lo que hay es viejo, vino de la caché o falló.
///
/// Un `FutureProvider` sin autoDispose conserva su primer resultado durante toda
/// la vida del proceso: sin esto, un cambio de horario hecho por el organizador
/// a media mañana no llegaba a quien abrió la app a primera hora.
void refreshTransportIfStale(WidgetRef ref) {
  final current = ref.read(busRoutesProvider);
  if (current.isLoading) return;
  final data = current.valueOrNull;
  final stale =
      data == null ||
      data.offline ||
      current.hasError ||
      DateTime.now().difference(data.savedAt) > transportStaleAfter;
  if (stale) ref.invalidate(busRoutesProvider);
}

/// Recarga para el gesto de tirar hacia abajo. Espera la respuesta para que el
/// indicador no desaparezca antes de tiempo, y no lanza: sin copia guardada, el
/// error ya lo pinta la pantalla.
Future<void> refreshTransport(WidgetRef ref) async {
  try {
    final _ = await ref.refresh(busRoutesProvider.future);
  } catch (_) {}
}

final busRouteByIdProvider = Provider.family<BusRoute?, String>((ref, id) {
  final list = ref.watch(busRoutesProvider).valueOrNull?.routes ?? const [];
  return list.firstWhereOrNull((r) => r.id == id);
});

/// Reloj que avanza por minutos, no por segundos.
///
/// Toda la pantalla de transporte se apoya en "¿qué hora es?" para decidir cuál
/// es la próxima salida y cuántos minutos faltan. Con un `Timer.periodic` de un
/// segundo se reconstruiría el árbol 60 veces por minuto para no cambiar nada:
/// el dato que se muestra tiene resolución de minuto. Se emite el valor actual
/// al instante y luego uno al filo de cada minuto.
///
/// Emite la hora de **pared de Guatemala** ([eventNow]), no la del teléfono. El
/// filo del minuto se calcula con la hora absoluta, que vale igual en cualquier
/// zona con desfase de horas enteras.
final _clockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;

  void tick() {
    controller.add(eventNow());
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    timer = Timer(next.difference(now), tick);
  }

  tick();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Hora actual del congreso con resolución de minuto. Las pantallas observan
/// esto en vez de llamar a `DateTime.now()` en `build`, que no reconstruye nada
/// por sí solo y además estaría en la zona del teléfono.
final nowProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(_clockProvider).valueOrNull ?? eventNow(),
);

/// Próxima salida de una ruta, o `null` si ya pasaron todas.
final nextDepartureProvider = Provider.autoDispose
    .family<({RouteDeparture departure, DateTime at})?, String>((ref, routeId) {
      final route = ref.watch(busRouteByIdProvider(routeId));
      if (route == null) return null;
      return route.nextDeparture(
        ref.watch(nowProvider),
        OvumEvent.agendaDays,
      );
    });

/// Días en los que esta ruta tiene alguna salida, en orden.
///
/// Incluye las salidas fechadas fuera de los días del congreso (llegadas del 10,
/// vuelta al aeropuerto del 14): antes salían en "Próxima salida" pero no en la
/// lista de horarios, así que no se podían ver ni agendar.
final serviceDaysProvider = Provider.family<List<DateTime>, String>((
  ref,
  routeId,
) {
  final route = ref.watch(busRouteByIdProvider(routeId));
  if (route == null) return const [];
  return route.serviceDays(OvumEvent.agendaDays);
});
