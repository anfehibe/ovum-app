# OVUM 2026

App del **XXIX Congreso Latinoamericano de Avicultura** (Ciudad de Guatemala, 11–13 nov 2026).

| | |
|---|---|
| Flutter | **3.44.8** · Dart `^3.12.2` |
| App id | `com.trivvo.ovum` (iOS y Android) |
| Versión | ver `version:` en `pubspec.yaml` |
| Backend | API TRIVVO v1 · `https://trivvo.events/api/v1` |

---

## Antes de compilar por primera vez

```bash
flutter pub get
```

### Secretos (no están en el repo)

Dos archivos **gitignored** que hay que crear a partir de su plantilla. Sin ellos la app compila
y arranca igual; lo único que pasa es que el mapa embebido sale sin teselas.

```bash
cp ios/Flutter/Secrets.example.xcconfig ios/Flutter/Secrets.xcconfig
cp android/local.properties.example android/local.properties   # si no existe ya
```

Luego rellena la clave de Google Maps en cada uno:

| Archivo | Clave | Formato |
|---|---|---|
| `ios/Flutter/Secrets.xcconfig` | `GMS_API_KEY` | `GMS_API_KEY = AIza…` (los espacios valen) |
| `android/local.properties` | `MAPS_API_KEY` | `MAPS_API_KEY=AIza…` (**sin espacios**: Gradle los conserva) |

Cómo obtenerlas: [`docs/MAPS-API-KEY.md`](docs/MAPS-API-KEY.md).

> ⚠️ **iOS usa CocoaPods desde que entró Google Maps.** A partir de ahora se abre
> `ios/Runner.xcworkspace`, **nunca** `ios/Runner.xcodeproj`: abriendo el `.xcodeproj` se compila
> sin los Pods y falla de formas confusas. Contexto en [`docs/SPIKE-IOS-MAPS.md`](docs/SPIKE-IOS-MAPS.md).

---

## Compilar

### Producción, las dos plataformas de una vez

El comando que se usa para preparar una entrega a las tiendas, con el mapa encendido:

```bash
flutter build appbundle --release --dart-define=OVUM_EMBEDDED_MAP=true && \
flutter build ios --release --dart-define=OVUM_EMBEDDED_MAP=true
```

Deja los artefactos en:

```
build/app/outputs/bundle/release/app-release.aab   → se sube a Google Play tal cual
build/ios/iphoneos/Runner.app                      → NO es subible: ver abajo
```

**El paso de iOS no termina ahí.** `flutter build ios` deja un `.app`, no un paquete que App Store
Connect acepte. Para subir:

```bash
open ios/Runner.xcworkspace
# Product → Archive → Distribute App
```

Si prefieres un `.ipa` listo para subir sin pasar por la interfaz de Xcode, cambia ese segundo
comando por `flutter build ipa --release --dart-define=OVUM_EMBEDDED_MAP=true`, que hace el
archivado y la exportación de una vez y lo deja en `build/ios/ipa/`.

Versión con comprobaciones previas, para no descubrir en la tienda algo que un test ya sabía:

```bash
flutter analyze && flutter test && \
flutter build appbundle --release --dart-define=OVUM_EMBEDDED_MAP=true && \
flutter build ios --release --dart-define=OVUM_EMBEDDED_MAP=true
```

Notas sobre este encadenado:

- **`&&` es secuencial, no paralelo.** No se pueden lanzar los dos builds a la vez con `&` en el
  mismo directorio: compiten por `.dart_tool/` y `build/` y el resultado es irreproducible. El
  orden es Android primero porque tarda menos: si algo falla, se sabe antes.
- **El build de iOS firma de verdad.** Necesita el certificado de distribución en el llavero y el
  equipo configurado en Xcode. Si falla por firma, el `&&` corta — pero el `.aab` ya está hecho, así
  que Android no se pierde.
- Para comprobar solo que iOS compila, sin firmar: añade `--no-codesign`.

### Desarrollo

```bash
flutter run
```

Con el mapa embebido encendido (necesita las claves de arriba):

```bash
flutter run --dart-define=OVUM_EMBEDDED_MAP=true
```

