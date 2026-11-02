import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../core/widgets/states.dart';
import '../../data/models/bus_route.dart';
import '../../data/providers/transport_providers.dart';
import 'transport_shared.dart';
import 'widgets/route_map.dart';

/// Mapa de una ruta a pantalla completa, con todos los gestos.
///
/// Se llega tocando la vista previa del detalle, que va sin gestos para no
/// pelear con el scroll vertical de la pantalla.
class BusRouteMapScreen extends ConsumerWidget {
  const BusRouteMapScreen({super.key, required this.routeId});
  final String routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(busRouteByIdProvider(routeId));
    if (route == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: PhosphorIconsRegular.bus,
          message: context.l10n.transportRouteUnavailable,
        ),
      );
    }
    final routes =
        ref.watch(busRoutesProvider).valueOrNull?.routes ?? const <BusRoute>[];
    final index = routes.indexWhere((r) => r.id == route.id);
    return Scaffold(
      appBar: AppBar(title: Text(route.name)),
      body: RouteMap(
        route: route,
        color: routeColor(context, route, index < 0 ? 0 : index),
        interactive: true,
        height: null,
      ),
    );
  }
}
