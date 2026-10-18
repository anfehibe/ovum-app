import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Identificador estable de **instalación**, enviado como header `X-Device-Id`.
///
/// Lo pide el backend para limitar por dispositivo en vez de por IP: en el WiFi
/// del recinto todos los asistentes comparten la misma IP pública, y con el
/// límite por IP bastarían unas decenas de teléfonos para que el resto empezara
/// a recibir 429 (ver `docs/TRANSPORTE.md` §9.1 del repo `trivvo`).
///
/// No identifica a una persona ni sobrevive a una reinstalación: es un número
/// aleatorio guardado en `SharedPreferences`. No se deriva de ningún id del
/// dispositivo (IMEI, IDFV, Android ID) a propósito — eso sería un identificador
/// persistente y obligaría a declararlo como seguimiento en las tiendas.
const _key = 'device_id';

/// Devuelve el id guardado, o genera y persiste uno nuevo la primera vez.
///
/// Síncrono a propósito: se llama al construir el `ApiClient`, que vive en un
/// `Provider` sin `async`. `setString` actualiza la caché en memoria al momento
/// y escribe a disco en segundo plano, así que la siguiente lectura ya lo ve.
String deviceId(SharedPreferences prefs) {
  final saved = prefs.getString(_key);
  if (saved != null && saved.isNotEmpty) return saved;
  final fresh = _uuidV4();
  prefs.setString(_key, fresh);
  return fresh;
}

/// UUID v4 con `Random.secure()`. Evita una dependencia nueva solo para esto.
String _uuidV4() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  String hex(int from, int to) => bytes
      .sublist(from, to)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
