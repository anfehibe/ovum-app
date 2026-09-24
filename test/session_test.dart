import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/core/network/auth_token_store.dart';
import 'package:ovum/core/notifications/session_reminders.dart';
import 'package:ovum/data/models/app_user.dart';
import 'package:ovum/data/providers/content_providers.dart';
import 'package:ovum/data/providers/networking_provider.dart';
import 'package:ovum/data/providers/notifications_provider.dart';
import 'package:ovum/data/providers/preferences.dart';
import 'package:ovum/data/providers/user_provider.dart';
import 'package:ovum/data/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePush extends PushRegistrationController {
  @override
  void build() {}

  @override
  Future<void> register({bool force = false}) async {}

  @override
  Future<void> unregister() async {}
}

class _FakeReminders extends SessionReminders {
  _FakeReminders() : super(FlutterLocalNotificationsPlugin());

  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cerrar sesión no choca con las cachés de la cuenta y las reinicia', () async {
    const carla = AppUser(
      id: '7',
      firstName: 'Carla',
      lastName: 'Demo',
      position: '',
      company: '',
      email: 'revisor.c@ovum.test',
    );
    SharedPreferences.setMockInitialValues({'auth_user': json.encode(carla.toJson())});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authTokenStoreProvider.overrideWithValue(AuthTokenStore(prefs)),
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      pushRegistrationProvider.overrideWith(_FakePush.new),
      sessionRemindersProvider.overrideWithValue(_FakeReminders()),
    ]);
    addTearDown(container.dispose);

    expect(container.read(sessionUserIdProvider), '7');

    // Dependientes vivos, como en la app con la pestaña Networking abierta. La
    // sonda de acceso es la que disparaba el CircularDependencyError. El binding
    // de test responde 400 a toda petición HTTP, así que la sonda queda en
    // `failed` sin salir a la red.
    container.listen(networkingAccessProvider, (_, _) {});
    await container.read(networkingAccessProvider.future);
    container.listen(networkingServiceProvider, (_, _) {});
    container.listen(directoryQueryProvider, (_, _) {});
    final servicioDeCarla = container.read(networkingServiceProvider);
    container.read(directoryQueryProvider.notifier).setSector('Genética');
    expect(container.read(directoryQueryProvider).sector, 'Genética');

    // Antes lanzaba CircularDependencyError y dejaba la sesión a medias.
    await container.read(authControllerProvider.notifier).logout();

    expect(container.read(authControllerProvider), isNull);
    expect(container.read(sessionUserIdProvider), isNull);
    expect(container.read(directoryQueryProvider).sector, isNull);
    expect(identical(container.read(networkingServiceProvider), servicioDeCarla), isFalse);
  });
}
