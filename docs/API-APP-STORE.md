# Backend para la revisión de App Store — OVUM 2026

**Fecha:** 24 de septiembre de 2026
**Backend:** `main` @ `2ba537b` · **App:** `main` @ `d44aa81` + los cambios de esta entrega
**Entorno:** producción (`https://trivvo.events/api/v1`), tenant `anavi`, congreso `94`

> ### ✅ Estado al 24 de septiembre, backend `e1cecb8`
>
> | § | Estado |
> |---|--------|
> | 1 | **Resuelto y desplegado** (`6efc10d`). `DELETE /me` sin token responde 401 (antes 405). Implementa todo lo pedido; comprobé que las tablas y columnas del borrado existen y admiten el valor que se les pone |
> | 2 | **Resuelto y desplegado** (`2cf6ce3` + `6efc10d`). La política dice "sus aplicaciones móviles" y tiene la sección "11. Aplicación móvil" |
> | 3 | **Comando listo, falta correrlo en producción** (`e1cecb8`, `php artisan ovum:demo-accounts`). Ver notas del §3 |
> | 6 | **Resuelto** (`6efc10d`), los cinco puntos |
> | 7 | **Nuevo:** tres riesgos de `PUT /me` (`c89d2b7`). No bloquean, porque la app todavía no lo usa |
>
> El borrado de punta a punta desde la app queda por probar con una cuenta desechable.

## Por qué existe este documento

Apple devolvió la primera versión de la app (0.7.0+7) con **Guideline 2.1 – Information Needed**.
Lo hace con todas las cuentas de desarrollador nuevas. Pide un video en un iPhone físico que muestre:
- el inicio de sesión
- **la eliminación de la cuenta** (guideline 5.1.1(v))
- si la app tiene contenido escrito por usuarios, **cómo se reporta y cómo se bloquea a alguien** (guideline 1.2)

**Decisión de producto:** en esta versión la app **oculta el chat**, **la nota de las solicitudes de
reunión** y **la bio de los asistentes**, detrás del flag `OVUM_USER_CONTENT`. Así la app queda sin
contenido escrito por usuarios y **todavía no hace falta reportar ni bloquear**. Del backend solo
bloquea el §1, más la preparación de datos del §3.

> **Verificación:** en la máquina donde se revisó esto no hay PHP ni acceso a la base. **[comprobado]**
> significa leído en el código o probado contra producción. **[hipótesis]** es una deducción que
> alguien tiene que confirmar ejecutándola. Los números de línea son de `2ba537b`.

| § | Qué | Tipo | ¿Bloquea App Store? |
|---|-----|------|---------------------|
| 1 | `DELETE /api/v1/me` | código | **Sí** |
| 2 | Que la política de privacidad cubra la app | contenido (admin) | No, recomendado |
| 3 | Cuentas y datos para la revisión | operación | **Sí** |
| 4 | Lo que no hace falta y por qué | — | — |
| 5 | Qué hará falta para reactivar el chat | código (siguiente versión) | No |
| 6 | Hallazgos de seguridad | código | No |

---

## 1. 🔴 `DELETE /api/v1/me` — eliminar la cuenta desde la app

### Contrato

```
DELETE /api/v1/me                         (auth:api, throttle:5,1)
Headers: Authorization: Bearer {token} · X-Tenant: anavi · Accept: application/json
Body (JSON): { "password": "..." }

200 → { "message": "Tu cuenta fue eliminada." }
422 → { "message": "La contraseña no es correcta.",
        "errors":  { "password": ["La contraseña no es correcta."] } }
422 → { "message": "Ingresa tu contraseña para confirmar.", "errors": { ... } }   (vacía)
401 → { "message": "Unauthenticated." }
```

- **Ruta:** dentro del grupo `auth:api` de `routes/api.php`, junto a `GET /me` (`:42`):
  ```php
  Route::delete('/me', 'API\V1\AuthController@destroy')->middleware('throttle:5,1')->name('api.me.destroy');
  ```
  El grupo `api` ya limita a 60 peticiones por minuto por IP (`app/Http/Kernel.php:46`). El
  `throttle:5,1` extra es contra fuerza bruta de la contraseña.
