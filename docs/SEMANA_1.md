# Semana 1 · Base compartida (T01 y T02)

## Objetivo
Tener una base compartida de CanchaYA que pueda compilarse en Android, con navegación inicial, repositorio organizado y una estrategia de datos preparada para evolucionar de local a nube.

## T01 · Repositorio, compilación Android y entorno reproducible

Estado: **En revisión**.

Evidencia disponible:
- Repositorio GitHub conectado y con historial.
- Proyecto Flutter generado y estructura Android presente.
- Nombre visible Android actualizado a `CanchaYA`.
- Flujo CI agregado para ejecutar análisis y pruebas en cada push/PR.
- Versión del proyecto preparada como `0.1.0+1`.

Pendiente para cerrar T01:
- Ejecutar en un equipo local `flutter pub get`, `flutter analyze`, `flutter test` y `flutter build apk --debug`.
- Guardar captura del APK funcionando en emulador o dispositivo.
- Registrar el resultado de las pruebas y la versión utilizada.

## T02 · Datos, reglas iniciales y navegación

Estado: **En revisión**.

Implementado:
- Navegación principal: Inicio, Equipos, Torneos y Perfil.
- Tema visual base con Material 3 y estilo propio de CanchaYA.
- Separación inicial por `app`, `core` y `features` para evitar concentrar la lógica en `main.dart`.
- Configuración de fuente de datos desacoplada mediante `DataSourceMode`.
- Pantallas base que indican explícitamente qué función F01-F08 las completará.

## Decisión de arquitectura

La interfaz no debe depender directamente de Firebase ni de una base local. Las funciones accederán a datos mediante repositorios/servicios. Eso permitirá una implementación local para demostración y una implementación remota para producción sin reescribir las pantallas.

## Evidencia recomendada

Tomar y conservar:
1. Captura del repositorio y rama de trabajo.
2. Captura de la pantalla Inicio.
3. Captura navegando a Equipos, Torneos y Perfil.
4. Salida de `flutter analyze` y `flutter test`.
5. Captura de compilación/ejecución Android.
6. Enlace al pull request y su revisión.