### Android

```bash
# APK de depuración
flutter build apk --debug

# APK firmado (pruebas de release en un dispositivo)
flutter build apk --release

# App Bundle para Google Play  ← lo que se sube a la tienda
flutter build appbundle --release
```

Con el mapa embebido:

```bash
flutter build appbundle --release --dart-define=OVUM_EMBEDDED_MAP=true
```

La firma de release sale de `android/key.properties` (gitignored), que apunta al keystore de
subida. Si falta, el build de release falla.

### iOS

```bash
# Simulador
flutter build ios --simulator --debug

# Dispositivo, sin firmar (comprobación de que compila)
flutter build ios --release --no-codesign

# Para subir a App Store: archivar desde Xcode
open ios/Runner.xcworkspace
# Product → Archive → Distribute App
```

> `flutter build ios --simulator --release` **no existe**: el simulador no admite modo release.
> Para probar AOT en iOS hay que ir a un dispositivo físico.

---

## Flags de compilación

Todos son `--dart-define`. Definidos en [`lib/core/config/app_config.dart`](lib/core/config/app_config.dart),
donde cada uno lleva su explicación.

### Los que importan al publicar

| Flag | Por defecto | Qué hace |
|---|---|---|
| `OVUM_EMBEDDED_MAP` | `false` | Mapa de Google dentro de la app. **Encenderlo exige la clave nativa**: sin ella, en iOS la app se cierra al abrir una pantalla con mapa |
| `OVUM_USER_CONTENT` | `false` | Chat, notas de reunión y bio de asistentes. Apagado hasta que el API tenga reportar y bloquear (App Store 1.2) |
| `OVUM_TRANSPORT` | `true` | Acceso a Transporte desde el inicio. Apagarlo lo oculta aunque el API responda |
| `OVUM_PUSH` | `true` | Notificaciones push (FCM) |
| `OVUM_CRASHLYTICS` | `true` | Reporte de cierres inesperados |
| `OVUM_CRASH_TEST` | `false` | **Cierra la app a propósito.** Nunca en una build que se publique |

### Entorno

| Flag | Por defecto |
|---|---|
| `OVUM_API_BASE` | `https://trivvo.events/api/v1` |
| `OVUM_TENANT` | `anavi` |
| `OVUM_EVENT_CODE` | `OVUM 2026` |

Hay además un flag `OVUM_API_*` por cada fuente de datos (agenda, ponentes, hoteles, transporte…),
todos en `true`. Poner uno en `false` hace que esa sección lea de `assets/mock/` en vez del API:
sirve para trabajar sin backend o para reproducir un fallo con datos fijos.

---

## Pruebas

```bash
flutter test            # suite completa
flutter analyze         # análisis estático
```

---

## Antes de publicar

- [ ] `flutter test` y `flutter analyze` en verde
- [ ] `OVUM_CRASH_TEST` **apagado**
- [ ] Subir la versión en `pubspec.yaml` (`version: x.y.z+build`)
- [ ] Si se publica con `OVUM_EMBEDDED_MAP=true`: tener registradas en la clave de Maps Android
      las huellas **SHA-1 de la clave de firma de Play** (y de la clave rotada anterior). Sin
      ellas el mapa sale gris **solo para quien descargue de la tienda** — en desarrollo se ve
      bien, así que el fallo se descubre tarde. Ver [`docs/MAPS-API-KEY.md`](docs/MAPS-API-KEY.md) §4

---

## Documentación

| | |
|---|---|
| [`docs/MAPS-API-KEY.md`](docs/MAPS-API-KEY.md) | Cómo obtener y restringir las claves de Google Maps |
| [`docs/SPIKE-IOS-MAPS.md`](docs/SPIKE-IOS-MAPS.md) | Por qué iOS usa CocoaPods y qué pasa sin clave |
| [`docs/API-PENDIENTES.md`](docs/API-PENDIENTES.md) | Estado del contrato con el backend |
| [`docs/API-APP-STORE.md`](docs/API-APP-STORE.md) | Requisitos de las tiendas pendientes del API |
