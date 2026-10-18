# Spike: mapa embebido en iOS (`google_maps_flutter`)

**Rama:** `spike/ios-google-maps` · **Fecha:** 18 de octubre de 2026
**Pregunta que responde:** ¿podemos añadir el mapa embebido del Nivel B sin romper el build de iOS,
a 24 días del congreso y con una build en revisión de App Store?

**Criterio de aceptación (binario, fijado antes de empezar):** la app actual sigue compilando y
arrancando, y el pin de `path_provider_foundation: 2.4.1` no se mueve. Si no se cumple, se escala
antes de escribir una línea de UI del mapa.

---

## Veredicto

| Comprobación | Resultado |
|---|---|
| `pod install` se genera y resuelve | ✅ |
| `flutter build ios --simulator --debug` | ✅ `Xcode build done · 107,5 s` |
| `path_provider_foundation` sigue en 2.4.1 | ✅ |
| `share_plus` 13.3.0 y `add_2_calendar` 3.1.1 sin mover | ✅ |
| La app arranca y la navegación existente funciona | ✅ |
| El mapa renderiza con teselas | ✅ **verificado en iOS y Android con las claves reales** |
| La app **no se cierra** si falta la clave | ✅ tras el arreglo de §4 — **antes sí se cerraba** |

**Pasa.** El riesgo técnico que nos preocupaba —que añadir el mapa rompiera el build de iOS— **no
se materializó**. Pero aparecieron dos cosas que no estaban en el análisis y que cambian la
recomendación; están en §3 y §6.

---

## 1. Lo que confirmamos sobre el plugin

`google_maps_flutter_ios` **2.18.7** (la versión que resuelve hoy) contiene únicamente
`ios/google_maps_flutter_ios.podspec`. **No tiene `Package.swift`**, así que no soporta Swift
Package Manager. Comparar con `permission_handler_apple`, que sí lo tiene.

Arrastra dos dependencias nativas de peso:

```
GoogleMaps (~> 9.0)
Google-Maps-iOS-Utils (6.1.0)
```

---

## 2. Qué le pasó al proyecto de iOS

El proyecto era **SPM puro**: cero referencias a Pods, 16 a `SwiftPackage`, sin `Podfile`.
Tras añadir la dependencia y compilar:

| Antes | Después |
|---|---|
| `Pods` en `project.pbxproj`: **0** | **43** |
| `SwiftPackage` en `project.pbxproj`: 16 | **16** (siguen) |
| `ios/Podfile` | **creado** por Flutter |
| `ios/Podfile.lock` | **creado** |
| `ios/Pods/` | **creado** (GoogleMaps + Utils) |
| `project.pbxproj` | **+114 / −2 líneas** |

Es decir: el proyecto quedó en **modo híbrido SPM + CocoaPods**. Flutter lo soporta y compila,
pero es el camino menos rodado.

`Debug.xcconfig` y `Release.xcconfig` ya traían `#include?` del xcconfig de Pods (lo añade Flutter
al generar el Podfile), así que no hubo que tocarlos para eso.

### A partir de ahora: `Runner.xcworkspace`, nunca `Runner.xcodeproj`

Con CocoaPods en juego, abrir el `.xcodeproj` directamente compila sin los Pods y falla de formas
confusas. **Documentar en el README.**

---

## 3. 🔴 Hallazgo nuevo: Flutter va a cerrar este camino

El build imprime, literalmente:

```
The following plugins do not support Swift Package Manager for ios:
  - google_maps_flutter_ios
This will become an error in a future version of Flutter.
```

No es solo fricción de hoy: hoy es un aviso, y Flutter anuncia que **pasará a ser un error**.
Esto no bloquea OVUM 2026 —la versión actual compila—, pero sí significa que el proyecto queda
anclado: **no se podrá actualizar Flutter libremente mientras el mapa embebido esté dentro**,
hasta que el plugin adopte SPM.

Es un coste que no estaba en el análisis original y que conviene que alguien decida conscientemente,
no descubrirlo en la próxima actualización de Flutter.

---

## 4. ⛔ El mapa no se puede ver todavía: falta la API key

