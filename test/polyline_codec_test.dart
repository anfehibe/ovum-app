import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/core/utils/polyline_codec.dart';

void main() {
  group('decodePolyline', () {
    test('decodifica el vector canónico de Google', () {
      // Ejemplo oficial de la documentación del formato.
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points.length, 3);
      expect(points[0].lat, closeTo(38.5, 1e-5));
      expect(points[0].lng, closeTo(-120.2, 1e-5));
      expect(points[1].lat, closeTo(40.7, 1e-5));
      expect(points[1].lng, closeTo(-120.95, 1e-5));
      expect(points[2].lat, closeTo(43.252, 1e-5));
      expect(points[2].lng, closeTo(-126.453, 1e-5));
    });

    test('decodifica el trazado real que devuelve el API', () {
      // Ruta A de OVUM 2026, tal cual la sirve producción.
      const trazado =
          '_mbxA~pmgPKlAa@vDi@hGV`@DZ?XKtAo@`GiCUG\\S^c@^SJUFa@BQCSISMOOKQKYGg@?CQKyB_@gUcC{TaC{ApO';
      final points = decodePolyline(trazado);
      expect(points, isNotEmpty);
      // Guatemala: ~14.6 N, ~-90.5 E. Si el trazado saliera de ese cuadro,
      // casi seguro es lat/lng invertidas en el backend.
      for (final p in points) {
        expect(p.lat, inInclusiveRange(14.4, 14.8));
        expect(p.lng, inInclusiveRange(-90.8, -90.3));
      }
    });

    test('devuelve vacío para una cadena vacía', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('no lanza con una cadena truncada', () {
      // Media lectura: debe devolver lo que pudo, no explotar.
      expect(() => decodePolyline('_p~iF~ps|U_ulL'), returnsNormally);
    });
  });
}
