import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers/preferences.dart';
import '../config/app_config.dart';
import '../utils/crash_reporting.dart';

/// Pide al usuario que califique la app en su tienda (App Store / Google Play).
///
/// Hay dos caminos:
///   * [onPositiveMoment]: tras algo que salió bien (aceptar o pedir una
///     reunión, guardar un favorito) muestra la **ventana nativa** de la
///     tienda — estrellas y comentario sin salir de la app — si el usuario ya
///     usó la app lo suficiente. La tienda decide si de verdad aparece: Apple
///     la limita a 3 veces al año por usuario y Google aplica una cuota que no
///     publica. No hay forma de saber si calificó.
///   * [openStoreListing]: el botón fijo del perfil. Abre la ficha de la tienda
///     (en iOS directo en "Escribir reseña") y apaga la ventana automática.
///
/// Las reglas de las tiendas prohíben preguntar antes "¿te gusta la app?" para
/// mandar solo a los contentos, y ofrecer algo a cambio: por eso aquí no hay
/// diálogo propio, solo la ventana del sistema.
///
/// Pruebas: en iOS la ventana sale en simulador y builds de desarrollo, pero
/// **nunca en TestFlight**; en Android solo si la app vino de Play (p. ej. la
/// pista de prueba interna).
class AppRating {
  AppRating(this._prefs);

  final SharedPreferences _prefs;

  static const _kFirstSeen = 'rating.firstSeen';
  static const _kLaunches = 'rating.launches';
  static const _kMoments = 'rating.moments';
  static const _kAskCount = 'rating.askCount';
  static const _kLastAsked = 'rating.lastAsked';
  static const _kOptedOut = 'rating.openedStore';

  /// Cuánto uso hace falta antes de la primera ventana: no en la primera
  /// apertura ni a los cinco minutos de instalar.
  static const _minLaunches = 3;
  static const _minMoments = 3;
  static const _minAge = Duration(days: 1);

  /// Entre una ventana y la siguiente. El congreso dura pocos días, así que
  /// no tiene sentido esperar meses; igual la tienda pone su propio tope.
  static const _minGap = Duration(days: 4);
  static const _maxAsks = 3;

  /// Espera antes de mostrar la ventana, para que no tape el snackbar o la
  /// animación de la acción que la disparó.
  static const _delay = Duration(milliseconds: 1500);

  /// Va en `main()` una vez por arranque.
  void recordLaunch() {
    if (!_prefs.containsKey(_kFirstSeen)) {
      _prefs.setInt(_kFirstSeen, DateTime.now().millisecondsSinceEpoch);
    }
    _prefs.setInt(_kLaunches, (_prefs.getInt(_kLaunches) ?? 0) + 1);
  }

  /// Cuenta un momento positivo y, si toca, muestra la ventana de la tienda.
  /// No espera a la ventana: se puede llamar sin `await`.
  void onPositiveMoment() {
    if (!AppConfig.useRatingPrompt) return;
    final moments = (_prefs.getInt(_kMoments) ?? 0) + 1;
    _prefs.setInt(_kMoments, moments);
    if (_shouldAsk(moments, DateTime.now())) unawaited(_ask());
  }

  bool _shouldAsk(int moments, DateTime now) {
    if (_prefs.getBool(_kOptedOut) ?? false) return false;
    if (moments < _minMoments) return false;
    if ((_prefs.getInt(_kLaunches) ?? 0) < _minLaunches) return false;
    if ((_prefs.getInt(_kAskCount) ?? 0) >= _maxAsks) return false;
    final firstSeen = _prefs.getInt(_kFirstSeen);
    if (firstSeen == null ||
        now.difference(DateTime.fromMillisecondsSinceEpoch(firstSeen)) <
            _minAge) {
      return false;
    }
    final lastAsked = _prefs.getInt(_kLastAsked);
    if (lastAsked != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(lastAsked)) <
            _minGap) {
      return false;
    }
    return true;
  }

  Future<void> _ask() async {
    // Se anota antes de pedirla: si dos acciones caen seguidas no salen dos.
    _prefs.setInt(_kLastAsked, DateTime.now().millisecondsSinceEpoch);
    _prefs.setInt(_kAskCount, (_prefs.getInt(_kAskCount) ?? 0) + 1);
    try {
      await Future<void>.delayed(_delay);
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (e, st) {
      reportError(e, st, reason: 'In-app review request failed');
    }
  }

  /// Abre la ficha de la app en su tienda. Quien llega aquí por su cuenta
  /// probablemente ya calificó, así que la ventana automática deja de salir.
  Future<void> openStoreListing() async {
    _prefs.setBool(_kOptedOut, true);
    try {
      await InAppReview.instance.openStoreListing(
        appStoreId: AppConfig.appStoreId,
      );
    } catch (e, st) {
      reportError(e, st, reason: 'Opening store listing failed');
    }
  }
}

final appRatingProvider = Provider<AppRating>(
  (ref) => AppRating(ref.watch(sharedPreferencesProvider)),
);
