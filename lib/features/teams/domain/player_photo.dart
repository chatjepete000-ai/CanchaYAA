import 'dart:math' as math;
import 'dart:ui';

// ================================================================
// FOTO DE CARA DEL JUGADOR
// ================================================================
//
// Para unirse a un equipo, el jugador se toma una foto de la cara.
// La foto se valida en el teléfono (detección de cara de ML Kit),
// se sube a Cloudinary y su URL se copia en:
//
//   users/{uid}.photoUrl                 foto de perfil
//   teamAssignments/{id}.userPhotoUrl    plantilla del encargado
//   teamLineups/{teamId}.playerPhotoUrls alineación (por posición)
//
// Solo la ven el equipo y el administrador de la liga; no se copia
// a publicTeams ni a publicTournaments.
// ================================================================

/// Prefijo de las fotos válidas: solo imágenes de la cuenta de
/// Cloudinary de CanchaYA. firestore.rules valida lo mismo.
const String trustedPlayerPhotoPrefix =
    'https://res.cloudinary.com/ns45i2wp/image/upload/';

/// Longitud máxima de la URL guardada.
const int maxPlayerPhotoUrlLength = 2048;

/// true si [url] es una foto de CanchaYA que se puede mostrar.
bool isTrustedPlayerPhotoUrl(String url) {
  final clean = url.trim();

  return clean.length > trustedPlayerPhotoPrefix.length &&
      clean.length <= maxPlayerPhotoUrlLength &&
      clean.startsWith(trustedPlayerPhotoPrefix) &&
      !clean.contains(' ');
}

/// Miniatura cuadrada centrada en la cara.
///
/// Cloudinary recorta la imagen alrededor de la cara al entregarla
/// (`c_thumb,g_face`), así que no hace falta recortar en el teléfono.
/// Devuelve '' si la URL no es de confianza.
String playerFaceThumbnailUrl(String url, {int size = 200}) {
  final clean = url.trim();

  if (!isTrustedPlayerPhotoUrl(clean)) {
    return '';
  }

  final rest = clean.substring(trustedPlayerPhotoPrefix.length);

  return '${trustedPlayerPhotoPrefix}c_thumb,g_face,w_$size,h_$size,z_0.75/$rest';
}

// ================================================================
// VALIDACIÓN DE LA FOTO
// ================================================================

/// Lo que importa de una cara detectada, sin depender de ML Kit
/// (así la regla se puede probar sin teléfono).
class DetectedFace {
  const DetectedFace({required this.box, this.yaw, this.roll});

  /// Rectángulo de la cara en píxeles de la imagen.
  final Rect box;

  /// Giro de la cabeza a los lados, en grados.
  final double? yaw;

  /// Inclinación de la cabeza, en grados.
  final double? roll;
}

enum FacePhotoIssue { none, noFace, multipleFaces, tooFar, notCentered, turned }

extension FacePhotoIssueX on FacePhotoIssue {
  bool get isValid => this == FacePhotoIssue.none;

  String get message {
    switch (this) {
      case FacePhotoIssue.none:
        return 'Foto lista.';
      case FacePhotoIssue.noFace:
        return 'No encontramos una cara. Usa buena luz y mira a la cámara.';
      case FacePhotoIssue.multipleFaces:
        return 'Aparece más de una persona. Tómate la foto tú solo.';
      case FacePhotoIssue.tooFar:
        return 'Acércate: la foto debe ser solo de tu cara, '
            'no de cuerpo completo.';
      case FacePhotoIssue.notCentered:
        return 'Centra tu cara en la foto, sin que se corte.';
      case FacePhotoIssue.turned:
        return 'Mira de frente a la cámara, sin girar ni inclinar la cabeza.';
    }
  }
}

/// La cara debe medir al menos esta fracción del lado corto
/// de la imagen. Una selfie normal ronda 0.35–0.60; de medio
/// cuerpo, 0.15–0.20, y de cuerpo completo, menos de 0.10.
const double minFaceToImageRatio = 0.28;

/// Giro o inclinación máxima de la cabeza, en grados.
const double maxHeadAngle = 25;

FacePhotoIssue evaluateFacePhoto({
  required Size imageSize,
  required List<DetectedFace> faces,
}) {
  if (faces.isEmpty || imageSize.isEmpty) {
    return FacePhotoIssue.noFace;
  }

  if (faces.length > 1) {
    return FacePhotoIssue.multipleFaces;
  }

  final face = faces.single;

  final box = face.box;

  final shortSide = math.min(imageSize.width, imageSize.height);

  final faceSide = math.max(box.width, box.height);

  if (faceSide / shortSide < minFaceToImageRatio) {
    return FacePhotoIssue.tooFar;
  }

  // El centro de la cara debe caer dentro de la zona central
  // (entre el 20 % y el 80 % de cada eje), con independencia
  // de si la imagen viene vertical u horizontal.
  final centerX = box.center.dx / imageSize.width;
  final centerY = box.center.dy / imageSize.height;
  final centerXAlt = box.center.dx / imageSize.height;
  final centerYAlt = box.center.dy / imageSize.width;

  bool centered(double x, double y) =>
      x >= 0.2 && x <= 0.8 && y >= 0.2 && y <= 0.8;

  if (!centered(centerX, centerY) && !centered(centerXAlt, centerYAlt)) {
    return FacePhotoIssue.notCentered;
  }

  final yaw = face.yaw?.abs() ?? 0;
  final roll = face.roll?.abs() ?? 0;

  if (yaw > maxHeadAngle || roll > maxHeadAngle) {
    return FacePhotoIssue.turned;
  }

  return FacePhotoIssue.none;
}

/// Inicial que se muestra cuando el jugador aún no tiene foto.
String playerInitial(String name) {
  final clean = name.trim();

  if (clean.isEmpty) {
    return '?';
  }

  return String.fromCharCode(clean.runes.first).toUpperCase();
}
