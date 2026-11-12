# Semana 7 · Avisos y recordatorios (F06)

Rama: `feat/canchaya-ligas-equipos`

## Decisión: notificaciones sin servidor

Las push enviadas desde un servidor (Cloud Functions) requieren el plan Blaze de Firebase. Se implementó una solución gratuita, sin servidor, que cumple el criterio de aceptación:

| Necesidad | Cómo se resuelve |
|---|---|
| Avisar cuando se programa o cambia un partido | El administrador, al programar o reprogramar, crea un aviso en la bandeja de cada jugador y encargado de los dos equipos. El teléfono lo detecta en tiempo real y muestra la notificación. |
| Recordar 24 h y 1 h antes, y al inicio | El teléfono programa notificaciones locales que suenan aunque la app esté cerrada. Si falta menos de 24 h, se omite ese aviso. |
| Reprogramar si cambia el partido | Al cambiar el horario se reemplazan (mismo ID); si se pospone o termina, se cancelan. |
| Evitar avisos repetidos por un reintento | IDs deterministas: `{matchId}_{evento}_{uid}` en la bandeja y un hash estable por partido y tipo en el teléfono. |
| Calendario visible si se niegan las notificaciones | Los avisos son un complemento; el calendario y la bandeja funcionan igual. |

Limitación conocida: si la app está totalmente cerrada, el aviso de "cambió el horario" aparece al abrirla (en la bandeja y como notificación). Los recordatorios de 24 h, 1 h y al inicio sí suenan con la app cerrada. Si en el futuro se activa Blaze, basta con agregar una función que envíe FCM a partir de los mismos documentos de la bandeja.

## Qué muestra la notificación

- Imagen con el escudo de cada equipo (de `publicTeams`) y "VS" en medio. Sin escudo se dibujan las iniciales.
- Título: "Diablos Emiliano vs Tigres".
- Texto corto: "Falta 1 hora · 6:00 PM · Dirígete a Cancha Escuela."
- Al tocarla se abre la bandeja (campanita), donde está el mensaje completo.
- Todos los avisos (programación, cambio, resultado y recordatorios) quedan en la bandeja.

## Archivos

- `lib/features/notifications/domain/match_alerts.dart`: tiempos, IDs y textos (sin dependencias de Firebase).
- `lib/features/notifications/data/match_notification_publisher.dart`: avisos del administrador a ambos equipos.
- `lib/features/notifications/services/match_alert_service.dart`: recordatorios programados, bandeja en tiempo real y registro de recordatorios en la bandeja.
- `lib/features/notifications/services/match_crest_image.dart`: imagen con los dos escudos.
- `schedule_court_screen.dart` y `match_result_screen.dart`: envían los avisos al programar o publicar.
- `home_shell.dart`: abre la bandeja al tocar un aviso.
- `main.dart`: inicia el servicio.
- `AndroidManifest.xml`: permiso `RECEIVE_BOOT_COMPLETED` y receptores para que los recordatorios sobrevivan a un reinicio.
- `pubspec.yaml`: `timezone` como dependencia directa (ya estaba como transitiva).

## Reglas de la bandeja (`notifications`)

Antes nadie podía crear avisos. Ahora solo:

1. El administrador de la liga del partido, para jugadores y encargados de los dos equipos, con tipos `match_created`, `match_updated` o `result_published`.
2. Un jugador o encargado, en su propia bandeja, un recordatorio (`r24`, `r1`, `r0`) de un partido de su equipo.

Siempre con ID determinista, sin leer previamente, con campos limitados. Nadie puede borrar avisos ni crearlos para personas fuera de los equipos.

## Pruebas automatizadas

| Prueba | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | 52 pruebas aprobadas (11 nuevas de avisos e imagen) |
| `firestore_notifications_rules_test.mjs` | 25 casos aprobados |
| Suites de reglas anteriores (resultados, alineaciones, canchas) | 87 casos aprobados |

## Guion de prueba en dispositivo Android (pendiente)

Se necesita un celular Android real (en Windows la app funciona, pero no programa notificaciones).

1. Desplegar reglas: `firebase deploy --only firestore:rules`.
2. Iniciar sesión como jugador en el celular y aceptar el permiso de notificaciones.
3. Con otra cuenta (administrador), programar un partido de ese equipo para dentro de 2 a 3 horas.
4. Con la app del jugador abierta o en segundo plano: llega "Programado: …" con los escudos.
5. Revisar la campanita: el aviso está en la bandeja con el mensaje completo.
6. Reprogramar el partido: llega "Nuevo horario" y los recordatorios se reprograman (no se duplican).
7. Cerrar la app del jugador y esperar el recordatorio de 1 hora antes (puede llegar con unos minutos de retraso por el ahorro de batería de Android).
8. Tocar la notificación: abre la bandeja.
9. Publicar el resultado: llega el aviso con el marcador.
10. Repetir el paso 3 con un jugador de otro equipo: no debe recibir nada.

## Pendientes registrados

- Mostrar el escudo del equipo en la imagen exportada de la alineación (F04).
- Opcional: notificaciones push con la app cerrada usando Cloud Functions (requiere plan Blaze).
