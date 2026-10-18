# Estado app ↔ API — OVUM 2026

**Actualizado:** 17 de octubre de 2026 — respuesta del backend del 16-oct verificada: A6, A2 y
`horarios`/`mesas` resueltos (ver cada sección)
**Backend:** `main` @ `cb24d81` · **App:** `main` @ `e6737b3` + editar/cancelar reuniones y Crashlytics (sin commit)
**Entorno:** producción (`https://trivvo.events/api/v1`), tenant `anavi`, congreso `94`

> 📱 **App Store:** lo que necesitaba el backend para la revisión de Apple está en
> [`API-APP-STORE.md`](API-APP-STORE.md) y **ya está resuelto**: `DELETE /me` desplegado (sonda sin
> token → 401, re-comprobado el 2026-10-16) y la app lo usa (`5306b73`); las cuentas demo existen
> (Bruno Demo sale en el directorio). **No reenviar.** Lo que queda abierto con Apple es de App Store
> Connect (clasificación por edad), no del backend.

Tres secciones que no hay que confundir: lo que falta **en el API**, lo que falta **en la app**, y
lo que falta **cargar en producción**. Al final, el historial de lo ya resuelto.

> **Verificación:** no hay PHP ni acceso a la base en la máquina donde se revisa esto. **[comprobado]**
> = visto fallar contra producción o leído directamente del código. **[hipótesis]** = deducción que
> alguien debe confirmar ejecutándola. Los números de línea son los de `e1cecb8`.
>
> ⚠️ **Mergeado ≠ desplegado** — el aviso sigue vigente como método, aunque hoy no haya desfase.
> **Re-comprobado el 2026-10-07 con sondas sin token** (401 = la ruta existe; 404/405 = no desplegada;
> control público `GET /sponsors` → 200): `availability`, `PUT /me`, `DELETE /me` y `/me/registrations`
> responden **401**. Todo en producción. Antes de dar por vivo un endpoint nuevo, repite la sonda;
> leer `routes/api.php` no prueba nada.
>
> 📌 **`fd5d24a..cb24d81` (16 oct) sí toca el API del app:** `cd34590`/`93e034b` (tenant de
> `horarios`/`mesas`), `0884bec` (A6), `e3c5223` (A2), `f447cf5` (worker de cola) y `cb24d81`
> (reintentos y deploy sin `config:cache`). Revisados uno a uno abajo.
>
> 📌 **Los commits del backend entre `bced0b4` y `fd5d24a` (7 – 16 oct) no tocan el API del app.**
> Son la integración InContacto/K-PASS (webhook `POST /webhooks/incontacto/registro`, lectura
> `GET /eventos/{id}/inscritos` para sistemas externos, importador de asistentes, correo de activación)
> y el rediseño web del directorio. Ningún endpoint de `/events/{id}/…`, `/me` ni networking cambió, así
> que **nada de A1–A5 se resolvió de paso**.

---

## 🔵 Falta en el API

**Al 17-oct solo queda A1** (el dev lo hará luego; no bloquea). A2 y A6 se entregaron el 16-oct y están
verificados; A3, A4 y A5 ya estaban cerrados. **No reenviar nada salvo A1** y las dos observaciones
menores de la revisión de A6 (ver A6).

### A1. `google/auth` no está declarada en `composer.json`

**[re-comprobado 2026-10-16 @ `fd5d24a` — SIGUE ABIERTO]** `FcmSender` hace `use Google\Auth\Credentials\ServiceAccountCredentials` y funciona
— entra **transitiva** por otra dependencia. Un `composer update` de ese otro paquete puede quitarla
y **el push se caería en silencio**: sin credencial, `FcmSender` devuelve `skipped` sin lanzar. Nadie
se entera. Conviene fijarla explícita.

### A2. ~~Correo y push son síncronos dentro del request~~ — ✅ RESUELTO (`e3c5223`, 16-oct)