- **La contraseña va en el cuerpo del DELETE.** Es igual que en `DELETE /me/device-token`, que la
  app ya usa así.
- **La app muestra `message` tal cual.** `lib/core/network/api_client.dart:111-127` solo lee
  `message`, nunca `errors`, así que el texto tiene que venir en español y listo para mostrar.

### ⚠️ Los 422 de Laravel 8 salen en inglés **[comprobado]**

`ValidationException`, la que lanzan `$request->validate()` y `ValidationException::withMessages`,
se renderiza como `{"message": "The given data was invalid.", "errors": {...}}`. Esto es Laravel
v8.83. `app/Exceptions/Handler.php` no lo personaliza, así que la app mostraría *"The given data was
invalid."*. **Esto ya pasa hoy** con los 422 de `requestMeeting` (`NetworkingController.php:304` y
`:312`, "Ya tienes una reunión a esa hora").

**Recomendado:** un override en el handler. Arregla todos los 422 JSON de una vez; las vistas web no
cambian, porque usan redirect.

```php
// app/Exceptions/Handler.php
protected function invalidJson($request, \Illuminate\Validation\ValidationException $exception)
{
    return response()->json([
        'message' => collect($exception->errors())->flatten()->first() ?: $exception->getMessage(),
        'errors'  => $exception->errors(),
    ], $exception->status);
}
```

Si no se quiere tocar el handler, `destroy()` arma sus 422 a mano con `response()->json([...], 422)`.

### Lógica: un solo servicio para la web y para el API

La única implementación que existe es `Web/UserController@eliminarCuenta` (`:182-238`). Está atada a
la sesión web: usa `Auth::user()`, `back()->withErrors()` y `Auth::logout()`. **Propuesta:** extraer
el borrado a un servicio, por ejemplo `app/Services/EliminarCuenta.php` con
`ejecutar(User $user): void`, y que lo llamen los dos:

- **La web**, después de sus tres confirmaciones actuales (contraseña, escribir "ELIMINAR" y la
  casilla). La UX no cambia.
- **El API:**
  ```php
  // API\V1\AuthController
  public function destroy(Request $request, EliminarCuenta $eliminar)
  {
      $request->validate(['password' => 'required|string'],
                         ['password.required' => 'Ingresa tu contraseña para confirmar.']);
      $user = $request->user();
      if (! Hash::check($request->input('password'), $user->password)) {
          throw ValidationException::withMessages(['password' => 'La contraseña no es correcta.']);
      }
      $eliminar->ejecutar($user);
      return response()->json(['message' => 'Tu cuenta fue eliminada.']);
  }
  ```
  La confirmación de "¿seguro?" la hace la app con un diálogo, así que el API solo pide la contraseña.

### ⚠️ El borrado de la web probablemente falla hoy **[hipótesis fuerte]**

`eliminarCuenta` pone en `NULL` `perfiles.movil`, `empresa`, `cargo` y `ciudad`, y también `pais_id`
(`UserController.php:206-209`). Según `database/schema/mysql-schema.sql:1275` y siguientes, esas
columnas son `NOT NULL`; `pais_id` es `int unsigned NOT NULL`. La conexión corre con
`'strict' => true` (`config/database.php:55`).

Así que el `UPDATE` de `perfiles` debería fallar con SQLSTATE 23000 / 1048. Como es lo primero que se
escribe, la persona ve un error 500 y **la cuenta queda intacta**.

El dump es del 30 de agosto, así que **hay que confirmarlo contra la base real**. La forma más rápida:
borrar una cuenta desechable desde la web (Mi cuenta → Contraseña). En el servicio nuevo hay que usar
`''` en esas columnas de texto y no tocar `pais_id` (o ponerlo en `0`).

### Qué tiene que hacer el servicio

Todo dentro de `DB::transaction`. La foto de S3 se borra después del commit y es best-effort, como hoy.

