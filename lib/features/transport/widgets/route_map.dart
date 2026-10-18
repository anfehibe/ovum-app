import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
/// No activa `myLocationEnabled`: pedir el permiso de ubicación encarecería la
/// revisión en las tiendas y aquí no aporta nada — para "cómo llego" la pantalla
/// abre Google Maps, que ya tiene el permiso del usuario.
class RouteMap extends StatefulWidget {
  const RouteMap({super.key, required this.route, required this.color});

  final BusRoute route;
  final Color color;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  GoogleMapController? _controller;

  /// Puntos del trazado. Si el backend no mandó polilínea (`trazado: null`,
  /// porque el administrador aún no la recalculó) se cae a unir las paradas con
  /// líneas rectas: menos bonito, pero orienta igual.
  late final List<LatLng> _path = _buildPath();

  List<LatLng> _buildPath() {
    final encoded = widget.route.polyline;
    if (encoded != null && encoded.isNotEmpty) {
      final pts = decodePolyline(encoded);
      if (pts.length >= 2) {
        return [for (final p in pts) LatLng(p.lat, p.lng)];
      }
    }
    return [
      for (final s in widget.route.mappableStops) LatLng(s.lat!, s.lng!),
    ];
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.useEmbeddedMap) return const SizedBox.shrink();

    final stops = widget.route.mappableStops;
    // Sin al menos una parada ubicable no hay nada que encuadrar.
    if (stops.isEmpty) return const SizedBox.shrink();

    final scheme = context.scheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 230,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(stops.first.lat!, stops.first.lng!),
            zoom: 12,
          ),
          style: dark ? _darkStyle : null,
          polylines: _polylines(scheme),
          markers: _markers(),
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          liteModeEnabled: false,
          onMapCreated: (c) {
            _controller = c;
            _fit();
          },
        ),
      ),
    );
  }

  Set<Polyline> _polylines(ColorScheme scheme) {
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

  Set<Marker> _markers() => {
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
        infoWindow: InfoWindow(title: s.name, snippet: _snippet(s)),
      ),
  };

  /// Subtítulo del globo de una parada: los minutos estimados si el organizador
  /// los cargó, y si no la dirección.
  String _snippet(RouteStop s) {
    final m = s.minutesFromStart;
    if (m != null && m > 0) return '+$m min';
    return s.address;
  }

  /// Encuadra todo el recorrido. Se llama en `onMapCreated` porque antes no hay
  /// viewport contra el que calcular el zoom.
  Future<void> _fit() async {
    final pts = _path.isNotEmpty
        ? _path
        : [
            for (final s in widget.route.mappableStops)
              LatLng(s.lat!, s.lng!),
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

    await _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        40,
      ),
    );
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