> **Revisado en código @ `cb24d81`.** Los cinco mailables de networking (`MensajeMail`, `ReunionMail`,
> `ReunionAprobadaMail`, `ReunionRechazadaMail` y el nuevo `ReunionCanceladaMail`) implementan
> `ShouldQueue`, y `pushAUsuario()` ahora despacha el job `App\Jobs\EnviarPush`. Tablas
> `jobs`/`failed_jobs` creadas y worker con supervisor en `deploy/trivvo-worker.conf` (`f447cf5`).
> **Hoy `QUEUE_CONNECTION=sync`**: siguen saliendo dentro del request, igual que antes, hasta que
> monten el worker. Comprobado que el `TenantScope` no filtra sin request (solo aplica si hay
> `currentTenantId`), así que los jobs podrán recargar `Reunion`/`DeviceToken` desde el worker.
> Detalle menor, sin impacto: `EnviarPush` atrapa toda excepción, así que su `$tries = 3` nunca
> reintenta.
>
> Lo que sigue es el diagnóstico original.

**[re-comprobado 2026-10-16 @ `fd5d24a` — entonces SEGUÍA ABIERTO]** `Mail::...->send()` y `pushAUsuario()`
bloquean el `POST /messages/{user}`, y lo mismo pasa al solicitar, aceptar y rechazar reuniones:
`MensajeMail`, `ReunionMail`, `ReunionAprobadaMail` y `ReunionRechazadaMail` extienden `Mailable` a
secas, y `pushAUsuario()` llama a `FcmSender` dentro del request. Lo correcto sería que ambos fueran a
cola (`ShouldQueue`). **Si se hace junto con A6**, que el `ReunionCanceladaMail` nuevo nazca ya en cola.

⚠️ **Cuidado al verificarlo:** `app/Mail/MensajeMail.php` **importa** `ShouldQueue` pero la clase es
`class MensajeMail extends Mailable` **a secas** — no lo implementa. El `use` viene del fork inicial
(`a42382e`), así que un `grep ShouldQueue` da falso positivo. Comprueba la declaración de la clase, no
el import.

### A3. ~~`POST /logout` y los tokens huérfanos~~ — ✅ RESUELTO

**[comprobado 2026-09-24]** `AuthController@logout` ahora borra los device tokens del usuario junto
con el `api_token`. Sumado a la purga de tokens muertos que ya hacía `FcmSender`, el problema queda
cerrado.

### A4. ~~Etiquetas de nivel de patrocinador sin normalizar~~ — ✅ NO HACE FALTA PEDIRLO

**[comprobado 2026-10-16 contra producción]** Los 29 patrocinadores usan **8 etiquetas limpias**, sin
erratas, espacios ni mayúsculas mezcladas: Diamante (4), Platino (5), Oro (5), Plata (3), Bronce (2),
Media Partner (8), Internet Oficial (1) y Línea Aérea Oficial (1). Son categorías reales, no variantes
de la misma. La app ya las agrupa y ordena (`SponsorTier`), así que no queda nada que pedir. Lo único
que faltaría es una clave u orden estable en el API (`nivel` es el texto libre de `$p->level`), y solo
importa si otro cliente necesita ordenarlos.

### A5. ~~Falta `PUT /me`~~ — ✅ RESUELTO, con tres trampas que la app esquiva

> **Entregado en `c89d2b7` y desplegado** (sonda sin token → 401, 2026-09-24). Respeta lo que se
> pidió: excluye `sector`/`intereses`, usa `updateOrCreate` sobre `perfiles`, y **añadió `bio` y
> `linkedin` a `userPayload()`** — que era la objeción del review, porque sin eso la app no podría
> leer lo que acaba de escribir.
>
> ✅ **La app ya lo usa desde el 2026-09-24**: "Editar perfil" vuelve a estar visible en Perfil y
> guarda contra el servidor. `profileUpdateBody()` (pura y testeada) implementa las tres
> protecciones de abajo.
>
> ⚠️ **Tres trampas, confirmadas contra el esquema y re-comprobadas el 2026-10-16 @ `fd5d24a`
> (siguen igual en `AuthController::updateMe`)** (detalle en
> [`API-APP-STORE.md` §7](API-APP-STORE.md)). **No bloquean a la app: se protege ella**, pero conviene
> cerrarlas en origen porque cualquier otro cliente tropezará:
> 1. `users.nombre`, `users.apellido`, `perfiles.empresa` y `perfiles.cargo` son **NOT NULL** y
>    `ConvertEmptyStringsToNull` está activo (`Kernel.php:20`): mandar `""` llega como `null` y
>    revienta en **500**. → La app omite esas claves del body si quedan vacías.
> 2. `bio` se valida `max:2000` contra una columna **`varchar(400)`**. → La app recorta a 400.
> 3. `Perfil::updateOrCreate` con un usuario sin fila en `perfiles` intentaría crearla sin `empresa`
>    ni `cargo`, que son NOT NULL sin default.
>
> Lo que sigue es el diagnóstico original, que explica por qué se pidió.

