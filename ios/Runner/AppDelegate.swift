import Flutter
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
