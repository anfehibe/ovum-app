/// Decodificador del *encoded polyline algorithm format* de Google.
///
/// El backend resuelve el trazado de cada ruta contra Routes API y lo manda ya
/// codificado en `trazado` (la clave de Google nunca sale del servidor), así
/// que la app solo necesita **decodificar**. Por eso no hay una dependencia de
/// `flutter_polyline_points`: ese paquete existe sobre todo para *llamar* a
/// Directions desde el cliente, que es justo lo que el diseño evita.
///
/// Devuelve pares `(lat, lng)` en orden. No depende de Flutter ni de ningún
/// SDK de mapas: así el día que se embeba el mapa basta con convertir a su tipo
/// `LatLng`, y mientras tanto esto es testeable sin plugins nativos.
library;

/// Un punto del trazado.
typedef LatLngPoint = ({double lat, double lng});

/// Decodifica [encoded] a la lista de puntos del trazado.
///
/// Tolerante por diseño: ante una cadena corrupta devuelve lo que haya podido
/// leer en vez de lanzar. Un trazado a medias se dibuja raro; una excepción
/// tumbaría la pantalla entera del transporte.
List<LatLngPoint> decodePolyline(String encoded) {
  final points = <LatLngPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    final dLat = _nextValue(encoded, index);
    if (dLat == null) break;
    index = dLat.next;
    lat += dLat.value;

    final dLng = _nextValue(encoded, index);
    if (dLng == null) break;
    index = dLng.next;
    lng += dLng.value;

    points.add((lat: lat / 1e5, lng: lng / 1e5));
  }
  return points;
}

/// Lee un entero con signo del formato de Google a partir de [start].
/// `null` si la cadena se acaba a media lectura.
({int value, int next})? _nextValue(String encoded, int start) {
  var shift = 0;
  var result = 0;
  var index = start;
  int byte;
  do {
    if (index >= encoded.length) return null;
    byte = encoded.codeUnitAt(index++) - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);
  // Bit menos significativo = signo, invertido en complemento a uno.
  final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  return (value: value, next: index);
}