**[comprobado]** No existe ningún endpoint para escribir el perfil del usuario. En `/me` solo hay
`GET /me`, `POST /logout`, `GET /me/registrations` y el par `POST`/`DELETE /me/device-token`. El
único perfil escribible es el de networking (`PUT /events/{id}/networking/me`).

**Qué provoca hoy en la app:** `ProfileEditScreen` (`lib/features/profile/profile_edit_screen.dart`)
ofrece seis campos y, al guardar, muestra *"Perfil actualizado"* — pero `updateUser()` solo escribe
en `shared_preferences` (`user_provider.dart:152`). Peor: al iniciar sesión, `login()` hace
`_persist(result.user)` (`:100`) con lo que devuelve el servidor y **machaca lo editado**. El usuario
corrige su cargo, ve el toast de éxito, vuelve a entrar y está como antes. Es un editor que miente.

**Lo que se pide:** `PUT /events/.../me` no; basta un **`PUT /me`** simétrico al `GET /me` que ya
existe, escribiendo sobre `users` y `perfiles`.

```
PUT /api/v1/me          (auth:api)
Body — todos opcionales, se escribe solo lo que llega:
  { "nombre", "apellido", "empresa", "cargo", "movil", "ciudad", "bio", "linkedin" }
```

- Devolver **el mismo `userPayload()` del `GET /me`** para que la app refresque con la respuesta y no
  tenga que adivinar qué quedó guardado. Hoy ese payload no incluye `bio` ni `linkedin`; si se aceptan
  en la escritura, conviene añadirlos también a la lectura.
- **`email` no debe ser editable** — es la identidad de login. Tampoco `id`, `tenant_id` ni `pais_id`
  (este último es un catálogo; si se quiere, que vaya aparte).
- **Ojo con el solape:** `sector` e `intereses` viven en `perfiles` pero **ya los escribe**
  `PUT /events/{id}/networking/me` (`NetworkingController::saveMe`, que los guarda como string
  separado por comas y aplica los topes de `NetworkingVocab`). **`PUT /me` no debería tocarlos**, o
  habrá dos endpoints peleándose por las mismas columnas con formatos distintos.
- Precedente de validación: el propio `saveMe` (`:82-90`). Mismo estilo: `nullable` + `string` +
  `max`, y `perfil` con `updateOrCreate` por si el usuario todavía no tiene fila en `perfiles`.

~~**Mientras no exista**, la app tiene dos salidas y ninguna es buena…~~ — **resuelto**: el endpoint
existe y la app lo usa desde el 2026-09-24 (ver el recuadro de arriba). Ya no hay decisión pendiente.

### A6. ~~Editar y cancelar reuniones~~ — ✅ DESPLEGADO (`0884bec`, 16-oct)

