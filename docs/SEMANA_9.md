# Semana 9 · Canchas cercanas, diseño "Limpio", alineación libre y avisos de partidos

Rama: `feat/canchaya-ligas-equipos`

## 1. Canchas cercanas al cambiar de ciudad (error corregido)

**Causa.** Al buscar una ciudad, Nominatim devuelve primero el **municipio**. Su centro geográfico puede quedar a 15 km o más del pueblo, en pleno campo: por ejemplo, el de Linares, N.L., está a unos 16 km de la cabecera. Como la app quitaba los repetidos por nombre, se quedaba con ese punto, y la búsqueda de canchas en 10 km a su alrededor salía vacía. Algo parecido pasaba al elegir un **estado**, cuyo centro cae lejos de cualquier ciudad.

**Arreglo.**

| Cambio | Archivo |
|---|---|
| Entre resultados con el mismo nombre y estado, se prefiere la ciudad o el pueblo sobre el municipio. Se descartan estados, regiones y países. | `location_search_service.dart` |
| Si hay menos de 3 canchas, el radio de OpenStreetMap crece de 10 a 25 y luego a 50 km. Las canchas se ordenan de la más cercana a la más lejana. | `osm_pitch_service.dart` |
| Si un servidor de Overpass está ocupado (429/504) o no responde, se usa el siguiente: overpass-api.de, overpass.kumi.systems y overpass.private.coffee. | `osm_pitch_service.dart` |
| La ciudad coincide aunque el nombre esté completo o abreviado ("Cadereyta" = "Cadereyta Jiménez"). | `user_location.dart` |

## 2. Diseño de Canchas: plantilla B "Limpio"

El propietario eligió esta plantilla entre tres propuestas. Las tres se hicieron solo con código, sin imágenes.

- Título grande "Encuentra tu cancha" y chip con la ciudad, que abre el selector de ciudad.
- Buscador gris claro y botón oscuro de filtros, que abre la hoja "Tipo de cancha".
- Pestañas **Lista · Mapa · Sugeridas (n)**. En pantallas anchas (850 px o más), el mapa queda fijo a la derecha.
- Etiquetas de filtro: "Hasta N km" (el radio real que usó la búsqueda) y el tipo elegido, que se puede quitar.
- Filas con la distancia a la izquierda, el nombre, la etiqueta **CanchaYA** o **Sugerida** y un botón redondo de "Cómo llegar".
- Funciona en modo claro y oscuro (colores del tema). El dorado de las sugeridas es más oscuro en modo claro, para que se lea bien.

Archivo: `lib/features/courts/presentation/courts_screen.dart`.

## 3. Alineación libre con el dedo (F04)

- **Arrastrar** a un jugador, o a un lugar libre, lo mueve a cualquier punto de la cancha.
- **Mantener presionado y arrastrar** lo intercambia con otro jugador o lo regresa a la banca, igual que antes.
- La formación (2-3-1, 4-4-2…) solo da el acomodo inicial. El botón **"Acomodo de la formación…"** lo restablece.
- Se guarda `slotX` y `slotY` (de 0 a 1) en `teamLineups`. Los jugadores ven y exportan el mismo acomodo.
- Reglas: los dos campos son opcionales, van siempre juntos y deben medir lo mismo que las casillas.

## 4. Suspender o cancelar partidos (clima u otro motivo)

Esto define lo que estaba pendiente sobre "suspendido" y "cancelado".

| Estado | Qué significa | Tabla | Cancha y equipos |
|---|---|---|---|
| `postponed` (**Suspendido**) | Clima, cancha no disponible u otro motivo. Queda pendiente de reprogramar. | No cuenta hasta que se juegue | Se liberan la cancha y el horario de los dos equipos |
| `cancelled` (**Cancelado**) | Definitivo: no se reprograma ni se captura resultado. | No cuenta | Se liberan |

- El administrador va a **Admin → torneo → calendario**, toca el partido y elige **Suspender** o **Cancelar partido**. Escoge el motivo (Clima, Cancha no disponible u Otro motivo) y puede escribir una nota de hasta 140 caracteres.
- Un partido suspendido muestra **Reprogramar cancha y horario**. Al reprogramarlo vuelve a `scheduled` y se borra el motivo.
- Jugadores y encargados ven "Suspendido · Clima (tormenta eléctrica)" en su equipo y en Torneos.
- Los recordatorios de 24 h, 1 h y al inicio se cancelan solos, porque el partido deja de estar programado.

Archivos nuevos:

- `lib/features/tournaments/domain/match_status.dart`
- `lib/features/tournaments/data/match_status_repository.dart`
- `lib/features/tournaments/presentation/match_status_sheet.dart`

