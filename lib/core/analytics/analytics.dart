import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';

/// Google Analytics para Firebase (proyecto `trivvo-ovum`, el mismo del push y
/// de Crashlytics).
///
/// Igual que `crash_reporting.dart`: todo pasa por aquí para que el resto de
/// la app no dependa del plugin. Si [setUpAnalytics] no corrió (tests,
/// `OVUM_ANALYTICS=false`), las demás funciones no hacen nada.
///
/// **Qué no se manda nunca:** correos, nombres, texto que escribe el usuario
/// (chat, preguntas, notas) ni ids de *otros* asistentes. Solo ids de contenido
/// del congreso (sesión, conferencista, patrocinador, expositor, ruta de bus).
bool _ready = false;
String? _language;

/// Va en `main()` después de `Firebase.initializeApp`.
Future<void> setUpAnalytics() async {
  // En debug no se envía: las pruebas de desarrollo ensuciarían las cifras del
  // congreso. `OVUM_ANALYTICS_DEBUG` lo enciende para mirar el DebugView.
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
    !kDebugMode || AppConfig.analyticsDebug,
  );
  _ready = true;
}

/// Evento con nombre propio. Los nombres y parámetros van en snake_case, sin
/// tildes, máx. 40 caracteres (límites de Firebase). Los `null` se descartan.
void logEvent(String name, [Map<String, Object?> params = const {}]) {
  if (!_ready) return;
  final clean = <String, Object>{
    for (final e in params.entries)
      if (e.value != null) e.key: e.value is num ? e.value! : '${e.value}',
  };
  unawaited(
    FirebaseAnalytics.instance
        .logEvent(name: name, parameters: clean.isEmpty ? null : clean)
        .catchError((Object e) => debugPrint('Analytics $name: $e')),
  );
}

/// Id numérico del asistente — **nunca** el correo — y si es invitado. `null`
/// = sin sesión o invitado.
void setAnalyticsUser(String? userId, {required bool isGuest}) {
  if (!_ready) return;
  final a = FirebaseAnalytics.instance;
  unawaited(a.setUserId(id: userId));
  unawaited(a.setUserProperty(
    name: 'user_type',
    value: userId != null ? 'attendee' : (isGuest ? 'guest' : null),
  ));
}

/// Idioma en el que el usuario ve la app (`es` / `en`).
void setAnalyticsLanguage(String languageCode) {
  // Se llama en cada build de `MaterialApp`: solo se manda si cambió.
  if (!_ready || languageCode == _language) return;
  _language = languageCode;
  unawaited(FirebaseAnalytics.instance
      .setUserProperty(name: 'app_language', value: languageCode));
}

// ── Eventos de la app ────────────────────────────────────────────────────────

/// `method`: `password`, `biometric` o `guest`.
void logLogin(String method) {
  if (!_ready) return;
  unawaited(FirebaseAnalytics.instance.logLogin(loginMethod: method));
}

/// Guardar o quitar un favorito. `kind` = sesión, conferencista, etc.
void logFavorite({required String kind, required String id, required bool added}) =>
    logEvent(added ? 'add_favorite' : 'remove_favorite',
        {'content_type': kind, 'item_id': id});

/// Enlace externo abierto. Solo el dominio: la URL completa puede traer datos
/// de quien la publicó (perfil de LinkedIn de un asistente, p. ej.).
void logOutboundLink(Uri uri) =>
    logEvent('outbound_link', {'link_domain': uri.host});

// ── Pantallas ────────────────────────────────────────────────────────────────

/// Rutas con `:id` cuyo id es **contenido del congreso** y vale la pena contar
/// por ítem ("cuántos vieron al patrocinador X"). Las de asistentes, chats y
/// reuniones quedan fuera a propósito: ese id es de una persona.
const _contentTypes = <String, String>{
  '/session/:id': 'session',
  '/speaker/:id': 'speaker',
  '/sponsor/:id': 'sponsor',
  '/exhibitor/:id': 'exhibitor',
  '/transport/route/:id': 'bus_route',
};

/// Registra `screen_view` (y `select_content` en los detalles) cada vez que
/// cambia la pantalla de arriba, sea por `go`, `push`, volver atrás o cambio de
/// pestaña. Se escucha el delegate del router en vez de usar un
/// `NavigatorObserver` porque las pestañas del shell no son un push y el
/// observer no las ve.
///
/// El nombre de pantalla es el **patrón** de la ruta (`/speaker/:id`), no la
/// ubicación real: así los informes agrupan y no viaja ningún id en el nombre.
void trackScreens(GoRouter router) {
  String? last;
  void onChange() {
    final (pattern, id) = topScreen(router.routerDelegate.currentConfiguration);
    if (pattern == null || pattern.isEmpty) return;
    final key = '$pattern#$id';
    if (key == last) return;
    last = key;
    if (!_ready) return;
    unawaited(FirebaseAnalytics.instance.logScreenView(screenName: pattern));
    final type = _contentTypes[pattern];
    if (type != null && id != null) {
      unawaited(FirebaseAnalytics.instance.logSelectContent(
        contentType: type,
        itemId: id,
      ));
    }
  }

  router.routerDelegate.addListener(onChange);
}

/// Patrón e `:id` de la pantalla visible. Una ruta abierta con `push` va
/// envuelta en un [ImperativeRouteMatch] con su propia lista de matches.
@visibleForTesting
(String?, String?) topScreen(RouteMatchList list) {
  if (list.isEmpty) return (null, null);
  final top = list.matches.last;
  if (top is ImperativeRouteMatch) return topScreen(top.matches);
  return (list.fullPath, list.pathParameters['id']);
}
