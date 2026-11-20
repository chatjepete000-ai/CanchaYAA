import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/player_photo.dart';

// ================================================================
// DETECCIÓN DE CARA EN EL TELÉFONO (ML Kit)
// ================================================================
//
// Funciona sin internet y sin enviar la foto a ningún servidor
// para analizarla. Solo está disponible en Android e iOS.
// ================================================================

class FacePhotoUnavailableException implements Exception {
  const FacePhotoUnavailableException();

  String get message =>
      'La verificación de la foto solo funciona en un teléfono '
      'Android o iPhone.';

  @override
  String toString() => message;
}

class FacePhotoDetector {
  const FacePhotoDetector();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<FacePhotoIssue> check(XFile photo) async {
    if (!isSupported) {
      throw const FacePhotoUnavailableException();
    }

    final bytes = await photo.readAsBytes();

    final image = await decodeImageFromList(bytes);

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    image.dispose();

    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        // Ignora caras muy pequeñas del fondo.
        minFaceSize: 0.15,
      ),
    );

    try {
      final faces = await detector.processImage(
        InputImage.fromFilePath(photo.path),
      );

      return evaluateFacePhoto(
        imageSize: imageSize,
        faces: [
          for (final face in faces)
            DetectedFace(
              box: face.boundingBox,
              yaw: face.headEulerAngleY,
              roll: face.headEulerAngleZ,
            ),
        ],
      );
    } finally {
      await detector.close();
    }
  }
}
