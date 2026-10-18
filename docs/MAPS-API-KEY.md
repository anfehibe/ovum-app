# Cómo conseguir las claves de Google Maps

**Para:** quien administre la cuenta de Google del congreso.
**Tiempo:** ~20 minutos, de los cuales 5 son esperar a que Google propague la clave.
**Prerrequisito que no podemos evitar:** una **tarjeta de crédito**. Sin facturación activa, el
mapa se renderiza vacío aunque el consumo real sea de céntimos.

> Esto lo tiene que hacer una persona: crear cuentas, aceptar términos y registrar una tarjeta
> no son cosas que podamos hacer nosotros por ti. Abajo está cada clic, y todos los datos que
> Google te va a pedir ya calculados.

---

## 0. Sobre el proyecto de Google Cloud

**Actualización (18-oct):** el proyecto de Maps es **distinto** del de Firebase. No pasa nada: las
claves de Maps no tienen que convivir con Firebase. Firebase sigue en `trivvo-ovum` (push y
Crashlytics) y Maps vive en el proyecto nuevo.

La única consecuencia es operativa: **dos proyectos, dos facturas, dos sitios donde mirar el gasto
y las alertas**. Conviene que las alertas de presupuesto estén puestas en el proyecto de Maps, que
es el único de los dos que puede generar coste.

⚠️ **Verificar que en el proyecto NUEVO estén**: la facturación vinculada y las APIs de §2
habilitadas. Habilitarlas en `trivvo-ovum` por costumbre no sirve de nada si las claves son del
otro proyecto — y el síntoma sería un mapa gris sin pista evidente.

---

## 1. Activar la facturación

1. Entra en **https://console.cloud.google.com/billing** con la cuenta dueña de `trivvo-ovum`.
2. Crea una cuenta de facturación si no hay ninguna, y **vincúlala al proyecto `trivvo-ovum`**.
3. En **Presupuestos y alertas**, crea un presupuesto con aviso por correo a **$20** y a **$50**.

> **Sobre el gasto real.** Para lo que vamos a usar (mapa embebido en la app + buscador de
> direcciones en el panel) la estimación es de **menos de 5 dólares en todo el congreso**: las
> cargas de mapa en móvil no se facturan, y el cálculo de trazados son unas pocas decenas de
> llamadas. La tarjeta es un requisito de Google, no una señal de que vaya a costar dinero.
> El detalle está en `docs/TRANSPORTE.md` §7 del repo `trivvo`.

---

## 2. Habilitar las APIs

En **APIs y servicios → Biblioteca**, con el proyecto `trivvo-ovum` seleccionado, habilita:

| API | Para qué |
|---|---|
| **Maps SDK for iOS** | El mapa dentro de la app en iPhone |
| **Maps SDK for Android** | El mapa dentro de la app en Android |
| **Maps JavaScript API** | El mapa del panel de administración |
| **Places API** | El buscador de direcciones al cargar las paradas |

No habilites **Routes API** todavía: es para el cálculo de tiempos con tráfico, que es del Nivel C.

---

## 3. Crear las claves (son tres, no una)

En **APIs y servicios → Credenciales → Crear credenciales → Clave de API**, repite tres veces.
Nombra cada una como aquí, porque dentro de seis meses nadie se acordará de cuál es cuál.

### 3.1 `OVUM — Maps iOS`

- **Restricción de aplicación:** *Apps para iOS*
- **ID del paquete:**
  ```
  com.trivvo.ovum
  ```
- **Restricción de API:** solo *Maps SDK for iOS*

### 3.2 `OVUM — Maps Android`

- **Restricción de aplicación:** *Apps para Android*
- **Nombre del paquete:** `com.trivvo.ovum`
- **Huellas SHA-1:** añade **las tres** (una línea por cada una):

| Para qué | SHA-1 |
|---|---|
| Desarrollo (este equipo) | `95:F9:9E:1B:70:49:76:EC:27:A1:D8:A3:77:0C:B6:07:0A:CC:DA:FC` |
| Clave de subida (`upload-ovum.jks`) | `2F:E8:01:78:3A:72:3A:8D:19:D4:A0:5B:E0:0C:A9:CA:0D:A9:EA:F7` |
| **Firma de la app en Google Play** | ⚠️ **falta — leer §4** |

- **Restricción de API:** solo *Maps SDK for Android*

