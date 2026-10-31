import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/core/network/api_client.dart';
import 'package:ovum/core/network/api_exception.dart';
import 'package:ovum/data/models/sponsor.dart';
import 'package:ovum/data/providers/content_providers.dart';
import 'package:ovum/data/repositories/api_ovum_repository.dart';

/// Responde por ruta. Un [ApiException] en [replies] se lanza en vez de devolverse.
class _FakeApi implements ApiClient {
  final replies = <String, Object?>{};
  final calls = <String>[];

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add(path);
    final reply = replies[path];
    if (reply is ApiException) throw reply;
    return reply;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Forma real de `GET /events/94/sponsors` (producción, 2026-10-29).
const _sponsors = {
  'data': [
    {'id': 1, 'nombre': 'Aviagen', 'logo': null, 'web': null, 'descripcion': null, 'nivel': 'Diamante', 'tipo': null},
    {'id': 2, 'nombre': 'Engormix', 'logo': null, 'web': null, 'descripcion': null, 'nivel': 'Media Partner', 'tipo': null},
    {'id': 3, 'nombre': 'Copa Airlines', 'logo': null, 'web': null, 'descripcion': null, 'nivel': 'Línea Aérea Oficial', 'tipo': null},
  ],
};

const _events = {
  'data': [
    {'id': 94, 'codigo': 'OVUM 2026', 'nombre': 'OVUM 2026'},
  ],
};

void main() {
  test('getSponsors mapea los niveles del API sin datos locales', () async {
    final api = _FakeApi()..replies['/events/94/sponsors'] = _sponsors;
    final repo = ApiOvumRepository(api, eventId: () async => '94');

    final sponsors = await repo.getSponsors();

    expect(sponsors.map((s) => s.name), ['Aviagen', 'Engormix', 'Copa Airlines']);
    expect(sponsors[0].tier, SponsorTier.diamante);
    expect(sponsors[1].tier.label, 'Media Partner');
    expect(sponsors[2].tier.label, 'Línea Aérea Oficial');
  });

  test('si el evento no se resuelve, getSponsors lanza en vez de inventar datos', () async {
    final api = _FakeApi();
    final repo = ApiOvumRepository(
      api,
      eventId: () async => throw const ApiException('sin red'),
    );

    await expectLater(repo.getSponsors(), throwsA(isA<ApiException>()));
    expect(api.calls, isEmpty);
  });

  test('tras un fallo de /events, reintentar vuelve a pedir el evento', () async {
    final api = _FakeApi()
      ..replies['/events'] = const ApiException('526', statusCode: 526)
      ..replies['/events/94/sponsors'] = _sponsors;
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(sponsorsProvider.future),
      throwsA(isA<ApiException>()),
    );

    // El backend vuelve; "Reintentar" invalida la lista.
    api.replies['/events'] = _events;
    container.invalidate(sponsorsProvider);

    final sponsors = await container.read(sponsorsProvider.future);
    expect(sponsors, hasLength(3));
    expect(api.calls.where((p) => p == '/events'), hasLength(2));
  });
}
