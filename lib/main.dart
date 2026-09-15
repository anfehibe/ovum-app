import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/network/auth_token_store.dart';
import 'core/notifications/notification_service.dart';
import 'data/providers/content_providers.dart';
import 'data/providers/preferences.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  // Firebase debe estar listo antes de cualquier uso de Messaging, incluido el
  // registro del handler de segundo plano. El resto de la configuración de
  // notificaciones vive en `notificationsInitProvider` (necesita Riverpod).
  if (AppConfig.usePush) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(ovumBackgroundHandler);
  }

  final prefs = await SharedPreferences.getInstance();

  // El token Bearer vive en el Keychain/KeyStore. La lectura arranca aquí pero
  // **no se espera**: bloquear `runApp` con ella dejaba la pantalla en blanco
  // casi un segundo en Android (KeyStore recién creado). Quien necesite el
  // token espera a `tokens.ready`; lo hace el splash antes de navegar.
  final tokens = AuthTokenStore(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authTokenStoreProvider.overrideWithValue(tokens),
      ],
      child: const OvumApp(),
    ),
  );
}