| Dónde | Qué | ¿Lo hace la web hoy? |
|-------|-----|----------------------|
| `users` | `nombre` "Cuenta eliminada", `apellido` `''`, `email` `eliminado_{id}@trivvo.invalid`, `foto` null, contraseña aleatoria, soft delete | ✅ |
| `users` | **`api_token = null`** | ❌ Se invalida igual por el soft delete, pero conviene limpiarlo |
| `perfiles` | Vaciar `movil`, `telefono`, `empresa`, `cargo`, `ciudad`, `numero_fiscal`, `direccion`, `website` (`''` en las NOT NULL) | ⚠️ Lo intenta con NULL (ver arriba) |
| `perfiles` | Vaciar también `bio`, `linkedin`, `twitter`, `sector`, `intereses`, `telefono_empresa`, `fax_empresa`, `email_empresa`, `estado`, `codigo_postal`, `area`, `tipo_empresa`, `escarapela` | ❌ |
| `perfiles` | `identificacion_tipo`, `identificacion_documento` | ❌ Borrar, salvo que la ley obligue a conservarlos |
| `device_tokens` | Borrar las del usuario, igual que `AuthController@logout` (`:84-94`) | ❌ Hoy `pushAUsuario` las sigue encontrando (p. ej. al responder una reunión) |
| `networking_preferencias` | Borrar las del usuario | ❌ |
| `networking_favoritos` | Borrar donde `user_id` **o** `favorito_id` sea el usuario | ❌ |
| `inscripcion_tarifa_user` | `networking_activo = 0` **y** `networking = 0` | ❌ `attendeeIds()` (`NetworkingController.php:692`) es `DB::table` y no mira `users.deleted_at`; el directorio web filtra por `networking` |
| `reuniones` | `estatus` 1 (pendiente) o 2 (confirmada) → **0 (eliminada)**, sea remitente o destinatario | ❌ La otra persona se quedaría esperando |
| `password_resets` | Borrar por email **antes** de anonimizar | ❌ |
| `user_allergy` | Borrar (es un dato de salud) | ❌ |
| `flights` | Borrar (datos de viaje) | ❌ |
| `users_chats`, `notifications_chat` | Chat viejo: revisar y borrar | ❌ |
| S3 | `usuarios/{foto}` | ✅ |

**Se conservan**, y quedan a nombre de "Cuenta eliminada": `mensajes`, `inscripciones` y pagos (por
obligaciones contables, como ya dice la política de privacidad), `live_poll_votes`,
`encuesta_respuestas` y `questions`.

### Lo que ya funciona sin cambios **[comprobado]**

- El token deja de servir. El guard `token` busca al usuario con Eloquent, y `SoftDeletes`
  (`app/User.php:16`) lo excluye.
- El directorio del API lo excluye, porque `directory()` usa `User::query()`. Cualquier ruta con
  `{user}` responde 404.
- No se puede volver a entrar: el email y la contraseña cambian.

### Cómo probarlo

No hay tests del API V1. Los Feature tests de `tests/` usan factories legacy que probablemente no
corren en Laravel 8. Se prueba con curl y **una cuenta desechable, nunca con las demo del §3**:

```bash
B=https://trivvo.events/api/v1
H=(-H 'X-Tenant: anavi' -H 'Accept: application/json' -H 'Content-Type: application/json')
TOKEN=$(curl -s "${H[@]}" -X POST $B/login -d '{"email":"desechable@...","password":"..."}' | jq -r .token)

curl -i "${H[@]}" -H "Authorization: Bearer $TOKEN" -X DELETE $B/me -d '{"password":"mala"}'  # 422, message en español
curl -i "${H[@]}" -H "Authorization: Bearer $TOKEN" -X DELETE $B/me -d '{"password":"..."}'   # 200
curl -i "${H[@]}" -H "Authorization: Bearer $TOKEN" $B/me                                     # 401
curl -i "${H[@]}" -X POST $B/login -d '{"email":"desechable@...","password":"..."}'          # 401
```

