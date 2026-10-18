import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Debe asignarse ANTES de que se registren los plugins.
    //
    // flutter_local_notifications depende de que FlutterAppDelegate sea el delegate
    // de UNUserNotificationCenter y le reenvíe los taps. firebase_messaging se pone
    // a sí mismo como delegate si el actual es nil, y solo respeta uno existente si
    // conforma FlutterAppLifeCycleProvider (que es el caso de FlutterAppDelegate).
    // Sin esta línea, firebase_messaging gana y los taps de las notificaciones
    // locales dejan de llegar a Dart.
    //
    // FirebaseApp.configure() NO va aquí: lo hace Firebase.initializeApp() desde Dart.
    UNUserNotificationCenter.current().delegate = self

    // Google Maps. La clave viene de Flutter/Secrets.xcconfig vía Info.plist, no
    // del código fuente.
    //
    // Medido en el spike (docs/SPIKE-IOS-MAPS.md), porque es contraintuitivo:
    //
    //   · provideAPIKey NUNCA se llama  → la app ABORTA al montar un GoogleMap
    //     (+[GMSServices checkServicePreconditions] lanza NSException).
    //   · provideAPIKey con clave INVÁLIDA → no se cae; el mapa monta su marco
    //     (logo, marcador, botón) pero sin teselas.
    //
    // O sea: esta guarda NO protege de nada por sí sola — saltarse la llamada
    // es justo lo que provoca el cierre. Lo que protege de verdad es que Dart
    // no construya ningún GoogleMap si el mapa no está habilitado
    // (AppConfig.useEmbeddedMap). Esta guarda solo evita pasarle al SDK una
    // cadena vacía cuando el mapa está apagado y nadie va a montar uno.
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
