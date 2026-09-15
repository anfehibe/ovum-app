import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Instancia única de `flutter_secure_storage` con las opciones de la app:
/// Keychain en iOS, KeyStore en Android.
///
/// `first_unlock_this_device` en iOS: el token tiene que poder leerse tras un
/// reinicio aunque el usuario aún no haya desbloqueado (la app puede arrancar
/// en frío por una push) y **no** debe viajar a otro equipo en un backup de
/// iCloud.
///
/// En Android bastan los valores por defecto de la 10.x (AES-GCM con la clave
/// envuelta por RSA-OAEP en el KeyStore, y `resetOnError: true` para que un
/// backup restaurado devuelva `null` en vez de reventar). No se usa
/// `AndroidOptions.biometric()`: la biometría la decide `local_auth`, no el
/// almacén — mezclarlas rompería la lectura del token en arranque en frío.
abstract final class OvumSecureStorage {
  static const iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  static const androidOptions = AndroidOptions();

  static const instance = FlutterSecureStorage(
    iOptions: iosOptions,
    aOptions: androidOptions,
  );
}
