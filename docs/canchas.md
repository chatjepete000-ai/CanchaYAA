# Explorador de canchas

## Recorrido

1. Inicio → **Explorar canchas en Montemorelos** o **Ver mapa**. Se abre una pantalla independiente; la flecha superior y el botón Atrás regresan al inicio.
2. Buscar por nombre, dirección o ciudad; filtrar por tipo de cancha. Tocar una ficha o marcador abre dirección, ruta externa y próximos partidos reales.
3. Con una cuenta `role: admin`, `status: active`, usar **Registrar cancha**. Capturar nombre, dirección y ciudad; tocar el mapa para ubicarla. Las coordenadas son opcionales; la dirección siempre es obligatoria.
4. El propietario administrador puede editar sus sedes; un administrador de plataforma puede editar cualquier sede. Los jugadores y capitanes consultan, pero no escriben.
5. En el calendario de un torneo, tocar un partido guardado para asignar cancha, fecha y horario. El selector enlaza al explorador para registrar una cancha nueva.

## Datos para pruebas

El botón superior **Agregar canchas de Montemorelos** importa cinco sedes a Firestore. Es idempotente: repetirlo no duplica ni sobrescribe las ediciones. No se insertan partidos ficticios en la base real.

- Polideportivo Almazán: coordenadas del complejo verificadas en [OpenStreetMap, nodo 5348015110](https://www.openstreetmap.org/node/5348015110). No equivalen a una cancha específica dentro del complejo.
- Unidad Deportiva Pavorreales, Unidad Deportiva Oriente, Cancha Los Sabinos y Cancha Infonavit: nombres y direcciones del [directorio deportivo municipal](https://www.montemorelos.gob.mx/_files/ugd/b4758b_86a051d1bc764bf9871ba6962754e216.pdf). Sus puntos exactos están pendientes de verificación; el administrador puede marcarlos desde Editar.

Las instalaciones escolares pueden agregarse igual que cualquier otra cancha. Registrar una sede no implica permiso para acceder a ella.

## Implementación

- `flutter_map` + `latlong2`: mapa interactivo, sin SDK de Google ni permisos GPS.
- `url_launcher`: Google Maps mediante URL HTTPS, con coordenadas o búsqueda por dirección como respaldo. El dispositivo decide si abre una app compatible o navegador. Si no puede abrirlo, se muestra un aviso; la dirección también se puede copiar.
- `courts`: datos de sede, coordenadas opcionales, propietario y fechas de creación/edición.
- `tournamentMatches`: nuevos campos opcionales `courtId`, `courtName`, `startsAt`, `bookingId`. Los calendarios existentes siguen siendo válidos y se muestran sin sede/horario hasta programarlos.
- `courtBookings` y `teamBookings`: reservas por bloques de dos horas, alineadas a UTC. Las transacciones y reglas impiden empalmes de cancha y de equipos, incluso con escrituras simultáneas. Reprogramar libera los bloques anteriores en la misma transacción.
- Se guarda UTC y se muestra explícitamente la hora del dispositivo; para las pruebas locales, configurar el teléfono en la zona de Monterrey. No se ha implementado conversión por zona horaria de cada ciudad.
- Los usuarios autenticados pueden consultar los partidos programados con cancha. Los partidos sin asignar conservan acceso restringido a administradores de su liga. No se amplía acceso a perfiles, equipos ni torneos privados.
- Las consultas de la agenda filtran por cancha y estado; ordenan por fecha localmente. No requieren índices compuestos personalizados.

## Conexión y mapas

La dirección sigue visible aunque no exista un punto válido. Los errores de descarga del mapa muestran un aviso y un botón de reintento. Firestore puede recuperar los datos previamente almacenados en la caché de la plataforma; no se promete disponibilidad de sedes nunca descargadas.

OpenStreetMap tiene datos libres, pero sus servidores públicos tienen capacidad limitada y [política de uso](https://operations.osmfoundation.org/policies/tiles/). Se incluyen atribución permanente, identificador de la app y la caché HTTP predeterminada de flutter_map 8.3.2; no se realizan descargas masivas. Se puede cambiar el proveedor mediante `--dart-define=MAP_TILE_URL=https://.../{z}/{x}/{y}.png`; al cambiarlo, adaptar también la atribución a sus condiciones. Firestore mantiene sus cuotas y costos habituales.

## Validación

```powershell
flutter pub get
flutter analyze
flutter test
firebase emulators:exec --only firestore --project demo-canchaya --config firebase.emulators.json "node test/firestore_courts_rules_test.mjs"
firebase deploy --only firestore:rules --dry-run --project canchaya-8ccdb
flutter build apk --debug
```

Las pruebas de reglas usan exclusivamente `demo-canchaya` en un emulador local y rechazan un host externo. Cubren acceso anónimo, jugador, administrador suspendido, suplantación, edición ajena, tamaños, coordenadas, campos extra, reserva atómica, empalmes, reprogramación y consulta de agenda.

Prueba manual realizada con Auth y Firestore emulados: registro de una cancha escolar, selección de punto, persistencia y aparición de marcador; consulta de partido próximo. La integración de apertura externa debe verificarse adicionalmente en un teléfono Android con una aplicación de mapas instalada.

Las reglas se publicaron en `canchaya-8ccdb` el 22 de octubre de 2026, después de comparar la versión remota con la original del repositorio. El despliegue se limitó a Firestore; no se publicó Hosting ni se modificó Firebase Authentication. Las sedes de ejemplo se cargan desde el botón del explorador con una cuenta administradora.

Resultado de esta entrega: `flutter analyze` sin observaciones, 15 pruebas Flutter aprobadas, suite de reglas y reservas aprobada y APK de depuración compilado en `build/app/outputs/flutter-apk/app-debug.apk`. El APK se generó desde `lib/main.dart` y usa la configuración Firebase normal del proyecto; la vista web temporal de QA usa un punto de entrada separado dentro de `build/qa/` y no forma parte del APK.

Las reglas nuevas son un prototipo validado con casos de seguridad y reservas. Deben revisarse antes de distribuir la app ampliamente. Este cambio no implementa resultados, posiciones ni notificaciones automáticas al reprogramar partidos.
