import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/network/auth_token_store.dart';
import 'core/notifications/notification_service.dart';
import 'core/utils/crash_reporting.dart';
import 'data/providers/content_providers.dart';
import 'data/providers/preferences.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Las pantallas no están pensadas para horizontal. En iOS ya lo fija el
  // Info.plist; esto cubre Android.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // La app es multilingüe (es/en): se cargan los símbolos de fecha de ambos
  // para que `DateFormat` funcione en cualquiera de los dos idiomas.
  await initializeDateFormatting('es');
  await initializeDateFormatting('en');

  // Firebase debe estar listo antes de cualquier uso de Messaging, incluido el
  // registro del handler de segundo plano. El resto de la configuración de
  // notificaciones vive en `notificationsInitProvider` (necesita Riverpod).
  // Crashlytics también lo necesita, así que ya no depende solo del push.
  if (AppConfig.usePush || AppConfig.useCrashlytics) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  // Lo antes posible: un error en el resto del arranque también debe llegar.
  if (AppConfig.useCrashlytics) await setUpCrashReporting();
  if (AppConfig.usePush) {
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