Después, revisar en la base que la cuenta no aparezca en el directorio de otro asistente y que sus
reuniones pendientes hayan quedado en `estatus 0`.

---

## 2. ✅ Política de privacidad y términos: completas, falta cubrir la app

**[comprobado el 24 de septiembre de 2026]** `https://trivvo.events/politica_privacidad` y
`/terms-conditions` ya no tienen marcadores. El operador es TRIVVO LLC, con domicilio en Miami. En el
HTML crudo el correo aparece como `[email protected]`, pero es el ofuscador de Cloudflare; en el
navegador se ve bien.

**Recomendado.** Es contenido, se edita en `/admin/contents` y no requiere código. La política dice
que aplica a la plataforma *"disponible en trivvo.events y sus subdominios"*, así que **no cubre la
app**, que es justo lo que se enlaza desde App Store Connect. Apple suele revisarlo. Hay que:

1. Cambiar esa frase por: *"… trivvo.events, sus subdominios y sus aplicaciones móviles"*.
2. Agregar una sección **"Aplicación móvil"** con:
   - La app usa los mismos datos de la cuenta, del perfil de networking y de las reuniones.
   - **Notificaciones push:** el identificador del dispositivo se envía a Firebase Cloud Messaging
     (Google) y al servicio de notificaciones de Apple (APNs), solo para entregar los avisos del
     congreso y de las reuniones.
   - **Acceso con Face ID o huella:** la verificación ocurre en el teléfono. La contraseña se guarda
     cifrada en el llavero del dispositivo, y ni Trivvo ni el organizador reciben datos biométricos.
   - **Recordatorios y calendario:** se crean en el propio teléfono.
   - **Eliminar la cuenta:** desde la app, en Perfil → Eliminar mi cuenta. Mencionar también la web
     solo cuando se confirme que funciona (ver §1).
3. En los Términos, §1 "Descripción del Servicio", mencionar la app. Las reglas de conducta y la
   posibilidad de suspender cuentas ya están en §5 "Uso aceptable".

Nota: la migración `2026_09_23_000000_seed_legal_pages.php` del repo **sigue con los marcadores**. El
texto se completó desde el admin. En una base nueva volverían a aparecer, así que conviene actualizar
la migración con el texto final.

---

## 3. 🔴 Cuentas y datos para la revisión (operación, no código)

Apple prueba con las credenciales que se le dan en App Store Connect y pide cubrir cada caso. En el
tenant `anavi`, congreso **94**, cada cuenta necesita inscripción confirmada (`inscripciones.estatus = 2`),
`inscripcion_tarifa_user.networking_activo = 1` y el perfil completo (empresa, cargo, sectores e
intereses; la foto es opcional):

| Cuenta | Para qué |
|--------|----------|
| **A** | La principal. Va en *Sign-In Information* de App Store Connect |
| **B** | Segundo asistente. Hace que el directorio no se vea vacío y le deja a A **una solicitud de reunión pendiente**, para que el revisor pueda aceptarla o rechazarla. La fecha debe caer entre el 11 y el 13 de noviembre, a en punto o y media |
| **C** | Para que **el revisor** pruebe "Eliminar cuenta" |
| **D** | Para grabar el video. Se elimina durante la grabación |

Además:
- **El networking tiene que seguir abierto mientras dure la revisión** (`congresos.networking = 1`).
- Si la ficha de la tienda menciona encuestas o preguntas a los ponentes: crear una encuesta en una
  sesión y activar `features.qa` en esa misma sesión. Hoy hay 0 encuestas y `qa` está en 0 de 60
  sesiones, así que el revisor no las vería.
- ⚠️ **Nadie usa la cuenta A mientras dure la revisión.** Ni en otra instalación de la app, ni con
  `POST /login` por curl. El backend guarda **un solo `api_token` por usuario**
  (`AuthController@login`: `forceFill(['api_token' => $token])`). Cada login nuevo le cierra la sesión
  al revisor, que vería *"Unauthenticated."* y lo reportaría como un bug de la app. Iniciar sesión en
  la web no afecta, porque usa sesión y no `api_token`.

