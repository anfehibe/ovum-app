# Estado app ↔ API — OVUM 2026

**Actualizado:** 17 de septiembre de 2026
**Backend:** `main` @ `75a20a3` · **App:** rama `main` con cambios sin commitear
**Entorno:** producción (`https://trivvo.events/api/v1`), tenant `anavi`, congreso `94`

Tres secciones que no hay que confundir: lo que falta **en el API**, lo que falta **en la app**, y
lo que falta **cargar en producción**. Al final, el historial de lo ya resuelto.

> **Verificación:** no hay PHP ni acceso a la base en la máquina donde se revisa esto. **[comprobado]**
> = visto fallar contra producción o leído directamente del código. **[hipótesis]** = deducción que
> alguien debe confirmar ejecutándola. Los números de línea son los de `75a20a3`.
>
> ⚠️ **Mergeado ≠ desplegado.** El repo va por delante de producción. Desplegado y verificado contra
> prod: hasta `2723473`. **`75a20a3` (disponibilidad + validación estricta al solicitar) está en
> revisión, sin aprobar ni desplegar** — todo lo que dependa de ese commit está marcado abajo.

---

## 🔵 Falta en el API

Ya no queda ningún bloqueante. Lo que sigue es higiene con consecuencias silenciosas.

### A1. `google/auth` no está declarada en `composer.json`

**[comprobado]** `FcmSender` hace `use Google\Auth\Credentials\ServiceAccountCredentials` y funciona
— entra **transitiva** por otra dependencia. Un `composer update` de ese otro paquete puede quitarla
y **el push se caería en silencio**: sin credencial, `FcmSender` devuelve `skipped` sin lanzar. Nadie
se entera. Conviene fijarla explícita.

### A2. Correo y push son síncronos dentro del request

**[comprobado]** `Mail::...->send()` y `pushAUsuario()` bloquean el `POST /messages/{user}`. Lo
correcto sería que ambos fueran a cola (`ShouldQueue`). No es urgente con el volumen actual, pero en
los días del congreso se va a notar.

### A3. `POST /logout` y los tokens huérfanos

**[comprobado]** La app llama a `DELETE /me/device-token` antes de limpiar el Bearer, así que el
camino feliz queda limpio. Pero si la app se desinstala o el logout falla a medias, el token queda
huérfano. `FcmSender` ya purga los que FCM reporta como muertos, lo que mitiga el problema pero no
lo cierra.

### A4. Etiquetas de nivel de patrocinador sin normalizar

**[comprobado]** 29 patrocinadores con **8 etiquetas distintas**, varias mal escritas. La app ya lo
absorbe (`SponsorTier` normaliza, ordena y conserva la etiqueta desconocida en vez de descartarla),
pero limpiarlo en origen evita que cada consumidor tenga que adivinar.

### A5. Falta `PUT /me` — el perfil general no se puede guardar

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

**Mientras no exista**, la app tiene dos salidas y ninguna es buena: quitar la pantalla (el perfil de
networking ya edita campos parecidos y sí persiste) o dejarla marcada como solo-local y quitarle el
toast de éxito. **Decisión pendiente del lado de la app.**

---

## 🟠 Falta en la app

### B1. `GET /networking/availability` no se consume — el hueco con más impacto

> 🚧 **Bloqueado por despliegue.** El endpoint existe en `75a20a3`, **en revisión y sin desplegar**.
> Hasta que salga a producción, conectarlo desde la app no se puede ni probar. Lo que sigue describe
> el trabajo que quedará listo para hacer en cuanto se apruebe.

**[comprobado en el código, NO en producción]** El backend expone
`GET /events/{id}/networking/availability?fecha&periodo&user`
(`API/V1/NetworkingController.php:214`), que devuelve `{fecha, periodo, origen, espacio_abierto,
slots}` calculados contra los `horarios` y `mesas` reales del congreso — y con `?user={id}` incluye
**la ocupación del otro asistente**.

**La app no lo llama nunca.** `features/networking/new_meeting_screen.dart` se inventa la rejilla:
`MeetingHours` hardcodea 08:00–18:00 en pasos de 30 min (`lib/core/utils/meeting_slots.dart`) y
`slotStates` solo cruza **mis** reuniones.