El build pasa, pero **renderizar es otra pregunta** y está bloqueada fuera del código.

El SDK de iOS exige `GMSServices.provideAPIKey(...)` antes de montar el primer mapa.
Comportamiento según el estado de la clave:

**Medido en el simulador, no deducido** — y el resultado corrigió lo que este documento decía en
su primera versión:

**Las dos plataformas se comportan distinto, y esa diferencia importa:**

| Plataforma | Estado de la clave | Qué pasa | ¿Verificado? |
|---|---|---|---|
| **iOS** | `provideAPIKey` **nunca se llama** | 💥 **La app se cierra** al montar el primer `GoogleMap` | ✅ simulador |
| **iOS** | Clave **inválida** | No se cae. Monta el marco (logo, marcador, botón) **sin teselas** | ✅ simulador |
| **Android** | Clave **vacía** | No se cae. **Mapa gris con el logo de Google** | ✅ emulador |
| **iOS** | Clave **válida** | 🗺️ **Mapa con calles y marcador** | ✅ simulador (18-oct) |
| **Android** | Clave **válida** | 🗺️ **Mapa con calles y marcador**, logcat sin errores | ✅ emulador (18-oct) |

En Android el fallo queda registrado de forma inequívoca en logcat, lo que ayuda a diagnosticar:

```
E Google Maps Android API: Error requesting API token. StatusCode=INVALID_ARGUMENT
E Google Android Maps SDK: Authorization failure. Please see https://developers.google.com/maps/documentation/android-sdk/start
E Google Android Maps SDK:   API Key:
```

**Android nunca se cierra por falta de clave; iOS sí.** Toda la fragilidad está del lado de iOS, y
viene de que su SDK exige una inicialización explícita que el de Android no necesita.

Traza del cierre:

```
+[GMSServices checkServicePreconditions]        ← NSException
+[GMSServices preLaunchServicesWithCompletion:]
-[FGMGoogleMapFactory sharedMapServices]
-[FGMGoogleMapFactory createWithFrame:viewIdentifier:arguments:]
-[FlutterPlatformViewsController onCreate:result:]
```

### ⚠️ La guarda del `AppDelegate` no protege de nada

La primera versión de esta rama tenía esto en `AppDelegate.swift`:

```swift
if let key = ..., !key.isEmpty { GMSServices.provideAPIKey(key) }
```

escrito con la intención de "si no hay clave, que no se caiga". **Hace exactamente lo contrario**:
no llamar a `provideAPIKey` es justo la condición que provoca el cierre. Con la clave vacía, esa
guarda *garantiza* el crash en vez de evitarlo.

### Lo que sí protege: apagar el mapa desde Dart

`AppConfig.useEmbeddedMap` (`--dart-define=OVUM_EMBEDDED_MAP`, **apagado por defecto**). Con el
flag apagado el widget `GoogleMap` **no se construye nunca**, así que el SDK no se inicializa y no
hay forma de llegar al crash, esté como esté el proyecto nativo.

Encender el mapa exige **las dos cosas a la vez**:

1. `GMS_API_KEY` válida en `ios/Flutter/Secrets.xcconfig` (y su equivalente en Android).
2. `--dart-define=OVUM_EMBEDDED_MAP=true`.

Es más fricción para quien publique, y es el punto: convierte "se me olvidó la clave" de un cierre
en producción a un mapa que simplemente no aparece.

### Fontanería ya montada en esta rama

```
ios/Flutter/Secrets.example.xcconfig   ← plantilla, se commitea
ios/Flutter/Secrets.xcconfig           ← valores reales, GITIGNORED
ios/Flutter/{Debug,Release}.xcconfig   ← +#include? "Secrets.xcconfig"
ios/Runner/Info.plist                  ← GMSApiKey = $(GMS_API_KEY)
ios/Runner/AppDelegate.swift           ← GMSServices.provideAPIKey(), con guarda
```

Para activarlo, el día que exista la clave:

```bash
cp ios/Flutter/Secrets.example.xcconfig ios/Flutter/Secrets.xcconfig
# y rellenar GMS_API_KEY
```

