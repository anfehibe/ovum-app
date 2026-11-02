import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bus_route.dart';
import 'mappers/transport_mapper.dart';

/// Última respuesta buena de las rutas de transporte, guardada en el teléfono.
///
/// El caso de uso real es el lobby del hotel a las 06:45: wifi saturado o datos
/// del extranjero apagados. Un horario de bus casi no cambia, así que mostrar el
/// de hace unas horas con un aviso es mucho mejor que una pantalla de error. Se
/// guarda en el formato del API (ver `busRouteToJson`) para leerlo con el mismo
/// mapper.
class TransportCache {
  TransportCache(this._prefs);

  final SharedPreferences _prefs;

  /// Con versión: si cambia el formato, la caché vieja se ignora sin romper.
  static const _key = 'transport_routes_cache_v1';

  /// Guarda [routes] con el instante en que se obtuvieron.
  Future<void> save(List<BusRoute> routes, DateTime savedAt) async {
    final payload = jsonEncode({
      'saved_at': savedAt.millisecondsSinceEpoch,
      'data': [for (final r in routes) busRouteToJson(r)],
    });
    await _prefs.setString(_key, payload);
  }

  /// Lo guardado, o `null` si no hay nada o está corrupto.
  ({List<BusRoute> routes, DateTime savedAt})? load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ms = map['saved_at'] as int;
      final data = map['data'] as List<dynamic>;
      return (
        routes: busRoutesFromJson(data),
        savedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      );
    } catch (e) {
      // Una caché ilegible no puede tumbar la pantalla: se ignora.
      debugPrint('Caché de transporte ilegible: $e');
      return null;
    }
  }
}
