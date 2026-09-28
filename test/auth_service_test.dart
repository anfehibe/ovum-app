import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/core/network/api_client.dart';
import 'package:ovum/data/services/auth_service.dart';

/// Guarda el body de cada llamada en lugar de enviarlo.
class _FakeApi implements ApiClient {
  final bodies = <String, Object?>{};

  @override
  Future<dynamic> post(String path, {Object? body}) async {
    bodies[path] = body;
    return {
      'token': 't',
      'user': {'id': 1},
    };
  }

  @override
  Future<dynamic> delete(String path, {Object? body}) async {
    bodies[path] = body;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('login recorta los extremos del correo y la contraseña', () async {
    final api = _FakeApi();
    await AuthService(api).login(' ana@correo.com ', ' mi clave 1 ');
    expect(api.bodies['/login'], {
      'email': 'ana@correo.com',
      'password': 'mi clave 1',
    });
  });

  test('eliminar la cuenta recorta la contraseña igual que el login', () async {
    final api = _FakeApi();
    await AuthService(api).deleteAccount('mi clave 1 ');
    expect(api.bodies['/me'], {'password': 'mi clave 1'});
  });
}
