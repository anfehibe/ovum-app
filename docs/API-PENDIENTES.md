# Pendientes del API TRIVVO — app OVUM 2026

**Fecha:** 16 de septiembre de 2026
**Backend revisado:** `main` @ `004bf8a`
**Entorno:** producción (`https://trivvo.events/api/v1`), tenant `anavi`, congreso `94`

Todo lo de aquí salió de integrar la app contra producción y de leer el código del backend.
Cada punto lleva la evidencia (archivo:línea) para que no haya que buscarla.

> **Nota sobre verificación:** no tengo PHP ni acceso a la base en la máquina donde revisé esto.
> Lo marcado como **[comprobado]** lo vi fallar contra producción o está leído directamente del
> código. Lo marcado como **[hipótesis]** es deducción a partir del esquema y necesita que alguien
> lo confirme ejecutándolo.
>
> **Los números de línea son los de `004bf8a` commiteado**, no los del working tree (que tiene el
> parche sin commitear del punto 4 y va 3 líneas desplazado a partir de los `use`).

---

## 🔴 Bloqueantes

### 1. `POST /networking/meetings/{user}` devuelve 500 siempre

**[comprobado]** Cualquier cuerpo, incluido el mínimo válido, responde 500. Es el único bloqueante
duro: sin poder crear una reunión desde la app, tampoco se puede probar aceptar/rechazar, así que
toda esa parte del producto está muerta.

**[hipótesis] Causa probable — columnas NOT NULL sin default.** Comparando el `Reunion::create()`
del API (`app/Http/Controllers/API/V1/NetworkingController.php:233`) con el esquema
(`database/schema/mysql-schema.sql`, tabla `reuniones`):

| Columna | Esquema | Qué hace el API |
|---|---|---|
| `fecha` | `date NOT NULL` | manda **`null` explícito** cuando el cliente la omite |
| `hora_inicio` | `time NOT NULL` | manda **`null` explícito** |
| `hora_fin` | `time NOT NULL` | manda **`null` explícito** |
| `confirmacion` | `varchar(191) NOT NULL` (sin default) | **no la manda** |
| `lugar_id` | `int unsigned NOT NULL` (sin default) | **no la manda** |

Sospecho que el disparador principal son las tres primeras: el API las declara opcionales en el
`validate()` (`:226-232`) y luego hace `'fecha' => $data['fecha'] ?? null`. La app, en consecuencia,
las omite (`networking_service.dart:137`), así que llega `null` a tres columnas `NOT NULL`. Un INSERT
de una sola fila con `NULL` explícito en `NOT NULL` falla en MySQL **aunque el modo estricto esté
apagado**, así que esto reventaría en cualquier configuración.

**Detalle raro que conviene mirar:** el flujo web que sí funciona
(`app/Http/Controllers/Web/ReunionController.php:226`) sí manda `confirmacion`, `code_meeting` y
`mesa`… pero **tampoco manda `lugar_id`**, que es `NOT NULL` sin default. O la tabla en producción
difiere del esquema commiteado, o ese camino también fallaría en modo estricto. Vale la pena
confirmarlo antes de arreglar, porque cambia la solución.

**Qué esperaría la app:** que `fecha`/`hora_inicio`/`hora_fin` sean opcionales de verdad (una
solicitud "sin hora" es el caso normal: se pide la reunión y luego se cuadra), o que el contrato
diga que son obligatorias y la app las pida en el formulario. Cualquiera de las dos sirve — pero
hoy el contrato dice "opcional" y el código no lo soporta.

---

## 🟠 Errores latentes

### 2. `GET /networking/meetings` puede dar 500 con invitaciones solo-por-correo

**[comprobado en el código]** El listado hace
`card($m->remitente_id === $me ? $m->destinatario : $m->remitente)`
(`API/V1/NetworkingController.php:207`), pero `card()` está tipado como
`private function card(User $u, ...)` (`:526`) — **no acepta null**.

En el esquema, `reuniones.destinatario_id` es `int unsigned DEFAULT NULL` y existe una columna
`email` justo al lado: el modelo admite invitar a alguien que todavía no tiene cuenta. En cuanto
una de esas reuniones caiga en el listado de un usuario, `card(null)` lanza `TypeError` → 500, y se
cae **toda la pestaña de Reuniones**, no solo esa fila.

**Sugerencia:** `?User $u` con un retorno mínimo (`['id' => null, 'nombre' => $m->email]`) o filtrar
esas reuniones del listado del API.

### 3. `lat` llega como string con coma final

**[comprobado]** El endpoint de sedes devuelve, por ejemplo, `"lat": "14.609184161164723,"` — string,
con una coma pegada al final. Parsearlo como número lanza, y tumbaba la pantalla de Sedes con un
error genérico.

En la app ya está workaroundeado con un parser defensivo, pero **es dato sucio en origen**: conviene
limpiarlo en la base y castearlo a `float` en el modelo, porque cualquier otro consumidor va a
tropezar igual.

---

## 🟡 Huecos funcionales

### 4. El push no tiene disparadores automáticos

**[comprobado]** `FcmSender` ya está migrado a FCM HTTP v1 y funciona. Pero tiene **un único call
site**: `Admin/PushController::send()` (`:67`), el envío manual del panel, con `data: ['origen' =>
'panel']`.