> **Verificado el 2026-10-17.** Sondas sin token: `PUT …/meetings/{id}` → **401** (antes 405) y
> `POST …/meetings/{id}/cancel` → **401** (antes 404). Revisado el código: rutas, `updateMeeting`,
> `cancelMeeting`, `meetingPayload()` con `cancelacion`, `availability?exclude`, el 422 "Esta reunión
> fue cancelada." en `respond`, borrado de `mesas` al mover o cancelar, y push + `ReunionCanceladaMail`
> solo si estaba confirmada. **Coincide con el contrato de abajo.** La app ya lo usa
> (`OVUM_MEETING_EDITS` encendido por defecto).
>
> **✅ Prueba punta a punta hecha el 2026-10-17** (simulador, Alfredo Cubillos como destinatario de una
> solicitud de Bruno Salas, reunión `10625`, 11 nov 08:30):
> - **Aceptar** → 200, `mesa: 1`, `asignacion: "mesa"`: "Reunión confirmada. Mesa 1 · Area de
>   Networking" (antes del arreglo de `horarios` habría salido "Mesa por asignar").
> - **Cancelar como destinatario** → 200, `estatus: 0`; tras el refetch la tarjeta muestra "Cancelada" y
>   **"Cancelada por ti hoy a las 20:46"**, y los contadores de recibidas/confirmadas bajan a 0.
> - **La mesa se libera:** el slot de las 08:30 volvió a `libre` con 200 mesas, igual que antes de
>   aceptar.
> - **Sin verificar desde aquí:** el push y el `ReunionCanceladaMail` a Bruno Salas (hay que mirar su
>   correo o su teléfono) y la edición de una reunión confirmada.
>
> **Dos observaciones menores para el dev (no bloquean):**
> 1. **La migración `2026_10_16_010000_reuniones_cancelacion.php` crea `cancelada_por` como
>    `unsignedBigInteger` con FK a `users.id`, que es `int unsigned`.** Todas las demás FK a `users`
>    del esquema usan `int`, y MySQL rechaza una FK entre tipos distintos. **Las columnas sí existen en
>    producción** (cancelar una confirmada funcionó y devolvió quién y cuándo), así que lo único dudoso
>    es si la FK quedó creada; vale la pena mirar `SHOW CREATE TABLE reuniones` y que la migración
>    figure como corrida en `migrate:status`.
> 2. `updateMeeting` hace `$reunion->mensaje = $data['mensaje'] ?? $reunion->mensaje`: con
>    `ConvertEmptyStringsToNull`, mandar `""` llega como `null` y **la nota no se puede borrar**. Hoy da
>    igual (la nota está oculta en la app por App Store 1.2).
>
> Lo que sigue es el pedido original.

**[comprobado 2026-10-16, backend `2a4f232`]** Una invitación enviada desde la app **no se puede
editar ni cancelar**. Las únicas rutas de reuniones son `availability`, `GET meetings`,
`POST meetings/{user}` y `POST meetings/{reunion}/respond` (`routes/api.php:69-72`), y `respond` solo
admite `accept|reject` y solo para el destinatario. `docs/API.md:342` ya lo lista como pendiente
("Reprogramar una reunión desde el app"). El panel web sí tiene `Web\ReunionController@update`
(`:372`) y `@reagendar` (`:779`), que sirven de referencia; **no** hay cancelación en ningún lado.

**La app ya está programada contra este contrato** y esconde los botones con
`--dart-define=OVUM_MEETING_EDITS=false` mientras no esté desplegado. Antes de darlo por vivo, sonda
sin token: 401 = existe, 404/405 = no desplegado.

**Reglas de negocio acordadas:**
- Se pueden editar y cancelar las reuniones **pendientes y confirmadas** que no hayan empezado.
- Editar es solo para el **remitente**. Cancelar lo puede hacer el remitente (pendiente o
  confirmada) y el **destinatario solo si ya la aceptó**; la pendiente la sigue rechazando con
  `respond`.
- Si se cambia el horario de una **confirmada**, vuelve a **Pendiente**, se libera la mesa y el
  destinatario tiene que aceptarla de nuevo (igual que hace el `update` del web, que pone `estatus 1`).
- Una cancelada **no se borra**: queda con `estatus = 0` y se sigue viendo en las dos listas.
- **Solo si estaba confirmada** se registra quién la canceló y cuándo, y se avisa a la contraparte
  por push y correo. Cancelar una pendiente no avisa (solo la pudo cancelar el remitente).

#### 1. `PUT /events/{congreso}/networking/meetings/{reunion}` — editar (solo el remitente)

No choca con `POST meetings/{user}`: distinto verbo.

| Caso | Respuesta |
|---|---|
| La reunión no es de ese congreso | **404** |
| No soy el remitente | **403** "Solo quien envió la solicitud puede editarla." |
| `estatus ∉ {1, 2}` | **422** "Esta reunión ya no se puede editar." |
| `fecha + hora_inicio` ya pasó (America/Bogota) | **422** "Esta reunión ya pasó." |
| Se solapa con otra reunión mía | **422** "Ya tienes una reunión a esa hora." |

```
Body: { "fecha": "2026-11-11", "hora_inicio": "10:00", "hora_fin": "10:30", "mensaje": "…" }
```

- **Mismas reglas que `requestMeeting`** (`NetworkingController.php:287-308`): `reglasDeFecha`,
  `REJILLA`, normalizar a `H:i:s`, `hora_fin > hora_inicio`. Conviene extraer un helper para no
  duplicarlas. Errores en español (`ValidationException::withMessages`, no el genérico de Laravel).
