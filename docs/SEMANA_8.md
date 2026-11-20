# Semana 8 · Reorganización de la pestaña Equipos

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

## Pendientes registrados

- Opcional: resaltar los partidos del equipo del usuario en el detalle del torneo.
