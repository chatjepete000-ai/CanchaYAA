# Semana 8 · Reorganización de Equipos y foto de cara del jugador

Rama: `feat/canchaya-ligas-equipos`

## Decisión: Equipos es personal, Torneos es general

| Pestaña | Qué muestra |
|---|---|
| Equipos | Mi equipo, mi próximo partido, cómo llegar, la alineación y "Administrar equipo" si soy encargado. |
| Torneos | Calendario de todos los partidos, resultados, tabla y equipos de cada torneo. |

Antes, Equipos también mostraba el calendario general, lo que duplicaba Torneos.

## Alcance

**Usuario sin equipo**

- Solo ve "Aún no perteneces a ningún equipo" y el botón **Unirme a un equipo**.
- Se quitaron la tarjeta "Calendario de partidos", la sección "Invitaciones" cuando está vacía y el aviso final.
- Si tiene una invitación para ser encargado, aparece arriba del mensaje.

**Jugador o encargado**

- Las tarjetas de equipo ya no tienen el botón "Ver calendario".
- La tarjeta de jugador conserva el próximo partido y "Cómo llegar" (`TeamMatchPanel`), además de **Ver alineación**.
- La tarjeta de encargado conserva el próximo partido y **Administrar equipo**.
- Una tarjeta nueva, "Calendario, resultados y tabla · Ir a Torneos", cambia a la pestaña Torneos.
- "Unirme a otro equipo" quedó como un botón de texto discreto al final.
- La sección "Invitaciones" solo aparece si hay invitaciones pendientes.

`TeamCalendarScreen` se conserva porque el detalle del torneo lo usa ("Ver calendario por día").

## Archivos

| Archivo | Cambio |
|---|---|
| `lib/features/teams/presentation/teams_screen.dart` | Nueva organización. Se eliminó `_PublicCalendarCard` y se agregaron `NoTeamCard` y `TournamentsShortcutCard`. |
| `lib/features/home/presentation/home_shell.dart` | `TeamsScreen` recibe `onOpenTournaments`, que cambia a la pestaña Torneos. |
| `test/teams_screen_test.dart` | Pruebas nuevas del estado sin equipo y del acceso a Torneos en 320 px. |

## Firestore

Sin cambios en las colecciones ni en `firestore.rules`. No se agregaron dependencias.

## Pruebas automatizadas

| Prueba | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | 73 pruebas aprobadas (2 nuevas) |

Nota: `SEMANA_7.md` reporta 52 pruebas. El commit `82da826` (elegir ciudad y canchas de OpenStreetMap) agregó 19 y llegó a 71.

## Guion de prueba en dispositivo Android (pendiente)

1. Iniciar sesión con una cuenta **sin equipo**, abrir Equipos y verificar que solo aparecen el mensaje y **Unirme a un equipo**.
2. Tocar **Unirme a un equipo**: abre la pantalla del código o QR.
3. Unirse con un código válido: al volver aparece la tarjeta del equipo con el próximo partido y "Ver alineación", sin "Ver calendario".
4. Tocar **Ir a Torneos**: cambia a la pestaña Torneos y la barra inferior marca Torneos.
5. Con una cuenta de **encargado**: verificar "Equipos que administras" y **Administrar equipo**, sin "Ver calendario".
6. Con una invitación pendiente de encargado: la sección "Invitaciones" aparece. Al aceptarla, desaparece.
7. En Torneos → detalle → **Ver calendario por día**: el calendario general sigue funcionando.
8. Probar en una pantalla angosta (320 px o letra grande): nada se desborda.

---

# Parte 2 · Foto de la cara para unirse a un equipo

## Decisiones del propietario

| Pregunta | Decisión |
|---|---|
| ¿Cómo se verifica que sea la cara? | Detección de cara en el teléfono con ML Kit (`google_mlkit_face_detection`). |
| ¿Quién ve la foto? | Solo el equipo (jugadores y encargado) y el administrador de la liga. No se copia a `publicTeams` ni a `publicTournaments`. |
| ¿Y los jugadores que ya estaban en un equipo? | Ven el aviso "Agrega tu foto", pero no se les bloquea. Mientras no tengan foto, aparece su inicial. |
| ¿Reemplaza la foto de perfil? | Sí: es una sola foto, que también queda como foto de perfil. |

## Cómo funciona

1. En **Unirme a un equipo**, después de validar el código, el botón **Unirme al equipo** abre la cámara frontal. No se permite elegir de la galería.
2. ML Kit revisa la foto **en el teléfono**, sin internet y sin enviarla a ningún servidor para analizarla. Pide:
   - una sola cara (si hay dos personas, se rechaza);
   - que la cara mida al menos el 28 % del lado corto de la foto (rechaza cuerpo completo y medio cuerpo);
   - que esté centrada y sin cortarse;
   - que la cabeza esté de frente, sin girarla ni inclinarla más de 25°.
3. Si no cumple, se explica el motivo y se puede tomar otra foto.
4. Al confirmar, la foto se sube a Cloudinary (preset `canchaya_profile_photos`), queda como foto de perfil y se guarda en la asignación del jugador.
5. Cloudinary la entrega recortada en la cara (`c_thumb,g_face`), así que no hace falta recortarla en el teléfono.

Dónde se ve:

- **Plantilla del encargado:** la foto circular en lugar de la inicial.
- **Alineación:** la foto en cada posición de la cancha y en la banca, y también en la imagen exportada.
- **Jugador sin foto:** la tarjeta de su equipo muestra "Agrega tu foto · Tomar".

Si un jugador agrega su foto después de que se guardó la alineación, el botón del encargado cambia a **Actualizar fotos**.

## Archivos (parte 2)