- **Solape excluyendo la propia reunión:** `ocupado($me, $fecha, $h1, $h2, $reunion->code_meeting)`.
  El parámetro `$excluirCode` ya existe en `DisponibilidadReuniones::ocupado()`.
- **Si cambia `fecha`/`hora_inicio`/`hora_fin`:**
  `Mesa::where('reunion_id', $reunion->id)->delete()`, y `lugar_id = null`, `mesa = 0`,
  `estatus = 1`. Borrar las filas de `mesas` es obligatorio: `DisponibilidadReuniones.php:108` cuenta
  la mesa como tomada sin mirar el estatus de la reunión.
- **Si solo cambia `mensaje`:** se conservan `estatus`, `lugar_id` y `mesa`.
- **Avisos al destinatario:** push "Reunión modificada" con `data:{tipo:'reunion', id}` y
  `ReunionMail` en try/catch (si la invitación fue solo por correo, al `email`).
- **Respuesta 200:** `{ "data": <mismo item que GET /meetings>, "message": "…" }`, con
  `"Reunión actualizada."` o `"Reunión reprogramada: debe confirmarla de nuevo."`. Conviene sacar el
  `map()` de `meetings()` (`:255-273`) a un `meetingPayload($m, $me)` y usarlo en los dos sitios.

#### 2. Migración: quién canceló y cuándo

```
reuniones.cancelada_por  int unsigned NULL  (FK users.id, ON DELETE SET NULL)
reuniones.cancelada_at   timestamp    NULL
```

**Solo se llenan al cancelar una reunión que estaba confirmada** (`estatus = 2`). En una pendiente
quedan en `null`. Es exactamente la regla de cuándo mostrar "Cancelada por…", así que la app no tiene
que deducir nada. Añadir las dos columnas al `$fillable` de `Reunion`.

#### 3. `POST /events/{congreso}/networking/meetings/{reunion}/cancel` — cancelar

| Caso | Respuesta |
|---|---|
| La reunión no es de ese congreso | **404** |
| No soy remitente ni destinatario | **403** "No puedes cancelar esta reunión." |
| Soy el destinatario y está pendiente | **422** "Para una solicitud pendiente, recházala." |
| `estatus ∉ {1, 2}` | **422** "Esta reunión ya no se puede cancelar." |
| Ya pasó | **422** "Esta reunión ya pasó." |

Efecto, en este orden:
1. `$estabaConfirmada = (int) $reunion->estatus === 2`.
2. `Mesa::where('reunion_id', $reunion->id)->delete()` — sin esto **la mesa queda bloqueada para
   siempre**: `Reunion` usa `SoftDeletes`, así que el `ON DELETE CASCADE` de `mesas.reunion_id` nunca
   se dispara, y nada en `app/` borra filas de `mesas`.
3. `estatus = 0`. **No** hacer soft delete: la reunión debe seguir en `GET /meetings`.
4. Si `$estabaConfirmada`:
   - `cancelada_por = $me->id`, `cancelada_at = now()`.
   - Push a la contraparte: título "Reunión cancelada", cuerpo
     `"{quien} canceló la reunión del {fecha} a las {hora}."`, `data:{tipo:'reunion', id}`.
   - Correo a la contraparte con un Mailable nuevo, `ReunionCanceladaMail` (no existe plantilla para
     esto; las de aprobada/rechazada no sirven), en try/catch.
5. Si estaba pendiente: **ni push ni correo**.

```json
{ "data": { "id": 123, "estatus": 0, "estado": "Eliminada", "cancelacion": { … } | null },
  "message": "Reunión cancelada." }
```

#### 4. `cancelacion` en cada item de `GET /meetings` (dentro de `meetingPayload()`)

```json
"cancelacion": null
"cancelacion": { "por": { "id": 45, "nombre": "Andres Higuera" }, "fecha": "2026-11-10T08:00:00-05:00" }
```

Lleno solo cuando `cancelada_por` no es `null`. `fecha` en ISO-8601 con offset, como el resto.

#### 5. `respond` sobre una cancelada

