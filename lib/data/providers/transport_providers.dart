import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ovum_event.dart';
import '../../core/utils/iterable_ext.dart';
import '../models/bus_route.dart';
import 'content_providers.dart';

/// Rutas de bus del congreso (`GET /events/{id}/transport/routes`).
final busRoutesProvider = FutureProvider<List<BusRoute>>(
  (ref) => ref.watch(ovumRepositoryProvider).getBusRoutes(),
);

final busRouteByIdProvider = Provider.family<BusRoute?, String>((ref, id) {
  final list = ref.watch(busRoutesProvider).valueOrNull ?? const [];
  return list.firstWhereOrNull((r) => r.id == id);
});

/// Reloj que avanza por minutos, no por segundos.
///
/// Toda la pantalla de transporte se apoya en "¿qué hora es?" para decidir cuál
/// es la próxima salida y cuántos minutos faltan. Con un `Timer.periodic` de un
/// segundo se reconstruiría el árbol 60 veces por minuto para no cambiar nada:
/// el dato que se muestra tiene resolución de minuto. Se emite el valor actual
/// al instante y luego uno al filo de cada minuto, para que el cambio de "en 1
/// min" a "saliendo" caiga cuando toca y no hasta un minuto tarde.
final _clockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;

  void tick() {
    controller.add(DateTime.now());
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

/// Hora actual con resolución de minuto. Las pantallas observan esto en vez de
/// llamar a `DateTime.now()` en `build`, que no reconstruye nada por sí solo.
final nowProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(_clockProvider).valueOrNull ?? DateTime.now(),
);

/// Próxima salida de una ruta, o `null` si ya pasaron todas las del congreso.
final nextDepartureProvider = Provider.autoDispose
    .family<({RouteDeparture departure, DateTime at})?, String>((ref, routeId) {
      final route = ref.watch(busRouteByIdProvider(routeId));
      if (route == null) return null;
      return route.nextDeparture(
        ref.watch(nowProvider),
        OvumEvent.agendaDays,
      );
    });

/// Días del congreso en los que esta ruta tiene alguna salida, en orden.
///
/// Normalmente son los tres, pero una ruta con solo salidas fechadas (la de la
/// cena de gala, por ejemplo) debe mostrar únicamente su día.
final serviceDaysProvider = Provider.family<List<DateTime>, String>((
  ref,
  routeId,
) {
  final route = ref.watch(busRouteByIdProvider(routeId));
  if (route == null) return const [];
  return [
    for (final day in OvumEvent.agendaDays)
      if (route.departuresOn(day).isNotEmpty) day,
  ];
});
