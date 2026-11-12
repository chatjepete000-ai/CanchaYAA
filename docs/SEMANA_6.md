# Semana 6 · Alineación (F04) y mapa (F07)

Rama: `feat/canchaya-ligas-equipos`

## Alcance

| Tarjeta | Función | Resultado esperado | Estado |
|---|---|---|---|
| T12 | F04 | Alineación arrastrando jugadores, guardado y exportación | Implementado |
| T13 | F07 | Mapa, dirección y apertura de ruta | Completado (casos sin internet y sin coordenadas) |

## F04 · Alineación visual

Archivos:

- `lib/features/teams/domain/team_lineup.dart`: formaciones por formato (Fútbol 5: 2-2, 1-2-1 · Fútbol 7: 2-3-1, 3-2-1, 3-1-2 · Fútbol 11: 4-4-2, 4-3-3, 3-5-2), posiciones en la cancha y lógica sin duplicados.
- `lib/features/teams/data/team_lineup_repository.dart`: leer y guardar `teamLineups/{teamId}`, plantilla activa y formato del torneo (desde `publicTournaments`).
- `lib/features/teams/presentation/team_lineup_screen.dart`: cancha, banca, arrastrar y soltar, guardar y exportar.
- `team_manager_screen.dart`: nueva tarjeta **Alineación** (el encargado edita).
- `teams_screen.dart`: botón **Ver alineación** en la tarjeta del jugador (solo lectura).

Cómo se usa (encargado):

1. Administrar equipo → Alineación.
2. Elegir la formación.
3. Mantener presionado un jugador de la banca y arrastrarlo a una posición. También se puede tocar una posición y elegir al jugador de la lista.
4. Arrastrar a un jugador a otra posición lo intercambia; soltarlo en la banca lo retira.
5. Guardar alineación. Exportar imagen abre el menú de compartir del teléfono.

Reglas (`teamLineups/{teamId}`):

- Solo el encargado del equipo crea o modifica la alineación (ni jugadores, ni otros encargados, ni el administrador de la liga).
- El número de posiciones debe coincidir con el formato (5, 7 u 11).
- Un jugador no puede estar en dos posiciones.
- Solo jugadores que pertenecen al equipo.
- La leen jugadores y encargados del equipo, y el administrador de la liga. No se borra.

Nueva dependencia: `share_plus` (exportar la imagen con el menú de compartir).

## F07 · Cómo llegar

- `lib/features/courts/presentation/court_directions.dart`: función compartida por el calendario y el próximo partido.
- Sin coordenadas: avisa y busca la ruta por la dirección de la cancha.
- Sin internet: usa la información guardada en el teléfono; si no la hay, lo explica.
- Si no se puede abrir el mapa: muestra la dirección con un botón para copiarla.
- No se pide la ubicación del jugador.

## Otros cambios

- Admin → liga → torneo: menú ⋮ para cambiar el estado del torneo (Borrador, Inscripciones, En curso, Finalizado, Cancelado). También actualiza la ficha pública.
- `test/firestore_courts_rules_test.mjs`: se actualizó la aserción obsoleta; el calendario es de lectura pública por decisión del proyecto.

## Pruebas automatizadas

| Prueba | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | 41 pruebas aprobadas (13 nuevas de alineación) |
| `firestore_lineups_rules_test.mjs` | 20 casos aprobados |
| `firestore_results_rules_test.mjs` | 37 casos aprobados |
| `firestore_courts_rules_test.mjs` | 30 casos aprobados |

```bash
firebase emulators:exec --only firestore --project demo-canchaya --config firebase.emulators.json "node test/firestore_lineups_rules_test.mjs"
```

## Guion de prueba en dispositivo (pendiente)

1. Desplegar reglas: `firebase deploy --only firestore:rules`.
2. Como encargado: Administrar equipo → Alineación → arrastrar jugadores → Guardar.
3. Intentar poner al mismo jugador en dos posiciones (debe intercambiarse, nunca duplicarse).
4. Cerrar y abrir la app: la alineación se recupera.
5. Exportar imagen y comprobar que se lee el nombre de cada jugador.
6. Como jugador del equipo: Equipos → Ver alineación (no puede editar).
7. Cómo llegar con el modo avión activado: debe mostrar la dirección.
8. Cómo llegar en una cancha sin coordenadas: avisa y abre la ruta por dirección.
9. Admin → torneo → ⋮ → En curso: en Torneos aparece "En curso".
