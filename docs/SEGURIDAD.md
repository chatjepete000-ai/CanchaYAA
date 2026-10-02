# Línea base de seguridad de CanchaYA

Este documento establece criterios obligatorios para el desarrollo. No sustituye las reglas de Firebase ni las pruebas de seguridad que se implementarán desde F01.

## Principios

- Nunca guardar contraseñas en texto plano ni implementar autenticación casera en Flutter.
- Para producción, la autenticación será gestionada por un proveedor seguro (plan actual: Firebase Authentication).
- Ningún rol administrativo se concede por una opción visual en la aplicación.
- Toda operación sensible debe validarse también en el servicio/backend o mediante reglas de seguridad.
- Aplicar mínimo privilegio: jugador, capitán y administrador solo acceden a las operaciones que necesitan.
- No incluir claves privadas, secretos de servidor ni credenciales en el repositorio.
- Validar tipo, tamaño y procedencia de archivos/fotos antes de almacenarlos.
- Las invitaciones de equipo deberán poder cancelarse y validarse en servidor.
- Las correcciones de resultados deberán conservar quién hizo el cambio, cuándo y por qué.
- Evitar exponer información personal que no sea necesaria para la función mostrada.
- Registrar y probar explícitamente intentos de acceso no autorizado.

## Datos locales y nube

El modo local se utilizará como apoyo de desarrollo/demostración, pero no se considerará una barrera de seguridad suficiente para permisos. En producción, las reglas de autorización residirán fuera del dispositivo.

## Secretos

Los archivos con credenciales privadas o valores sensibles no se subirán a Git. Las configuraciones públicas necesarias para clientes móviles se gestionarán según la documentación oficial del proveedor, y cualquier secreto de servidor permanecerá fuera de la app.
