# Semanas 4 y 5 · Resultados (F08), posiciones y Torneos (F05)

Rama: `feat/canchaya-ligas-equipos`

## Alcance

| Tarjeta | Función | Resultado esperado | Estado |
|---|---|---|---|
| T08 | F05 | Fechas y canchas sin empalmes; ver el calendario | Ya existía (reservas `courtBookings` / `teamBookings`) |
| T09 | F08 | Marcador y corrección con permiso, con historial | Implementado |
| T10 | F05 | Posiciones actualizadas y pruebas de las correcciones | Implementado |
| T11 | Fecha clave 1 | Pruebas generales, APK y ensayo | Pendiente en dispositivo (ver guion) |

## Qué se implementó

### F08 · Captura y corrección de resultados

- `lib/features/tournaments/domain/match_result.dart`: modelo del historial y validaciones (0 a 99 goles, motivo de 5 a 240 caracteres).
- `lib/features/tournaments/data/match_result_repository.dart`: publicar y corregir en una transacción que actualiza el partido y crea `tournamentMatches/{id}/resultHistory/v{n}`.
- `lib/features/tournaments/presentation/match_result_screen.dart`: selectores + / − (sin teclear goles), confirmación, motivo obligatorio para corregir e historial.
- `tournament_schedule_screen.dart` (Admin): al tocar un partido programado se elige "Cambiar cancha u horario" o "Capturar resultado"; un partido finalizado muestra el marcador y abre la corrección.
- `tournament_schedule_repository.dart`: `TournamentMatchRecord` ahora lee `homeScore`, `awayScore` y `resultVersion`; regenerar el calendario se bloquea con un mensaje claro si ya hay resultados.

Historial (`resultHistory/v{n}`): `action` (`published` / `corrected`), marcador nuevo, marcador anterior, `reason`, `changedByUserId` y `changedAt`.

### F05 · Tabla de posiciones

- `lib/features/tournaments/domain/standings_calculator.dart`: se calcula desde los partidos finalizados; no se guarda. Victoria 3, empate 1, derrota 0. Desempate: diferencia de goles, goles a favor y nombre del equipo.
- Programados, pospuestos y partidos sin marcador no cuentan. Una corrección reemplaza el marcador, por eso nunca suma dos veces.

### F05 · Sección Torneos visible para todos

- Nueva colección `publicTournaments/{id}` (nombre, categoría, ciudad, temporada, formato y estado). `tournaments` sigue siendo privada para los administradores.
- `league_repository.dart`: crear torneo y cambiar su estado escriben también la ficha pública en el mismo batch.
- Los torneos creados antes se publican la primera vez que el administrador abre su calendario (Admin → liga → torneo).
- `tournaments_screen.dart`: lista de torneos (los cancelados no se muestran; "Borrador" se muestra como "Próximamente").
- `tournament_detail_screen.dart`: pestañas Calendario, Resultados, Tabla y Equipos, con escudos y nombres cortos de `publicTeams` y hora en formato AM/PM.
- `team_calendar_screen.dart`: parámetro opcional `tournamentId` para reutilizar el calendario por día dentro de un torneo (sin `tournamentId` funciona igual que antes).

### Reglas de Firestore

- Publicar resultado: solo administrador de la liga, partido programado con horario, `resultVersion == 1` y entrada `v1` del historial en el mismo batch.
- Corregir: solo administrador, el marcador debe cambiar, la versión sube exactamente 1 y la entrada `v{n}` con motivo se crea en el mismo batch.
- Historial: inmutable, solo lo leen los administradores de la liga.
- `publicTournaments`: lectura para usuarios autenticados; escritura solo del administrador y debe coincidir con `tournaments/{id}`; no se borra.

## Pruebas automatizadas

| Prueba | Comando | Resultado |
|---|---|---|
| Análisis estático | `flutter analyze` | Sin problemas |
| Unitarias y widgets | `flutter test` | 28 pruebas aprobadas |
| Posiciones | `test/standings_calculator_test.dart` | 9 casos (puntos, desempates, pendientes, correcciones) |
| Tarjeta de partido | `test/tournament_widgets_test.dart` | Sin desbordes a 320 px, AM/PM |
| Reglas F08 y publicTournaments | ver comando abajo | 37 casos aprobados |

```bash
firebase emulators:exec --only firestore --project demo-canchaya --config firebase.emulators.json "node test/firestore_results_rules_test.mjs"
```

Nota: `test/firestore_courts_rules_test.mjs` ya fallaba antes de estos cambios en el caso "unpublished match remains private", porque después se decidió que el calendario (`tournamentMatches`) sea de lectura pública. La aserción debe actualizarse.

## Guion de prueba en dispositivo (pendiente)

1. Desplegar reglas: `firebase deploy --only firestore:rules`.
2. Como administrador: Admin → liga → abrir el torneo (publica el torneo en Torneos).
3. Generar el calendario y programar un partido con cancha y horario.
4. Tocar el partido → Capturar resultado → elegir goles → Publicar.
5. Volver a tocarlo → corregir el marcador con un motivo → verificar el historial.
6. Con una cuenta de jugador: Torneos → abrir el torneo → revisar Calendario, Resultados, Tabla y Equipos.
7. Verificar que la tabla cambió tras la corrección y que no sumó dos veces.
8. Reiniciar la app y comprobar que todo sigue guardado.
9. Con la cuenta de jugador, intentar escribir un resultado (debe rechazarse; cubierto también por las pruebas de reglas).
10. Compilar APK: `flutter build apk --debug`.
