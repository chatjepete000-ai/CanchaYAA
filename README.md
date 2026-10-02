# CanchaYA

Aplicación móvil Flutter para organizar equipos, torneos y partidos de fútbol en escuelas, barrios y ligas.

## Estado actual

Base de Semana 1 (`v0.1`): estructura Flutter, navegación inicial, tema visual, documentación de arquitectura y seguridad, y CI para análisis/pruebas.

## Ejecutar localmente

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Para generar un APK de desarrollo:

```bash
flutter build apk --debug
```

## Estructura inicial

```text
lib/
  app/                 configuración de la aplicación
  core/                tema, configuración y componentes compartidos
  features/            módulos funcionales
    home/
    teams/
    tournaments/
    profile/
docs/                  decisiones, seguridad y evidencia del proyecto
```

## Arquitectura de datos

Las pantallas no se conectarán directamente a una base de datos. La capa de datos se diseñará para permitir una fuente local durante desarrollo/demostración y Firebase en la versión conectada a la nube.

## Seguridad

La seguridad se desarrolla desde F01: autenticación administrada, permisos por rol, mínimo privilegio, reglas del lado del servicio, validación de propiedad de recursos y ningún secreto privado en el repositorio. Consulta `docs/SEGURIDAD.md`.

## Plan universitario

El desarrollo se alinea con las funciones F01-F08 y las tarjetas T01-T16 del plan de trabajo. Las evidencias se conservarán durante el desarrollo y no se considerará terminada una función únicamente por tener pantallas visuales.