> Cada desarrollador tiene su propia huella de debug. Si otra persona compila y ve el mapa gris,
> es que falta la suya: se saca con
> `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`.

### 3.3 `OVUM — Maps Web (panel)`

- **Restricción de aplicación:** *Sitios web*
- **Referentes permitidos:**
  ```
  https://trivvo.events/*
  https://*.trivvo.events/*
  ```
- **Restricción de API:** *Maps JavaScript API* y *Places API*

---

## 4. ⚠️ La trampa que deja el mapa gris en producción

**Google Play vuelve a firmar la app.** Si el proyecto usa *Play App Signing* —y lo usa, porque el
keystore se llama `upload-ovum.jks`—, la app que se instala desde la tienda **no** está firmada
con esa clave de subida, sino con la *clave de firma de la app* que guarda Google.

Resultado si no se añade esa huella: **el mapa funciona en desarrollo y sale gris para todos los
asistentes**. Es el fallo clásico, y se descubre tarde.

**Dónde está el dato correcto:**

```
Play Console → tu app → Configuración → Integridad de la app
→ pestaña "Firma de apps"
→ "Certificado de la clave de firma de apps" → copiar la huella SHA-1
```

Esa es la tercera fila de la tabla de §3.2. **Sin ella, el mapa en Android no funciona en la
tienda.**

---

## 5. Qué hacer con las claves cuando las tengas

**No las pegues en un chat ni en el repositorio.** Mándalas por el gestor de contraseñas del
equipo, o pégalas tú directamente en los archivos de abajo.

| Clave | Dónde va | ¿Se commitea? |
|---|---|---|
| Maps iOS | `ovum-app/ios/Flutter/Secrets.xcconfig` → `GMS_API_KEY = …` | ❌ gitignored |
| Maps Android | `ovum-app/android/local.properties` → `MAPS_API_KEY=…` | ❌ gitignored |
| Maps Web | `.env` del servidor → `GOOGLE_MAPS_WEB_KEY=…` | ❌ |

El archivo de iOS ya está creado y vacío, listo para rellenar:

```bash
# desde ovum-app/
open ios/Flutter/Secrets.xcconfig
```

Lo de Android todavía no está cableado — ver §6.

---

## 6. Lo que falta de nuestro lado

Para que la clave sirva, queda trabajo en el repositorio que **no depende de ti**:

- [x] **iOS:** cadena completa de la clave (`Secrets.xcconfig` → `Info.plist` → `AppDelegate`)
- [ ] **Android:** falta el `meta-data com.google.android.geo.API_KEY` en el manifest y leer la
      clave de `local.properties`. Hoy Android **no puede** mostrar mapas aunque exista la clave.
- [ ] **Panel:** el selector de mapa para capturar las paradas (Sprint 2 del backend)
- [ ] Quitar la pantalla y el botón temporales del spike

Avísanos cuando tengas las claves y lo dejamos conectado.

---

## 7. Cómo comprobar que funcionan

Con la clave de iOS puesta en `Secrets.xcconfig`:

```bash
cd ovum-app
flutter run --dart-define=OVUM_EMBEDDED_MAP=true
```

Entra en **Transporte → icono de mapa** (arriba a la derecha):

| Lo que ves | Qué significa |
|---|---|
| Mapa con calles y un marcador en COPEREX | ✅ todo bien |
| Marco, logo de Google y marcador, **sin calles** | La clave llega pero Google la rechaza: falta facturación, falta habilitar *Maps SDK for iOS*, o la restricción de bundle id no coincide |
| El texto "Mapa embebido apagado" | Falta el `--dart-define`, no la clave |
| La app se cierra al entrar | La clave está vacía **y** el flag encendido — ver `docs/SPIKE-IOS-MAPS.md` §4 |

Si sale el segundo caso, **espera 5 minutos**: Google tarda en propagar una clave recién creada.
Si sigue igual, el motivo exacto aparece en **APIs y servicios → Métricas**, que muestra las
peticiones rechazadas y por qué.

---

## Resumen: lo que necesitamos de ti

1. Tarjeta vinculada al proyecto `trivvo-ovum` y alertas de presupuesto puestas.
2. Las cuatro APIs de §2 habilitadas.
3. Las tres claves de §3, restringidas como se indica.
4. **La huella SHA-1 de la firma de app de Play Console** (§4) — es la que más se olvida.
5. Las claves entregadas por un canal seguro, no por chat.