### Revisión del comando `ovum:demo-accounts` (`e1cecb8`)

**[comprobado en el código]** Crea o actualiza A–D (`revisor.{a,b,c,d}@ovum.test`) con perfil
completo, inscripción `estatus 2`, `networking = networking_activo = 1` y la reunión pendiente B → A
(`fecha_desde` del congreso, a las 10:00). Llena todas las columnas NOT NULL sin default de `users`,
`inscripciones`, `inscripcion_tarifa_user` y `reuniones`, así que no debería fallar a medias. Si C se
borró, volver a correrlo crea una C nueva, porque la anterior quedó con otro email. Hay que ajustar
tres cosas:

1. **La contraseña por defecto está en el repo** (`--password=TrivvoDemo2026`) y el comando la
   imprime al terminar. Quien tenga acceso al repo podría entrar como asistente confirmado y ver el
   directorio real. Conviene correrlo **siempre con `--password=` fuerte** y quitar el valor por
   defecto (que sea obligatorio).
2. **Las cuatro cuentas aparecen en el directorio real.** Durante el congreso los asistentes verían
   a "Ana Revisora" o "Bruno Demo" y podrían pedirles reunión. Después de la aprobación, y antes del
   11 de noviembre, hay que poner `networking_activo = 0` en B, C y D. A también, hasta la
   siguiente revisión.
3. **Falta ejecutarlo en producción.** El commit dice que no toca prod hasta correrlo. Después
   conviene entrar con A en la app para confirmar que ve el directorio y la reunión pendiente.

---

## 4. Lo que **no** hace falta en esta entrega, y por qué

- **Reportar, bloquear y filtro de palabras.** La app oculta el chat, la nota de reunión y la bio,
  así que no queda texto libre de un usuario que vea otro.
- **Apagar el push de chat.** Solo lo envía `sendMessage` del API (`NetworkingController.php:515`, con
  el texto del mensaje). `Web/MensajeController` no manda push, y sin chat en la app nadie llama a ese
  endpoint. Si alguien escribe desde la web, el aviso sigue llegando por correo (`MensajeMail`).
- **Cambiar `requestMeeting`.** `mensaje` ya es `nullable` y la app deja de mandarlo. Los push de
  reunión no incluyen la nota (`:338`, `:376`, `:400`).

---

## 5. Qué hará falta para reactivar el chat (siguiente versión, no bloquea)

Queda escrito para planificarlo. Nada de esto se pide ahora.

- **Términos con "cero tolerancia" explícita** al contenido ofensivo y a los usuarios abusivos,
  aceptados antes de entrar a Networking. Hoy §5 prohíbe el contenido ofensivo, pero no dice "cero
  tolerancia" ni describe cómo se reporta.
- **Reportar:** `POST /events/{c}/networking/reports` con `{user_id, mensaje_id?, motivo, detalle?}`.
  Se guarda y se avisa a moderación.
- **Bloquear:** `POST|DELETE /events/{c}/networking/blocks/{user}` y `GET /events/{c}/networking/blocks`.
  - Excluye en los dos sentidos en el directorio, la ficha (404), favoritos, reuniones,
    conversaciones y el hilo.
  - Responde 403 al escribir o al pedir reunión, **también en la web**: `MensajeController@enviarInline`
    (L138), `@store` (L205) y `@update` (L299, que en realidad crea), `ReunionController`, y el chat
    viejo `ChatController@send` (L34).
  - Bloquear también avisa a moderación (Apple lo pide).
- **Filtro de palabras** (es/en/pt, sin tildes, por palabra completa) en mensajes, nota de reunión y
  bio. Hoy no hay ningún paquete ni lista.
- **Moderación en menos de 24 horas:**
  - No existe una marca de "suspendido". Para sacar a alguien del networking hoy hay que poner
    `networking_activo = 0` (lo usa el API) **y** `networking = 0` (lo usa la web).
  - No hay pantalla de admin para mensajes; sí la hay para reuniones (`/admin/meetings/{congreso}`).
  - El aviso puede ir a `congresos.emails` (el organizador) y a `soporte@trivvo.events`, como hace
    `Web/ComentarioController.php:34`.
  - Falta decidir quién modera: ANAVI, TRIVVO o ambos.