Los eventos que deberían notificar solos solo mandan correo:

| Evento | Dónde | Qué hace hoy |
|---|---|---|
| Mensaje nuevo | `API/V1/NetworkingController.php:385` | solo `MensajeMail` |
| Reunión aceptada/rechazada | `API/V1/NetworkingController.php:447` (dentro de `notificarReunion`, `:441`) | solo `ReunionAprobadaMail` / `ReunionRechazadaMail` |
| Nueva solicitud de reunión | `requestMeeting` | nada (y además da 500, ver punto 1) |

**Por qué importa:** una app cerrada no puede consultar nada. Hoy el chat depende de un polling cada
15 s que además **solo corre con el hilo abierto**. Sin push, un mensaje recibido no se entera nadie
hasta que el usuario entra a esa conversación a mano.

**La app ya está lista:** entiende `data: {tipo, id}` y con eso navega al destino, refresca el hilo
abierto al instante e invalida la bandeja. Solo falta que el backend lo mande.

**Payload que espera la app:**

```json
{ "tipo": "chat",    "id": "<id del REMITENTE>" }   // no el id del mensaje: el hilo se abre por interlocutor
{ "tipo": "reunion", "id": "<id de la reunión>" }
```

Ojo: FCM v1 **rechaza el mensaje si algún valor de `data` no es string**. `FcmSender` ya castea,
pero conviene mandarlos ya como string.

> Hay un parche propuesto para esto (helper `pushA()` + las dos llamadas) escrito en el working tree
> del repo backend, **sin commitear**, para que lo revises antes de que entre nada. `git diff`.

### 5. No hay estado de leído en mensajes

**[comprobado]** `GET /messages` devuelve `total`, que es el **histórico** de la conversación, no los
pendientes. No hay ningún `leido_at` ni equivalente.

Consecuencia: la app **no puede mostrar un badge de no leídos**, que es lo primero que cualquiera
espera de una bandeja. Hoy está deliberadamente sin badge porque cualquier contador estaría mal
desde el primer render.

**Sugerencia:** columna `leido_at` en `mensajes` + un contador en la respuesta de `GET /messages`, y
un `POST /messages/{user}/read` (o marcar al abrir el hilo).

### 6. `GET /networking/meetings` no expone `lugar` ni `mesa`

**[comprobado]** El `respond` sí los devuelve al aceptar, pero el listado no los incluye
(`API/V1/NetworkingController.php:202-213`). Resultado: la app puede decir la mesa asignada en el
SnackBar del momento, pero al volver a entrar la tarjeta de la reunión confirmada ya no sabe dónde
es. Añadirlos al listado.

---

## 🟢 Menores / higiene

### 7. `google/auth` no está declarada en `composer.json`

**[comprobado]** `FcmSender` hace `use Google\Auth\Credentials\ServiceAccountCredentials`, y funciona
— está entrando **transitiva** por otra dependencia. Un `composer update` de ese otro paquete puede
quitarla y **el push se caería en silencio**: sin credencial, `FcmSender` devuelve `skipped` sin
lanzar, así que nadie se entera. Conviene fijarla explícita.

### 8. `POST /logout` no borra el device token

**[comprobado]** La app llama a `DELETE /me/device-token` antes de limpiar el Bearer, así que en el
camino feliz queda limpio. Pero si la app se desinstala o el logout falla a medias, el token queda
huérfano y el usuario puede seguir recibiendo push de un congreso del que ya salió.

### 9. Correo y push son síncronos dentro del request

**[comprobado]** `Mail::...->send()` bloquea el `POST /messages/{user}`. Si se añade el push (punto 4)
se suma una llamada HTTP más a Google. Lo correcto sería que ambos fueran a cola (`ShouldQueue`).
No es urgente con el volumen actual, pero en los días del congreso sí se va a notar.

---

## 📋 Contenido vacío en producción

No es código — es que el congreso todavía no tiene datos cargados. Lo anoto porque la app tiene las
pantallas hechas y hoy se ven vacías:

| Recurso | Estado |
|---|---|
| `features.qa` | 0 de 60 sesiones con Q&A activo |
| `polls` | 0 |
| `other-activities` | 0 |
| `content/*` (los cinco) | 0 |
| Ponentes | sin bio, sin foto, sin redes |
| Sponsors | 29 cargados, pero con 8 etiquetas de nivel distintas y varias mal escritas |

Lo de sponsors ya está absorbido en la app (normaliza y ordena por nivel, y conserva la etiqueta
desconocida en vez de descartarla), pero **limpiar las etiquetas en origen** ahorraría que cada
consumidor tenga que adivinar.

---

## Resumen para priorizar

| # | Asunto | Impacto |
|---|---|---|
| 1 | 500 al crear reunión | **Bloquea toda la función de reuniones** |
| 2 | 500 en listado con invitación por correo | Tumba la pestaña entera cuando ocurra |
| 4 | Push sin disparadores | El chat no sirve como chat |
| 5 | Sin estado de leído | No hay badge de no leídos |
| 6 | Listado sin `lugar`/`mesa` | La tarjeta no dice dónde es la reunión |
| 3 | `lat` sucio | Ya workaroundeado en la app |
| 7-9 | Higiene | Sin impacto visible hoy |