La clave **no se commitea** y **no se escribe en el código fuente**.

> **Resuelto el 18 de octubre.** El cliente creó un proyecto de Google Cloud con facturación
> —**distinto** del de Firebase, lo cual es correcto y no da problemas— y dos claves separadas,
> una por plataforma. Ambas verificadas: el mapa renderiza con calles y marcador en iPhone 17 Pro
> (simulador) y en un emulador Android, sin errores de autorización en logcat.
>
> **Sigue pendiente una sola cosa**: añadir a la clave de Android la huella SHA-1 de la *clave de
> firma de apps* de Play Console. No existe hasta subir el primer build a Play. **Sin ella el mapa
> sale gris solo para quien descargue de la tienda**, y como funciona en desarrollo es un fallo
> que se descubre tarde. Es un cambio en la consola de Google, no en el código.

### Lo que hace falta del lado de Google Cloud

1. Proyecto con **facturación activa**. Sin tarjeta el mapa sale gris aunque el consumo sea cero.
2. **Maps SDK for iOS** habilitado (y *for Android*, que es una clave aparte).
3. Clave restringida a **aplicaciones iOS → bundle id `com.trivvo.ovum`**.
4. **No reutilizar** la clave de Firebase ni la de servidor de Routes API: son tres claves con
   restricciones distintas (ver `docs/TRANSPORTE.md` §10.1 del repo `trivvo`).

Esto sigue bloqueado en la decisión del organizador sobre quién abre y paga la cuenta
(`docs/TRANSPORTE-ORGANIZADOR.md` §3). **Es ahora el único bloqueante del Nivel B.**

---

---

## 4-bis. El lado Android

Se cableó en esta misma rama. Tres piezas:

| Archivo | Qué hace |
|---|---|
| `android/app/build.gradle.kts` | Lee `MAPS_API_KEY` de `local.properties`, con `System.getenv` de respaldo para CI y cadena vacía como último recurso |
| `android/app/src/main/AndroidManifest.xml` | `<meta-data com.google.android.geo.API_KEY>` leyendo del placeholder |
| `android/local.properties.example` | Plantilla, gemela de `Secrets.example.xcconfig` |

**La cadena vacía de respaldo no es descuido:** un `${MAPS_API_KEY}` sin valor **rompe el merge de
manifiestos**, y quien clone el repo sin la clave tiene que poder compilar.

**`minSdk` fijado a `maxOf(24, flutter.minSdkVersion)`.** `google_maps_flutter_android` exige 24;
hoy el valor por defecto de Flutter ya lo cumple, pero si una actualización lo bajara el fallo
sería un error de merge difícil de leer. Verificado con `aapt2 dump badging`: `minSdkVersion:'24'`.

Verificado en el manifiesto fusionado de la app: el placeholder resuelve a `android:value=""`
cuando no hay clave, y el APK compila en debug y release.

### ⚠️ Nota sobre la verificación en emulador

La primera tanda de pruebas se hizo en un emulador con el disco al 95 %, con instalaciones
fallidas y sesiones de instalación abandonadas acumulándose. En ese estado **la app mostró una
pantalla de inicio sin el acceso a Transporte**, lo que llevó a sospechar que los `--dart-define`
rompían los `defaultValue` de otros flags en AOT.

**Esa sospecha era falsa.** Se descartó por dos vías:

1. Compilando el patrón exacto (`bool.fromEnvironment` con `defaultValue` dentro de un `if` de
   colección constante) con `dart compile exe`: idéntico en JIT y AOT, con y sin defines ajenos.
2. Repitiendo la prueba en un emulador limpio (`ovum_verify`): **el acceso aparece con
   normalidad** en build de release.

Era un APK obsoleto corriendo en un emulador degradado. Se deja anotado porque el falso positivo
costó tiempo: **antes de perseguir una anomalía, comprobar el espacio en disco del emulador.**

## 5. Prueba de regresión

Lo que hay que comprobar antes de dar el spike por bueno:

