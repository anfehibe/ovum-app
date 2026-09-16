import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../firebase_options.dart';
import '../config/app_config.dart';
import 'notification_routes.dart';

/// Handler de los mensajes que llegan con la app en segundo plano o cerrada.
///
/// Corre en un isolate aparte, así que debe ser una función top-level anotada
/// con `@pragma('vm:entry-point')` y reinicializar Firebase por su cuenta.
///
/// Hoy es casi un no-op: el panel de TRIVVO siempre envía un bloque
/// `notification`, así que el sistema dibuja la notificación solo. Existe para
/// que los mensajes *data-only* (si el backend los agrega) tengan dónde caer.
@pragma('vm:entry-point')
Future<void> ovumBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Envuelve FCM + notificaciones locales. No conoce Riverpod ni el API: expone
/// streams y métodos para que los providers decidan qué hacer.
class NotificationService {
  NotificationService();

  /// Avisos del congreso (push del panel). El id **debe** coincidir con el
  /// `default_notification_channel_id` del AndroidManifest.
  static const pushChannel = AndroidNotificationChannel(
    'ovum_avisos',
    'Avisos del congreso',
    description: 'Anuncios y cambios de agenda de OVUM 2026.',
    importance: Importance.high,
  );

  /// Recordatorios locales de las sesiones marcadas como favoritas.
  static const reminderChannel = AndroidNotificationChannel(
    'ovum_recordatorios',
    'Recordatorios de sesiones',
    description: 'Aviso antes de que empiecen tus sesiones guardadas.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  final _routes = StreamController<String>.broadcast();

  /// Rutas producidas al tocar una notificación con la app ya viva.
  Stream<String> get onNotificationRoute => _routes.stream;

  final _data = StreamController<Map<String, dynamic>>.broadcast();

  /// `data` crudo de las push que llegan con la app en primer plano, **sin
  /// esperar a que el usuario las toque**. Es lo que permite que una pantalla se
  /// refresque sola al llegar el aviso; quien escucha decide si le incumbe.
  Stream<Map<String, dynamic>> get onDataMessage => _data.stream;

  /// Id del interlocutor cuyo hilo está abierto ahora mismo, si lo hay. Lo fija
  /// `ChatScreen`. Sirve para no notificar un mensaje que el usuario está viendo
  /// entrar en pantalla.
  String? activeChatId;

  /// Ruta con la que se abrió la app desde cero (arranque en frío). La UI la
  /// consume después de que el splash termine de navegar.
  String? initialRoute;

  bool _inited = false;

  FlutterLocalNotificationsPlugin get plugin => _fln;

  AndroidFlutterLocalNotificationsPlugin? get _android => _fln
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    await _initTimeZone();

    await _fln.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_ovum'),
        // El permiso en iOS lo pide firebase_messaging (una sola vez, tras la
        // hoja explicativa). Pedirlo aquí también dispararía dos diálogos.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    await _android?.createNotificationChannel(pushChannel);
    await _android?.createNotificationChannel(reminderChannel);

    // Notificación local que abrió la app estando cerrada.
    final launch = await _fln.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final payload = launch!.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) initialRoute ??= payload;
    }

    if (!AppConfig.usePush) return;

    // En iOS el sistema muestra la push en primer plano; en Android no (lo
    // hacemos nosotros en _onForegroundMessage).
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedApp);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      initialRoute ??= resolveNotificationRoute(initial.data);
    }
  }

  /// `tz.local` arranca en UTC: sin esto los recordatorios se programarían con
  /// varias horas de corrimiento.
  Future<void> _initTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      // Identificador desconocido o plugin no disponible: UTC como respaldo.
      debugPrint('Zona horaria local no resuelta ($e); se usa UTC.');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  /// Pide el permiso de notificaciones. Una sola llamada cubre iOS **y** el
  /// `POST_NOTIFICATIONS` de Android 13+. Devuelve `true` si quedó autorizado.
  Future<bool> requestPermission() async {
    if (AppConfig.usePush) {
      final settings = await FirebaseMessaging.instance.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    // Sin FCM el permiso de Android hay que pedirlo por el plugin local.
    if (Platform.isAndroid) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  /// `true` si el usuario ya concedió el permiso del sistema.
  Future<bool> hasPermission() async {
    if (!AppConfig.usePush) return true;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// En Android las push en primer plano no se muestran solas: las dibujamos.
  /// En iOS ya lo hace el sistema (setForegroundNotificationPresentationOptions),
  /// así que replicarlo sacaría la notificación dos veces.
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // El dato se publica SIEMPRE y antes de cualquier corte por plataforma: es
    // lo que refresca la UI, y eso vale igual en iOS que en Android.
    _data.add(message.data);

    if (!Platform.isAndroid) return;
    final n = message.notification;
    if (n == null) return;

    // El hilo abierto ya va a mostrar el mensaje solo: notificarlo sería ruido.
    // Solo se puede evitar en Android, que es donde dibujamos nosotros; en iOS
    // la decisión es del sistema por `setForegroundNotificationPresentationOptions`
    // y suprimir caso por caso obligaría a dibujar todas las push a mano.
    final chat = chatCounterpartId(message.data);
    if (chat != null && chat == activeChatId) return;
    await _fln.show(
      id: message.messageId?.hashCode.abs() ?? DateTime.now().millisecond,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          pushChannel.id,
          pushChannel.name,
          channelDescription: pushChannel.description,
          icon: '@drawable/ic_stat_ovum',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: resolveNotificationRoute(message.data),
    );
  }

  void _onOpenedApp(RemoteMessage message) {
    final route = resolveNotificationRoute(message.data);
    if (route != null) _routes.add(route);
  }

  void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) _routes.add(payload);
  }

  // ── Token FCM ─────────────────────────────────────────────────────────────

  /// Token del dispositivo. `null` en el simulador de iOS (no hay APNs real).
  Future<String?> currentToken() async {
    if (!AppConfig.usePush) return null;
    try {
      if (Platform.isIOS && await FirebaseMessaging.instance.getAPNSToken() == null) {
        return null; // sin token APNs, getToken() se queda colgado o falla
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('No se pudo obtener el token FCM: $e');
      return null;
    }
  }

  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
}