Hoy cualquier `estatus != 1` responde "Esta reunión ya fue respondida." Con `estatus = 0` debe ser
**422 "Esta reunión fue cancelada."**, para que el destinatario entienda qué pasó si intenta aceptar
una pendiente que el remitente ya canceló (a esa no le llega push).

#### 6. `GET .../availability?exclude={reunionId}` — opcional pero recomendado

Si la reunión es mía (remitente o destinatario) y de ese congreso, pasar
`'excluir_code' => $reunion->code_meeting` a `paraCongreso()`, que ya soporta la opción
(`DisponibilidadReuniones.php:53`). Si no, 404. Sin esto, al editar, la reunión ocupa su propio hueco
— en mi agenda y, si estaba confirmada, también en la del otro. La app ya lo compensa localmente, pero
no puede saber si la mesa que liberaría la edición deja el slot con sitio.

---

## 🟠 Falta en la app

### B1. `GET /networking/availability` no se consume — el hueco con más impacto

> ✅ **CONECTADO el 2026-09-24.** `75a20a3` está desplegado (sonda sin token → 401) y la app ya lo
> consume: `availabilityFromJson` + `NetworkingService.availability()` +
> `meetingAvailabilityProvider`, y `new_meeting_screen` pinta la rejilla del servidor. Un hueco que
> el otro tiene ocupado sale deshabilitado con su motivo (`SlotState.otherBusy`, nuevo). **La rejilla
> local sigue de respaldo**: si el endpoint falla se cae a ella con un aviso de que las horas son
> orientativas, en vez de dejar la pantalla inservible.
>
> El diagnóstico original se conserva porque explica qué se ganó.

**[comprobado en código y desplegado]** El backend expone
`GET /events/{id}/networking/availability?fecha&periodo&user`
(`API/V1/NetworkingController.php:214`), que devuelve `{fecha, periodo, origen, espacio_abierto,
slots}` calculados contra los `horarios` y `mesas` reales del congreso — y con `?user={id}` incluye
**la ocupación del otro asistente**.

**[histórico — así estaba antes del 24 sep]** **La app no lo llama nunca.**
`features/networking/new_meeting_screen.dart` se inventa la rejilla:
`MeetingHours` hardcodea 08:00–18:00 en pasos de 30 min (`lib/core/utils/meeting_slots.dart`) y
`slotStates` solo cruza **mis** reuniones.

Dos consecuencias reales:

1. Se puede solicitar una reunión a una hora en la que la otra persona ya está ocupada. El backend
   la rechazará o la aceptará mal, pero el usuario no se entera al elegir.
2. La rejilla no refleja los horarios ni las sedes que configuró el organizador. Si las filas de
   `horarios` no cubren 08:00–18:00, la app ofrece horas que no existen.

**Trabajo:** mapper + método en `NetworkingService`, y sustituir
`meetingSlots()`/`slotStates()` por la respuesta del servidor, dejando la rejilla local como respaldo
si el endpoint falla, para no dejar la pantalla inservible sin red.

**Compatibilidad ya comprobada:** ese mismo commit endurece la validación de `requestMeeting`
(rejilla de 30 min por regex, `hora_fin > hora_inicio`, fecha dentro del congreso, y solapamiento del
remitente). Lo que la app manda hoy **pasa esas reglas**: `apiDate()` produce `Y-m-d` dentro del
congreso y `MeetingHours` trabaja en pasos de 30 min, así que `hora_inicio`/`hora_fin` siempre caen
en `:00`/`:30`. El despliegue no debería romper la pantalla actual.

### B2. `AttendeesScreen` es una pantalla huérfana

**[re-comprobado 2026-10-16 — sigue igual]** La ruta `/attendees` está registrada (`lib/core/router/app_router.dart:115`) pero
**nada en la UI navega a ella** — es la única ruta del router en esa situación, y ya lo era antes de
los cambios recientes. La sustituyó la pestaña **Directorio** de Networking. Decidir: borrarla, o
darle un punto de entrada.

### B3. `Session.hasPolls` es un campo muerto

**[comprobado]** `session_mapper.dart:115` lo fija a `false` porque el API no manda esa clave en
`features`, y **nadie lo lee**: la ficha de sesión usa `pollsForSessionProvider(...).isNotEmpty`
(`session_detail_screen.dart:38`). Borrarlo del modelo o alimentarlo de verdad.

### B4. El fallback al mock se dispara en silencio