- **Bug a corregir de paso:** `sendMessage` responde 422 *"El congreso ya finalizó."* **durante el
  último día** del congreso. `fecha_hasta` vale 00:00 y se compara con `isPast()`, mientras que la
  compuerta `networkingAbierto()` (`app/Congreso.php:97-106`) usa `endOfDay`.

---

## 6. Hallazgos de seguridad (no bloquean App Store, pero conviene arreglarlos)

Salieron al revisar el código para este documento. **[comprobado en el código, no explotado]**

1. **`thread()` (`NetworkingController.php:456`) y `toggleFavorite()` (`:182`) no comprueban que
   `{user}` sea asistente.** Como `User` no tiene tenant scope, con cualquier id se obtiene la ficha
   (nombre, empresa, cargo, foto, bio, LinkedIn) de **cualquier usuario de cualquier tenant**.
   Arreglo: `abort_unless($this->esAsistente($congreso, $user->id), 404)`, igual que en `attendee()`.
2. **`GET /events/{id}/attendees` (`EventController.php:342`) no pasa por `guard()`.** Cualquier
   usuario autenticado del tenant, sea asistente o no, lista a los asistentes con bio y LinkedIn.
3. **`Web/MensajeController@show` y `@edit` (L259, L278)** devuelven el texto de un mensaje sin
   comprobar que sea del usuario.
4. **`HomeController@networking` (`POST /networking/activate`, L95)** activa el networking de
   cualquier `inscripcion_tarifa_user` sin comprobar quién es el dueño.
5. **`ChatController@send` (L34)** toma `remitente_id` del request, así que se puede escribir a nombre
   de otra persona.

> ✅ Los cinco quedaron resueltos en `6efc10d`: `abort_unless(esAsistente)` en `thread()` y
> `toggleFavorite()`, asistente confirmado en `attendees`, comprobación de dueño en
> `MensajeController`, `show`/`edit` y `HomeController@networking`, y `Auth::id()` en `ChatController`.
>
> **Efecto en la app:** `GET /events/{id}/attendees` ahora responde 403 a quien no tiene networking
> activo. La app lo usa como roster de respaldo cuando el networking está cerrado; ya se ajustó para
> mostrar solo el aviso en ese caso.

---

## 7. `PUT /api/v1/me` (`c89d2b7`): tres riesgos antes de que la app lo use

Resuelve la §A5 de `API-PENDIENTES.md`. La app **todavía no lo usa**: "Editar perfil" sigue oculto en
esta entrega. Antes de conectarlo hay que corregir:

1. **Un valor vacío da 500 [comprobado en el código].** `ConvertEmptyStringsToNull` es global
   (`app/Http/Kernel.php:20`), así que `"cargo": ""` llega como `null`. Las reglas son `nullable`, y
   `nombre`, `apellido` (`users`), `empresa`, `cargo`, `movil` y `ciudad` (`perfiles`) son
   **NOT NULL**, así que el `UPDATE` falla con 1048. Arreglo:
   - `sometimes|filled` en `nombre` y `apellido` (un nombre no se puede vaciar)
   - `null → ''` en las otras cuatro antes de guardar
2. **Una bio de más de 400 caracteres da 500 [comprobado en el código].** La regla es `bio max:2000`,
   pero `perfiles.bio` es `varchar(400)`, y en modo estricto el `UPDATE` falla con "Data too long".
   Arreglo: `max:400`, igual que la web (`PerfilV2.php:65`).
3. **[hipótesis]** `Perfil::updateOrCreate` con un usuario **sin** fila en `perfiles` haría un
   `INSERT` sin `movil`, `empresa`, `cargo`, `ciudad` ni `pais_id`, que son NOT NULL sin default.
   Solo pasa si hay usuarios sin perfil. Confirmarlo, y si hace falta crear la fila con `''` y el
   país por defecto.
