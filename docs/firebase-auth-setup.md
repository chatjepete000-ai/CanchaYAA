# Acceso con Google y recuperación de contraseña

Proyecto Firebase: `canchaya-8ccdb`. Android: `com.canchaya.cancha_ya`.

## Configuración pendiente en Firebase

1. En Authentication > Sign-in method habilitar **Google**, seleccionar el correo de soporte y guardar. Mantener habilitado **Correo electrónico/contraseña** para las cuentas tradicionales.
2. En Configuración del proyecto > Tus apps seleccionar la app Android con el paquete indicado. Agregar la huella **SHA-1** del certificado utilizado para compilar. Registrar también SHA-256. Obtenerlas desde la carpeta `android` con `./gradlew signingReport` (PowerShell: `.\gradlew.bat signingReport`). Cada colaborador tiene su propio certificado de depuración; registrar el correspondiente. Para distribuir con otra firma, registrar también esa firma y la de Play App Signing si se usa Google Play.
3. Descargar de nuevo `google-services.json` y reemplazar `android/app/google-services.json`. El archivo actual tiene `oauth_client: []`: falta la configuración OAuth. El nuevo debe incluir un cliente web con `client_type: 3`; el plugin lo utiliza como server client ID sin escribir claves en Dart.
4. Ejecutar `flutter pub get` y recompilar la app completamente. Hot reload no aplica cambios en plugins o configuración nativa.
5. Para web, autorizar el dominio en Authentication > Settings > Authorized domains. Incluir `localhost` si se prueba allí y permitir ventanas emergentes.

Se necesitan permisos para administrar **Firebase Authentication** y la configuración de aplicaciones; tener acceso solo a Firestore puede no ser suficiente. Si las opciones están bloqueadas, solicitar estos cambios al propietario. No se necesita una clave privada de cuenta de servicio ni contraseña de Gmail.

## Huellas de depuración de este equipo

Obtenidas de `%USERPROFILE%/.android/debug.keystore` mediante `keytool`:

- SHA-1: `31:54:43:EF:EC:B1:0C:52:35:26:0D:5B:8C:D0:E3:C9:EC:CB:D3:5F`
- SHA-256: `33:CF:1A:CE:53:88:9D:FA:95:FB:96:C8:DF:30:81:90:45:4C:23:52:58:B0:3F:75:74:74:4A:FE:A0:05:7E:83`

Actualmente Gradle usa la firma debug también para release. Estas huellas deben reemplazarse o complementarse cuando se configure una firma de distribución propia.

## Recuperación

El enlace “¿Olvidaste tu contraseña?” valida el correo y llama a `sendPasswordResetEmail` con idioma español. Firebase envía el mensaje y aloja la página para elegir la nueva contraseña. En Authentication > Templates > Password reset puede revisarse la plantilla, nombre y remitente. Se envía al correo registrado (Gmail u otro proveedor); revisar spam. La respuesta no confirma si una dirección está registrada.

Esta operación cambia la contraseña de **CanchaYA**, no la contraseña de la cuenta de Google. Quien accede con Google puede seguir usando “Continuar con Google”.

## Comportamiento y pruebas manuales pendientes

- Google en Android usa `google_sign_in` y entrega el ID token a Firebase Auth. Web utiliza el popup de Firebase. Cancelar permite reintentar; los errores de configuración, red y cuenta deshabilitada se muestran en español.
- Antes de abrir el inicio de una cuenta Google se comprueba el perfil en Firestore. Solo se crea cuando falta, con rol jugador; no se reemplaza el rol ni los datos de perfiles existentes. Un fallo permite reintentar o cerrar sesión.
- La sesión se conserva mediante Firebase Auth y los cierres existentes cierran esa sesión. No se realiza acceso silencioso con el plugin de Google.
- iOS/macOS requieren su configuración OAuth propia (client ID y URL scheme según la documentación del plugin); no fueron configurados ni validados en este cambio. Google no está habilitado para escritorio Windows/Linux; utilizar Android o web.

Después de configurar Firebase, probar en Android y web: cuenta nueva, cuenta existente con rol personalizado, cancelar y reintentar, cerrar sesión y elegir otra cuenta, reiniciar la app y fallos de red. Confirmar que no se duplican documentos `users/{uid}` ni se modifican roles existentes.

Con una cuenta de prueba de correo/contraseña, solicitar el enlace, comprobar su recepción, abrirlo, cambiar la contraseña y verificar que la nueva funciona y la anterior deja de funcionar. Probar correo inválido, cancelar y reintentar después de un error de red. Estas verificaciones necesitan acceso real a Firebase y al buzón; las pruebas locales no demuestran la entrega del correo ni la configuración OAuth.

## Referencias

- https://firebase.google.com/docs/auth/flutter/federated-auth
- https://pub.dev/packages/google_sign_in_android
- https://firebase.google.com/docs/auth/flutter/manage-users