Dos consecuencias reales:

1. Se puede solicitar una reunión a una hora en la que la otra persona ya está ocupada. El backend
   la rechazará o la aceptará mal, pero el usuario no se entera al elegir.
2. La rejilla no refleja los horarios ni las sedes que configuró el organizador. Si las filas de
   `horarios` no cubren 08:00–18:00, la app ofrece horas que no existen.

**Trabajo (cuando se despliegue):** mapper + método en `NetworkingService`, y sustituir
`meetingSlots()`/`slotStates()` por la respuesta del servidor, dejando la rejilla local como respaldo
si el endpoint falla o devuelve 404 — que es exactamente lo que hará mientras no esté desplegado.

**Compatibilidad ya comprobada:** ese mismo commit endurece la validación de `requestMeeting`
(rejilla de 30 min por regex, `hora_fin > hora_inicio`, fecha dentro del congreso, y solapamiento del
remitente). Lo que la app manda hoy **pasa esas reglas**: `apiDate()` produce `Y-m-d` dentro del
congreso y `MeetingHours` trabaja en pasos de 30 min, así que `hora_inicio`/`hora_fin` siempre caen
en `:00`/`:30`. El despliegue no debería romper la pantalla actual.

### B2. `AttendeesScreen` es una pantalla huérfana

**[comprobado]** La ruta `/attendees` está registrada (`lib/core/router/app_router.dart:113`) pero
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

| Recurso | Estado | Qué desbloquea |
|---|---|---|
| `polls` | **0** | La tarjeta "Encuesta en vivo" de la ficha de sesión |
| `features.qa` | **0 de 60** sesiones | La tarjeta "Preguntas en vivo" |
| `other-activities` | 0 | La pantalla de otras actividades |
| `content/*` | 0 | Info, organizadores, expositores |
| Ponentes | sin bio, foto ni redes | La ficha de ponente se ve pelada |
| `horarios` / `mesas` | **sin confirmar** | Sin filas, toda reunión aceptada sale con `mesa: 0` |

> **Esto responde a "no veo polls en la app".** Polls está implementado de punta a punta — modelo,
> mapper, providers, pantalla, ruta y el `POST /polls/{id}/vote`. El acceso está en la ficha de
> sesión y solo se pinta si esa sesión tiene encuestas. Como `GET /events/94/polls` devuelve 0, no
> aparece nunca. **No hay nada que programar; hay que crear una encuesta.**

**[hipótesis] Pregunta abierta a operaciones:** ¿existen filas en `horarios` para el congreso 94 los
días 11–13 de noviembre de 2026, y en qué ventana? La app asume 08:00–18:00. Si no están cargadas,
`autoAsignarMesa` cae siempre al espacio abierto.

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
| 10 | Sin disponibilidad real de horas | ⚠️ **Escrito, NO desplegado.** `75a20a3` añade el endpoint `availability`, el servicio `DisponibilidadReuniones` y la validación al crear (rejilla de 30 min por regex, `hora_fin > hora_inicio`, fechas dentro del congreso, solapamiento del remitente). **En revisión** — no cuenta como cerrado hasta que salga a prod. Ver B1 |

---

## Resumen para priorizar

| Dónde | Asunto | Impacto |
|---|---|---|
| **Backend** | Aprobar y desplegar `75a20a3` | Desbloquea B1; hoy el endpoint no responde en prod |
| **App** | B1 · conectar `availability` *(bloqueado)* | Se pueden pedir horas ocupadas del otro; la rejilla es inventada |
| **Prod** | Crear encuestas y activar `features.qa` | Dos funciones completas hoy invisibles |
| **Prod** | Confirmar `horarios`/`mesas` | Sin ellas, ninguna reunión recibe mesa |
| **App** | B4 · fallback mudo al mock | Puede mostrar datos de demo como reales |
| **API** | **A5 · `PUT /me`** | Sin él, el editor de perfil general miente al usuario |
| **API** | A1 · fijar `google/auth` | Si se cae, el push muere en silencio |
| **App** | B2, B3 · código muerto | Sin impacto en usuario; deuda |
| **API** | A2, A3, A4 | Sin impacto visible hoy |
