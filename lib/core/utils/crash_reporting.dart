import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/app_config.dart';

/// Crashlytics (proyecto Firebase `trivvo-ovum`, el mismo del push).
///
/// Todo pasa por aquí para que el resto de la app no dependa del plugin. Si
/// [setUpCrashReporting] no corrió (tests, `OVUM_CRASHLYTICS=false`), las demás
/// funciones solo escriben en consola.
bool _ready = false;

/// Engancha los manejadores globales de errores. Va en `main()` justo después
/// de `Firebase.initializeApp` y antes de `runApp`, para no perder los errores
/// del arranque.
Future<void> setUpCrashReporting() async {
  final crashlytics = FirebaseCrashlytics.instance;

  // En debug los errores ya salen en consola: mandarlos llenaría el panel de
  // ruido de builds que nadie más usa. La prueba de punta a punta sí envía.
  await crashlytics.setCrashlyticsCollectionEnabled(
    !kDebugMode || AppConfig.crashTest,
  );

  // Errores del framework (build, layout, pintado). También los imprime, así
  // que en debug se siguen viendo igual que antes.
  FlutterError.onError = crashlytics.recordFlutterFatalError;

  // Errores asíncronos que nadie capturó (un `Future` sin `catch`, un plugin
  // que lanza desde nativo). `recordError` los imprime en debug; `true` = ya
  // manejado.
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };

  _ready = true;

  if (AppConfig.crashTest) await _runCrashTest(crashlytics);
}

/// Asocia los reportes al id numérico del asistente — **nunca** el correo —
/// para poder cruzarlos con lo que ese usuario tiene en el backend. `null` =
/// sin sesión o invitado.
void setCrashUser(String? userId) {
  if (!_ready) return;
  unawaited(FirebaseCrashlytics.instance.setUserIdentifier(userId ?? ''));
}

/// Un error que la app captura y absorbe (sigue funcionando), pero que conviene
/// ver en el panel: fallos del almacén seguro, de la biometría, de las alarmas.
///
/// **No** es para errores del API: un 4xx o la falta de red son parte del uso
/// normal y solo meterían ruido.
void reportError(Object error, StackTrace? stack, {required String reason}) {
  debugPrint('$reason: $error');
  if (!_ready) return;
  unawaited(
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      printDetails: false, // ya se imprimió arriba
    ),
  );
}

/// Con `--dart-define=OVUM_CRASH_TEST=true` la app se cierra a propósito a los
/// pocos segundos de abrir, para comprobar que el reporte llega a Firebase.
///
/// Se cierra **una de cada dos veces**: si el arranque anterior acabó en
/// crash, este se queda abierto para que dé tiempo a subir el reporte (que
/// Crashlytics manda al abrir de nuevo). Al ser `const false` por defecto, en
/// una build normal todo esto ni siquiera se compila.
Future<void> _runCrashTest(FirebaseCrashlytics crashlytics) async {
  if (await crashlytics.didCrashOnPreviousExecution()) {
    debugPrint('OVUM_CRASH_TEST: el arranque anterior falló; subiendo reporte.');
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Timer(const Duration(seconds: 4), () {
      crashlytics.log('OVUM_CRASH_TEST: cierre provocado a propósito.');
      crashlytics.crash();
    });
  });
}
