import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/core/network/api_client.dart';
import 'package:ovum/core/network/auth_token_store.dart';
import 'package:ovum/core/network/device_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adaptador que no sale a la red: captura la petición y responde 200 vacío.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString('{"data":[]}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('deviceId', () {
    test('genera un UUID v4 y lo persiste', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final first = deviceId(prefs);
      expect(
        first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      // Estable: la segunda llamada devuelve el mismo, no uno nuevo. Si no lo
      // fuera, cada petición contaría como un dispositivo distinto y el limiter
      // del backend dejaría de proteger nada.
      expect(deviceId(prefs), first);
      expect(prefs.getString('device_id'), first);
    });

    test('respeta uno ya guardado', () async {
      SharedPreferences.setMockInitialValues({'device_id': 'ya-existente'});
      final prefs = await SharedPreferences.getInstance();
      expect(deviceId(prefs), 'ya-existente');
    });

    test('dos instalaciones distintas no comparten id', () async {
      SharedPreferences.setMockInitialValues({});
      final a = deviceId(await SharedPreferences.getInstance());
      SharedPreferences.setMockInitialValues({});
      final b = deviceId(await SharedPreferences.getInstance());
      expect(a, isNot(b));
    });
  });

  group('ApiClient', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('manda X-Device-Id en la petición', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final api = ApiClient(
        AuthTokenStore(await SharedPreferences.getInstance()),
        dio: dio,
        baseUrl: 'https://ejemplo.test/api/v1',
        tenantSlug: 'anavi',
        deviceId: 'abc-123',
      );

      await api.get('/events/94/transport/routes');

      expect(adapter.last!.headers['X-Device-Id'], 'abc-123');
      expect(adapter.last!.headers['X-Tenant'], 'anavi');
    });

    test('sin device id no manda el header', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final api = ApiClient(
        AuthTokenStore(await SharedPreferences.getInstance()),
        dio: dio,
        baseUrl: 'https://ejemplo.test/api/v1',
      );

      await api.get('/events');

      expect(adapter.last!.headers.containsKey('X-Device-Id'), isFalse);
    });
  });
}