| Archivo | Cambio |
|---|---|
| `pubspec.yaml`, `pubspec.lock` | Nueva dependencia `google_mlkit_face_detection: ^1.0.3`. |
| `lib/features/teams/domain/player_photo.dart` (nuevo) | Reglas de validación de la cara (sin depender de ML Kit, para poder probarlas), URLs de confianza y miniatura. |
| `lib/features/teams/data/face_photo_detector.dart` (nuevo) | Conecta ML Kit con la validación. Solo funciona en Android e iOS. |
| `lib/features/teams/presentation/face_photo_capture_screen.dart` (nuevo) | Pantalla para tomar, revisar y subir la foto. |
| `lib/features/teams/presentation/widgets/player_avatar.dart` (nuevo) | Foto circular del jugador o su inicial. |
| `lib/features/teams/presentation/player_join_screen.dart` | La foto es obligatoria antes de unirse y se guarda en `userPhotoUrl`. |
| `lib/features/teams/presentation/teams_screen.dart` | Aviso "Agrega tu foto" para jugadores sin foto. |
| `lib/features/teams/presentation/team_roster_screen.dart` | Fotos en la plantilla. |
| `lib/features/teams/presentation/team_lineup_screen.dart` | Fotos en la cancha, la banca y la imagen exportada; botón **Actualizar fotos**. |
| `lib/features/teams/domain/team_models.dart` | `TeamAssignment.userPhotoUrl`. |
| `lib/features/teams/domain/team_lineup.dart` | `TeamLineup.playerPhotoUrls`. |
| `lib/features/teams/data/team_repository.dart` | `updateMyAssignmentPhoto`. |
| `lib/features/teams/data/team_lineup_repository.dart` | Lee la foto de la plantilla y guarda `playerPhotoUrls`. |
| `firestore.rules` | Ver la sección siguiente. |
| `test/player_photo_test.dart`, `test/firestore_player_photo_rules_test.mjs` (nuevos) | Pruebas. |

## Firestore y reglas

| Colección | Cambio |
|---|---|
| `teamAssignments` (jugador, crear) | **Exige** `userPhotoUrl`: una URL HTTPS de `res.cloudinary.com/ns45i2wp/image/upload/`. |
| `teamAssignments` (encargado, crear) | Si trae `userPhotoUrl`, debe ser válida. |
| `teamAssignments` (actualizar, nueva) | Un jugador activo puede cambiar solo `userPhotoUrl` y `updatedAt` de **su propia** asignación. |
| `teamLineups` | Acepta `playerPhotoUrls`, que es opcional y debe tener una entrada por posición. Solo el encargado la escribe, como antes. |

Las fotos se leen con los mismos permisos de siempre: la asignación la ven el propio jugador, el encargado y el administrador, y la alineación la ve el equipo. **No hay ninguna lectura nueva pública.**

> **Importante:** hay que desplegar las reglas antes de usar esta versión. Con las reglas anteriores se rechazan "Agrega tu foto" y guardar una alineación en la que algún jugador tenga foto. Las alineaciones sin fotos se siguen guardando, porque en ese caso no se envía `playerPhotoUrls`. Unirse con foto funciona en ambos casos, pero solo las reglas nuevas obligan a tener foto.
>
> `firebase deploy --only firestore:rules --dry-run` y, si sale bien, `firebase deploy --only firestore:rules`.

## Pruebas automatizadas (parte 2)

| Prueba | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | 89 pruebas aprobadas (16 nuevas: validación de la cara, URLs, modelos, avatar y pantalla en 320 px) |
| `firestore_player_photo_rules_test.mjs` | 22 casos aprobados |
| Suites de reglas anteriores (canchas, alineaciones, avisos, resultados, borrado de equipos, ubicación) | 141 casos aprobados |

No se pudo compilar el APK en el entorno de desarrollo, porque no tiene el SDK de Android. Hay que generarlo en la computadora del propietario con `flutter build apk --debug`.

## Guion de prueba en dispositivo Android (pendiente)

Se necesita un celular Android real o un emulador con cámara frontal (en el emulador se puede usar la cámara web).

1. Desplegar las reglas (ver arriba).
2. Con una cuenta sin equipo, ingresar un código de jugador válido y tocar **Unirme al equipo**: se abre la pantalla de la foto.
3. Tomar una foto de **cuerpo completo**: debe decir "Acércate: la foto debe ser solo de tu cara…" y no permite continuar.
4. Tomar una foto con **dos personas**: la rechaza.
5. Tomar una selfie de frente: muestra "Foto lista" y **Usar foto y unirme**. Al tocarlo, se une al equipo.
6. Volver atrás en la pantalla de la foto sin tomarla: no se une y avisa que la foto es necesaria.
7. Abrir **Perfil**: la foto de perfil es la nueva.
8. Con la cuenta del **encargado**: Administrar equipo → plantilla, donde aparece la foto. En la alineación, la foto aparece en la banca y al colocarlo en la cancha. Guardar y exportar la imagen: la foto sale en la imagen.
9. Con un **jugador antiguo** sin foto: en Equipos aparece "Agrega tu foto". Tomarla, y el aviso desaparece. El encargado ve **Actualizar fotos** en la alineación.
10. Con la cuenta del jugador: **Ver alineación** muestra las fotos.

## Pendientes registrados

- Opcional: resaltar los partidos del equipo del usuario en el detalle del torneo.
- iOS: `Info.plist` no tiene `NSCameraUsageDescription` (tampoco para el escáner QR que ya existía). Hay que agregarlo si se publica en iPhone.
- La validación de la cara no reconoce a la persona: solo revisa que la foto sea de una cara. Que sea la del jugador depende del encargado, que lo conoce.
- Mostrar la foto en la futura ficha pública del equipo quedó descartado: el propietario decidió que la vea solo el equipo.
