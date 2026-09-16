import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/notifications/notification_routes.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/content_providers.dart';
import 'data/providers/favorites_provider.dart';
import 'data/providers/messages_provider.dart';
import 'data/providers/notifications_provider.dart';
import 'data/providers/user_provider.dart';

class OvumApp extends ConsumerWidget {
  const OvumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return NotificationsBootstrap(
      child: MaterialApp.router(
        title: 'OVUM 2026',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}

/// Efectos secundarios de notificaciones, fuera de cualquier `build`:
/// inicializa el servicio, mantiene los recordatorios al día y encola las rutas
/// que produce el tap de una notificación.
class NotificationsBootstrap extends ConsumerStatefulWidget {
  const NotificationsBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationsBootstrap> createState() =>
      _NotificationsBootstrapState();
}

class _NotificationsBootstrapState
    extends ConsumerState<NotificationsBootstrap> {
  StreamSubscription<String>? _routeSub;
  StreamSubscription<Map<String, dynamic>>? _pushSub;

  @override
  void initState() {
    super.initState();
    // Arranca la inicialización (permisos aparte: los pide la hoja explicativa).
    ref.read(notificationsInitProvider);

    final service = ref.read(notificationServiceProvider);

    _routeSub = service.onNotificationRoute.listen((route) {
      ref.read(pendingNotificationRouteProvider.notifier).set(route);
    });

    // Un mensaje nuevo deja obsoleta la bandeja, esté abierta o no. Invalidar
    // basta: `conversationsProvider` es autoDispose, así que si nadie la mira
    // esto no cuesta una petición — se recargará al abrir "Mis chats".
    // El hilo abierto no se toca aquí; lo refresca `ChatScreen` por su cuenta.
    _pushSub = service.onDataMessage.listen((data) {
      if (chatCounterpartId(data) != null) ref.invalidate(conversationsProvider);
    });
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    _pushSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // La ruta con la que se abrió la app en frío solo está disponible una vez
    // que el servicio terminó de inicializarse.
    ref.listen(notificationsInitProvider, (_, next) {
      if (!next.hasValue) return;
      final initial = ref.read(notificationServiceProvider).initialRoute;
      if (initial != null) {
        ref.read(pendingNotificationRouteProvider.notifier).set(initial);
      }
      _syncReminders();
    });

    // Cualquier cambio en favoritos, agenda o preferencias reprograma todo.
    ref.listen(favoritesProvider, (_, _) => _syncReminders());
    ref.listen(sessionsProvider, (_, _) => _syncReminders());
    ref.listen(notificationPrefsProvider, (_, _) => _syncReminders());

    return widget.child;
  }

  /// Reprograma los recordatorios desde cero (idempotente y barato).
  Future<void> _syncReminders() async {
    if (!AppConfig.useLocalReminders) return;
    if (!ref.read(notificationsInitProvider).hasValue) return;

    final reminders = ref.read(sessionRemindersProvider);
    final prefs = ref.read(notificationPrefsProvider);

    if (!prefs.remindersEnabled) {
      await reminders.cancelAll();
      return;
    }

    final sessions = ref.read(sessionsProvider).valueOrNull;
    if (sessions == null) return; // la agenda aún no cargó

    final favs = ref.read(favoritesProvider);
    final favoritas = sessions
        .where((s) => favs.contains(favKey(FavKind.session, s.id)))
        .toList();

    await reminders.rescheduleAll(favoritas, leadMinutes: prefs.leadMinutes);
  }
}