Archivos modificados: `tournament_schedule_screen.dart`, `court_repository.dart` (permite reprogramar un suspendido), `team_match_panel.dart`, `tournament_widgets.dart`, `match_result_screen.dart` y los dos modelos de partido.

## 5. Avisos en tiempo real en la campanita (F06)

| Aviso | Quién lo recibe |
|---|---|
| Partido programado o con cambio de horario o cancha | Los dos equipos (ya existía) |
| Recordatorio 24 h, 1 h y al inicio | El propio jugador (ya existía) |
| **Partido suspendido o cancelado, con motivo** (nuevo) | Los dos equipos |
| **Resultado publicado o corregido** (ahora a todo el torneo) | Los dos equipos **y** los jugadores y encargados de los demás equipos del mismo torneo |

- Los avisos llegan a la bandeja (campanita). Con la app abierta o en segundo plano, el teléfono los muestra al momento como notificación, con los escudos.
- Para avisar a los demás equipos se guarda `teamId`: el equipo del destinatario. La regla comprueba que la persona pertenezca a ese equipo y que el equipo sea del mismo torneo del partido.
- Siguen sin poder enviarse con la app totalmente cerrada. Eso necesitaría Cloud Functions (plan Blaze).

## Firestore y reglas

| Colección | Cambio |
|---|---|
| `tournamentMatches` | Suspender exige `statusReason` (`weather`, `court` u `other`) y acepta una nota de hasta 140 caracteres. Nueva regla **cancelar**, desde `scheduled` o `postponed`, liberando las reservas. Reprogramar borra el motivo. Los cancelados se pueden borrar al regenerar el calendario. |
| `teamLineups` | `slotX` y `slotY` opcionales. |
| `notifications` | Tipos `match_postponed` y `match_cancelled` para los dos equipos, y `result_published` para todo el torneo, verificado con `teamId`. |

> **Hay que desplegar las reglas:** primero `firebase deploy --only firestore:rules --dry-run` y, si sale bien, `firebase deploy --only firestore:rules`.

## Pruebas automatizadas

| Prueba | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | 106 pruebas aprobadas (14 nuevas: ciudad, OSM, alineación libre, estados y textos de avisos) |
| `firestore_match_status_rules_test.mjs` (nuevo) | 18 casos aprobados |
| `firestore_notifications_rules_test.mjs` | 35 casos (10 nuevos) |
| `firestore_lineups_rules_test.mjs` | 25 casos (5 nuevos) |
| Resto de suites (canchas, fotos, resultados, borrado de equipos, ubicación) | 118 casos aprobados |

No se probó en un teléfono, porque el entorno de desarrollo no tiene SDK de Android. Los servidores de Overpass no se pudieron consultar desde ese entorno (red bloqueada), así que la lógica de búsqueda se probó con respuestas simuladas.

## Guion de prueba en dispositivo Android (pendiente)

1. Desplegar las reglas.
2. **Canchas:** elegir "Linares" y revisar que el chip diga "Linares, Nuevo León" y que salgan canchas sugeridas. Probar con un pueblo pequeño: la etiqueta debe cambiar a "Hasta 25 km" o "Hasta 50 km" si hay pocas. Cambiar entre Lista, Mapa y Sugeridas.
3. **Alineación (encargado):** arrastrar a un jugador a un punto libre y ver que se mueve. Mantener presionado y soltarlo sobre otro para intercambiarlos. Guardar, abrir con un jugador **Ver alineación** y comprobar que el acomodo es el mismo. Probar **Acomodo de la formación**.
4. **Suspender por clima (administrador):** en el calendario, tocar un partido programado → Suspender → Clima → "tormenta". Los dos equipos reciben "Suspendido: A vs B" en la campanita y ven el motivo en su tarjeta. La cancha queda libre para otro partido a esa hora.
5. **Reprogramar el suspendido:** recibe "Nuevo horario" y desaparece el motivo.
6. **Cancelar:** el partido muestra "Cancelado · …", no se puede capturar resultado y la tabla no cambia.
7. **Resultado a todo el torneo:** publicar un resultado y comprobar que lo recibe un jugador de un **tercer** equipo del mismo torneo, pero no uno de otro torneo.

## Pendientes registrados

- Aplicar la plantilla "Limpio" a otras pantallas (Inicio, Torneos, bandeja) si el propietario lo pide.
- Push con la app totalmente cerrada (Cloud Functions, plan Blaze).
- Opcional: resaltar los partidos del equipo del usuario en el detalle del torneo.