**[comprobado]** Varios métodos de `ApiOvumRepository` caen a `MockOvumRepository` cuando no se
resuelve el id del evento, no solo cuando se apaga un flag (p. ej. `api_ovum_repository.dart:111`).
Si `GET /events?all=1` falla, la app **muestra datos de demo como si fueran reales**, sin avisar.
Debería distinguirse de un error.

### B5. Constantes del evento hardcodeadas

**[comprobado]** `lib/core/constants/ovum_event.dart` fija nombre, edición, lema, ciudad, sede,
fechas, días de agenda, organizadores, email y teléfono de contacto, web, aerolínea oficial y su
código de descuento, y hotel oficial. Parte de eso vive en `GET /events/{id}`, que la app no pide
(resuelve el evento con `GET /events?all=1`). No molesta mientras la app sea de un solo congreso,
pero es lo primero que estorba si se reutiliza.

### B6. Endpoints disponibles sin consumir (menores)

| Endpoint | Nota |
|---|---|
| `GET /me/registrations` | Diría el tipo de inscripción del asistente. Sin pantalla que lo pida hoy |
| `GET /public/events/{id}/program` · `/speakers` | Redundantes: agenda y speakers ya son públicos |
| `GET /app/splash` | Sustituido **a propósito** por `/events/{id}/splash` |

---

## 📋 Falta cargar en producción

No es código. **Las pantallas están hechas y aparecerán solas** en cuanto haya datos.

**Medido contra producción el 2026-10-16** con los endpoints públicos. **Nada ha cambiado desde el
17 de septiembre**, y el congreso es el 11 de noviembre: quedan **26 días**. Esto ya no es deuda
técnica, es la ruta crítica.

| Recurso | 17 sep | 7 oct | **16 oct** | Qué desbloquea |
|---|---|---|---|---|
| `polls` | 0 | 0 | **0** | La tarjeta "Encuesta en vivo" de la ficha de sesión |
| `features.qa` | 0/60 | 0 de 60 | **0 de 60** | La tarjeta "Preguntas en vivo" |
| `other-activities` | 0 | 0 | **0** | La pantalla de otras actividades |
| `content/organizers` | 0 | 0 | **0** | Pantalla de organizadores |
| `content/exhibitors` | 0 | 0 | **0** | Pantalla de expositores |
| `content/interest` · `phones` · `services` | 0 | 0 | **0** | Toda la pantalla de Info |
| Ponentes: bio | 0 | 0 de 50 | **0 de 50** | La ficha de ponente se ve pelada |
| Ponentes: foto | 0 | 0 de 50 | **0 de 50** (`foto: null`) | Solo se ven iniciales |
| Ponentes: redes | 0 | 0 de 50 | **0 de 50** | Sin enlaces |
| `horarios` / `mesas` | sin confirmar | sin confirmar | ❌ invisibles → **✅ 17-oct** | Las reuniones aceptadas ya reciben mesa |

> ✅ **RESUELTO el 16-oct (`cd34590` + `93e034b`).** Las filas **sí estaban cargadas**, pero con
> `tenant_id` NULL, así que el API (que filtra por tenant) no las veía. El dev rellenó el tenant y ahora
> `horarios`/`mesas` lo heredan de su lugar al crearse. **Verificado el 2026-10-17** con sesión real
> desde la app: los tres días responden **`origen: "horarios"`** con **200 mesas libres** por slot
> desde las 08:00. Lo de abajo es el diagnóstico del 16-oct.

**[histórico] `horarios`/`mesas`: ya no es una pregunta, está confirmado que faltan.** El 2026-10-16 la app pidió
`GET /networking/availability` con sesión real para los tres días (11, 12 y 13 de noviembre) y el
servidor respondió las tres veces **`origen: "abierta"`** (no hay filas en `horarios` para esa fecha) y
**`espacio_abierto: false`** (ninguna sede está configurada como espacio abierto, `mesas <= 0`). Con
eso `autoAsignarMesa` no encuentra horario ni espacio abierto y **toda reunión aceptada queda con
`asignacion: "pendiente"`**: sin lugar y con mesa 0. Hay que cargar `horarios` y `mesas` para los tres
días, o al menos marcar una sede como espacio abierto.