- [x] `flutter analyze` limpio
- [x] `flutter build ios --simulator --debug` pasa
- [x] La app arranca y la navegación existente sigue funcionando
- [x] La pantalla de Transporte (sin mapa) sigue igual
- [x] Abrir una pantalla con mapa **no cierra la app** (con el flag apagado)
- [x] `flutter test` sigue en verde — **194 tests**
- [x] `flutter build ios --release --no-codesign` pasa — `103,3 s`, **46,4 MB**
- [x] **Android**: APK debug y release compilan; `minSdkVersion:'24'` confirmado en el APK
- [x] **Android**: la app arranca y abrir un mapa sin clave **no la cierra** (mapa gris)
- [ ] Build de release **firmada** en un iPhone físico ← no se puede hacer desde aquí

> **Tamaño:** la app de release pesa 46,4 MB con el SDK de Google Maps dentro. Conviene
> contrastarlo con el peso de `main` antes de decidir: iOS avisa al usuario cuando una descarga
> por datos móviles supera cierto umbral, y muchos asistentes instalarán la app al llegar al
> recinto, sin WiFi.

---

## 6. Recomendación

**El spike pasa, pero con 24 días para el congreso la recomendación es no meter el mapa embebido
en la release de OVUM 2026.** Razones, en orden:

1. **El bloqueante real no es técnico, es la cuenta de Google.** Sin clave el mapa sale gris, y la
   cuenta sigue sin decidirse. Enviar a las tiendas una pantalla con un rectángulo gris es peor que
   no tenerla.
2. **Ancla la versión de Flutter** (§3) justo cuando el proyecto está peleando con App Store por
   otros motivos.
3. **El valor marginal es bajo.** La pantalla de Transporte ya resuelve lo que pregunta el
   asistente —qué rutas hay, dónde paran, a qué hora salen— y el botón "Cómo llegar" abre Google
   Maps con tráfico y tiempo reales. El mapa embebido es más bonito, no más útil.
4. El trabajo ya está hecho y la rama queda lista: **activarlo después es cambiar una línea del
   xcconfig y hacer merge**, no reabrir el problema.

**Si aun así se decide incluirlo**, el orden es: conseguir la clave primero, verificar que el mapa
renderiza en un iPhone físico con build de release firmada, y solo entonces integrar el mapa en la
pantalla de ruta.

---

## 7. Cómo deshacer esto

Si hay que volver a SPM puro:

```bash
git switch main                      # la rama de spike no está mergeada
```

Y si ya se hubiera mergeado:

```bash
flutter config --no-enable-swift-package-manager   # CocoaPods puro (más rodado)
flutter clean
rm -rf ios/Flutter/ephemeral ios/.symlinks
cd ios && pod install --repo-update
```

---

## 8. Archivos de esta rama

**Nuevos**
```
ios/Podfile                                        generado por Flutter
ios/Podfile.lock                                   commitear: builds reproducibles
ios/Flutter/Secrets.example.xcconfig               plantilla
android/local.properties.example                  plantilla (Android)
docs/MAPS-API-KEY.md                              cómo conseguir las claves
lib/features/transport/widgets/map_spike_screen.dart   TEMPORAL: borrar al cerrar
docs/SPIKE-IOS-MAPS.md                             este documento
```

**Modificados**
```
pubspec.yaml / pubspec.lock        +google_maps_flutter ^2.18.0
lib/core/config/app_config.dart    +useEmbeddedMap (apagado por defecto)
android/app/build.gradle.kts       +MAPS_API_KEY, minSdk 24
android/app/src/main/AndroidManifest.xml  +meta-data geo.API_KEY
ios/Runner.xcodeproj/project.pbxproj   +114 líneas (CocoaPods)
ios/Runner/AppDelegate.swift       +GMSServices.provideAPIKey()
ios/Runner/Info.plist              +GMSApiKey
ios/Flutter/{Debug,Release}.xcconfig   +#include? Secrets
ios/.gitignore                     +Flutter/Secrets.xcconfig
lib/core/router/app_router.dart    TEMPORAL: ruta /_spike/map
```

**No commitear nunca:** `ios/Flutter/Secrets.xcconfig` (ya está en `.gitignore`).
