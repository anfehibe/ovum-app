import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ovum/core/l10n/l10n.dart';
import 'package:ovum/core/ui/app_icons.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/polyline_codec.dart';
import '../../../data/models/bus_route.dart';

/// Mapa embebido con el trazado de una ruta y sus paradas.
///
/// **Devuelve `SizedBox.shrink()` si [AppConfig.useEmbeddedMap] está apagado.**
/// No es una optimización: en iOS, montar un `GoogleMap` sin que el SDK haya
/// recibido su clave **cierra la app** (ver `docs/SPIKE-IOS-MAPS.md` §4). Con el
/// flag apagado el widget nunca se construye, así que ese fallo es inalcanzable
/// por mucho que el proyecto nativo esté mal configurado.
///
/// Dos modos:
/// - **Vista previa** ([interactive] `false`, en el detalle de la ruta): sin
///   gestos. Dentro del scroll vertical de la pantalla, un mapa con gestos no se
///   podía desplazar en vertical (se lo quedaba el scroll) y el pellizco
///   respondía a destiempo. Tocarla llama a [onExpand].
/// - **Interactivo** (pantalla completa): todos los gestos.
///
/// No activa `myLocationEnabled`: pedir el permiso de ubicación encarecería la
/// revisión en las tiendas y aquí no aporta nada — para "cómo llego" la pantalla
/// abre Google Maps, que ya tiene el permiso del usuario.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    required this.color,
    this.interactive = false,
    this.height = 230,
    this.onExpand,
  });

  final BusRoute route;
  final Color color;
  final bool interactive;

  /// Alto fijo; `null` ocupa todo el espacio disponible (pantalla completa).
  final double? height;

  /// Al tocar la vista previa (abre el mapa a pantalla completa).
  final VoidCallback? onExpand;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap>
    with AutomaticKeepAliveClientMixin {
  GoogleMapController? _controller;

  /// Puntos del trazado. Si el backend no mandó polilínea (`trazado: null`,
  /// porque el administrador aún no la recalculó) se cae a unir las paradas con
  /// líneas rectas: menos bonito, pero orienta igual.
  late List<LatLng> _path = _buildPath();

  /// Sin esto, el `ListView` del detalle destruía la vista nativa al bajar a
  /// los horarios y la recreaba al volver: parpadeo, teselas recargadas y el
  /// encuadre repetido.
  @override
  bool get wantKeepAlive => true;

  List<LatLng> _buildPath() {
    final encoded = widget.route.polyline;
    if (encoded != null && encoded.isNotEmpty) {
      final pts = decodePolyline(encoded);
      if (pts.length >= 2) {
        return [for (final p in pts) LatLng(p.lat, p.lng)];
      }
    }
    return [for (final s in widget.route.mappableStops) LatLng(s.lat!, s.lng!)];
  }

  @override
  void didUpdateWidget(covariant RouteMap old) {
    super.didUpdateWidget(old);
    // Un refresco puede traer la misma ruta con otro trazado o paradas.
    if (old.route != widget.route) {
      _path = _buildPath();
      _fit();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!AppConfig.useEmbeddedMap) return const SizedBox.shrink();

    final stops = widget.route.mappableStops;
    // Sin al menos una parada ubicable no hay nada que encuadrar.
    if (stops.isEmpty) return const SizedBox.shrink();

    final dark = Theme.of(context).brightness == Brightness.dark;
    final interactive = widget.interactive;

    final map = GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(stops.first.lat!, stops.first.lng!),
        zoom: 12,
      ),
      // '' y no `null` para el tema claro: `null` significa "sin cambios", así
      // que al pasar de oscuro a claro el mapa se quedaba oscuro.
      style: dark ? _darkStyle : '',
      polylines: _polylines(),
      markers: _markers(context),
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      scrollGesturesEnabled: interactive,
      zoomGesturesEnabled: interactive,
      rotateGesturesEnabled: interactive,
      tiltGesturesEnabled: interactive,
      onTap: interactive ? null : (_) => widget.onExpand?.call(),
      onMapCreated: (c) {
        _controller = c;
        _fit();
      },
    );

    final framed = interactive
        ? map
        : Stack(
            children: [
              Positioned.fill(child: map),
              if (widget.onExpand != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Material(
                    color: context.scheme.surface.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      tooltip: context.l10n.transportExpandMap,
                      onPressed: widget.onExpand,
                      icon: const Icon(PhosphorIconsRegular.mapTrifold),
                    ),
                  ),
                ),
            ],
          );

    final sized = widget.height == null
        ? framed
        : SizedBox(height: widget.height, child: framed);
    return interactive
        ? sized
        : ClipRRect(borderRadius: BorderRadius.circular(20), child: sized);
  }

  Set<Polyline> _polylines() {
    if (_path.length < 2) return const {};
    return {
      // Contorno oscuro debajo: sin él la línea de color se pierde sobre las
      // calles claras de Google.
      Polyline(
        polylineId: const PolylineId('casing'),
        points: _path,
        width: 9,
        color: Colors.black.withValues(alpha: 0.25),
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: _path,
        width: 5,
        color: widget.color,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Set<Marker> _markers(BuildContext context) => {
    for (final s in widget.route.mappableStops)
      Marker(
        markerId: MarkerId('stop-${s.id}'),
        position: LatLng(s.lat!, s.lng!),
        // Las terminales en rojo, las intermedias en ámbar: de un vistazo se ve
        // dónde empieza y dónde acaba el recorrido.
        icon: BitmapDescriptor.defaultMarkerWithHue(
          s.order == 1 || s.isTerminal
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(title: s.name, snippet: _snippet(context, s)),
      ),
  };

  /// Subtítulo del globo de una parada: los minutos estimados si el organizador
  /// los cargó, y si no la dirección.
  String _snippet(BuildContext context, RouteStop s) {
    final m = s.minutesFromStart;
    if (m != null && m > 0) return context.l10n.transportPlusMinutes(m);
    return s.address;
  }

  /// Encuadra todo el recorrido: trazado **y** paradas. Solo el trazado no
  /// basta, porque una polilínea parcial (el decodificador tolera cadenas
  /// cortadas) dejaría paradas fuera de la vista.
  ///
  /// Se llama en `onMapCreated` porque antes no hay viewport contra el que
  /// calcular el zoom. Un fallo aquí solo deja la cámara inicial: no puede
  /// tumbar la pantalla ni ensuciar Crashlytics.
  Future<void> _fit() async {
    final controller = _controller;
    if (controller == null) return;
    final pts = [
      ..._path,
      for (final s in widget.route.mappableStops) LatLng(s.lat!, s.lng!),
    ];
    if (pts.isEmpty) return;

    var minLat = pts.first.latitude, maxLat = pts.first.latitude;
    var minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // Una ruta de una sola parada da un rect de área cero y newLatLngBounds
    // lanza; se le da un margen mínimo.
    const epsilon = 0.002;
    if (maxLat - minLat < epsilon) {
      minLat -= epsilon;
      maxLat += epsilon;
    }
    if (maxLng - minLng < epsilon) {
      minLng -= epsilon;
      maxLng += epsilon;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          40,
        ),
      );
    } catch (e) {
      debugPrint('No se pudo encuadrar el mapa de la ruta: $e');
    }
  }
}

/// Estilo oscuro mínimo, en línea para no añadir un asset. Baja el brillo del
/// mapa lo justo para que no deslumbre en tema oscuro y para que la polilínea
/// de la ruta siga siendo el elemento de más contraste.
const _darkStyle = '''
[
 {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
 {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
 {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
 {"featureType":"poi","stylers":[{"visibility":"simplified"}]},
 {"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},
 {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
 {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},
 {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},
 {"featureType":"transit","stylers":[{"visibility":"off"}]},
 {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]}
]
''';
