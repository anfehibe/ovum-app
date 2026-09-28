import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ovum/data/providers/biometric_provider.dart';
import 'package:ovum/data/providers/content_providers.dart';
import 'package:ovum/data/providers/preferences.dart';
import 'package:ovum/features/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpLogin(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Sin banner del API: se pinta el header de respaldo y no hay red.
        headerBannerProvider.overrideWithValue(null),
        biometricAvailableProvider.overrideWith((ref) async => false),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
}

void main() {
  testWidgets('el correo descarta los espacios al escribir o pegar', (tester) async {
    await _pumpLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      ' ana perez@correo.com ',
    );
    expect(find.text('anaperez@correo.com'), findsOneWidget);
  });

  testWidgets('la contraseña conserva los espacios', (tester) async {
    // Los de en medio son parte de la clave; los de los extremos los quita
    // `AuthService` al enviar (ver auth_service_test.dart).
    await _pumpLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'mi clave 1',
    );
    expect(find.text('mi clave 1'), findsOneWidget);
  });
}