**Lo que sí está cargado** (y por tanto se ve bien en la app): 60 sesiones en 2 sedes, 50 de ellas con
ponentes asignados · 50 ponentes · 29 patrocinadores · 19 hoteles · 1 plano · y, nuevo desde el
7 de octubre, **el directorio de asistentes** con los inscritos importados por la integración
InContacto/K-PASS.

> **Esto responde a "no veo polls en la app".** Polls está implementado de punta a punta — modelo,
> mapper, providers, pantalla, ruta y el `POST /polls/{id}/vote`. El acceso está en la ficha de
> sesión y solo se pinta si esa sesión tiene encuestas. Como `GET /events/94/polls` devuelve 0, no
> aparece nunca. **No hay nada que programar; hay que crear una encuesta.**

~~**Pregunta abierta a operaciones:** ¿existen filas en `horarios` para el congreso 94?~~ —
**cerrada:** existían pero el API no las veía; corregido y verificado el 17-oct (ver arriba).

---

## ✅ Resuelto (historial)

Todo esto estaba en la versión anterior de este documento y el backend lo cerró en `eeaaf7a`,
`2723473` y `733fee3`.

| # | Asunto | Cómo se cerró |
|---|---|---|
| 1 | 500 al crear reunión | Migración `2026_09_16_000000_reuniones_scheduling_nullable.php`. **Verificado**: responde 200 y la reunión sale en el listado |
| 2 | 500 en el listado con invitación por correo | `card()` acepta `?User` y devuelve ficha mínima con el correo |
| 3 | `lat` sucio (`"14.60…,"`) | Accesores en el modelo `Venue` + migración de limpieza. La app conserva su parser defensivo como red |
| 4 | Push sin disparadores | `pushAUsuario()` en mensaje nuevo, solicitud de reunión y aceptar/rechazar, con `data:{tipo,id}`. **La app ya lo entiende** |
| 5 | Sin estado de leído | Columna `mensajes.leido_at` + `no_leidos` en `GET /messages`; el hilo marca leído al abrir. **Badge verificado en dispositivo** |
| 6 | Listado sin `lugar`/`mesa` | Añadidos al `map()` del listado. **Verificado**: la tarjeta confirmada muestra "Mesa por asignar" |
| 10 | Sin disponibilidad real de horas | ✅ `75a20a3` añadió el endpoint `availability`, el servicio `DisponibilidadReuniones` y la validación al crear (rejilla de 30 min por regex, `hora_fin > hora_inicio`, fechas dentro del congreso, solapamiento del remitente). **Desplegado** (sonda → 401) y **consumido por la app** desde el 2026-09-24. Ver B1 |

---

## Resumen para priorizar

| Dónde | Asunto | Impacto |
|---|---|---|
| 🔴 **Prod** | Cargar `content/*` (los 5) | **Info, organizadores y expositores salen vacíos** |
| 🔴 **Prod** | Bio y foto de los 50 ponentes | Las fichas se ven peladas |
| **App** | A6 · confirmar push/correo de cancelación y editar una confirmada | Aceptar con mesa y cancelar ya se probaron punta a punta |
| 🟠 **Prod** | Crear encuestas y activar `features.qa` | Dos funciones completas hoy invisibles |
| **App** | B4 · fallback mudo al mock | Puede mostrar datos de demo como reales |
| **API** | A1 · fijar `google/auth` | Si se cae, el push muere en silencio |
| **App** | B2, B3 · código muerto | Sin impacto en usuario; deuda |
| **API** | Montar el worker de cola (`QUEUE_CONNECTION`) | A2 ya está en código; hasta entonces sale inline |

> **Ya cerrado — no reenviar:** A2 (correo y push a cola), A3 (logout borra device tokens), A4 (los
> niveles de patrocinador ya llegan limpios), A5 (`PUT /me`, con la app usándolo y protegida de sus tres
> trampas), A6 (editar y cancelar, desplegado), `horarios`/`mesas` (ya visibles), B1 (`availability`
> conectado), lo del App Store (`DELETE /me` y cuentas demo) y los puntos del historial.
>
> **Para el dev del backend solo queda:** A1, más las dos observaciones menores de A6 (tipo de
> `cancelada_por` y nota que no se puede borrar). Lo de 🔴/🟠 **Prod** es carga de contenido
> (operaciones), no código: según el backend, ya están en ello.
