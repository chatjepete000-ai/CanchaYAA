import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryProfilePhotoService {
  static const String _cloudName = 'ns45i2wp';

  static const String _uploadPreset =
      'canchaya_profile_photos';

  static const int _maxFileSizeBytes =
      5 * 1024 * 1024;

  Uri get _uploadUri => Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$_cloudName/image/upload',
      );

  Future<String> uploadProfilePhoto(
    XFile image,
  ) async {
    final bytes = await image.readAsBytes();

    if (bytes.isEmpty) {
      throw const CloudinaryProfilePhotoException(
        'La imagen seleccionada está vacía.',
      );
    }

    if (bytes.length > _maxFileSizeBytes) {
      throw const CloudinaryProfilePhotoException(
        'La fotografía debe pesar menos de 5 MB.',
      );
    }

    final extension =
        _getFileExtension(image.name);

    if (!_isAllowedExtension(extension)) {
      throw const CloudinaryProfilePhotoException(
        'El formato de la imagen no es compatible. '
        'Usa JPG, JPEG, PNG o WEBP.',
      );
    }

    final request =
        http.MultipartRequest(
      'POST',
      _uploadUri,
    );

    request.fields['upload_preset'] =
        _uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: image.name,
      ),
    );

    http.StreamedResponse response;

    try {
      response = await request.send();
    } catch (_) {
      throw const CloudinaryProfilePhotoException(
        'No se pudo conectar con el servicio de imágenes. '
        'Revisa tu conexión a internet.',
      );
    }

    final responseBody =
        await response.stream.bytesToString();

    Map<String, dynamic> data;

    try {
      final decoded =
          jsonDecode(responseBody);

      if (decoded
          is! Map<String, dynamic>) {
        throw const FormatException();
      }

      data = decoded;
    } catch (_) {
      throw const CloudinaryProfilePhotoException(
        'Cloudinary devolvió una respuesta no válida.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      final error = data['error'];

      String? message;

      if (error is Map<String, dynamic>) {
        final cloudinaryMessage =
            error['message'];

        if (cloudinaryMessage is String) {
          message = cloudinaryMessage;
        }
      }

      throw CloudinaryProfilePhotoException(
        message == null
            ? 'No se pudo subir la fotografía.'
            : 'No se pudo subir la fotografía: '
                '$message',
      );
    }

    final secureUrl =
        data['secure_url'];

    if (secureUrl is! String ||
        secureUrl.trim().isEmpty) {
      throw const CloudinaryProfilePhotoException(
        'Cloudinary no devolvió la URL de la fotografía.',
      );
    }

    return secureUrl.trim();
  }

  String _getFileExtension(
    String filename,
  ) {
    final separator =
        filename.lastIndexOf('.');

    if (separator == -1 ||
        separator ==
            filename.length - 1) {
      return '';
    }

    return filename
        .substring(separator + 1)
        .toLowerCase();
  }

  bool _isAllowedExtension(
    String extension,
  ) {
    return const {
      'jpg',
      'jpeg',
      'png',
      'webp',
    }.contains(extension);
  }
}

class CloudinaryProfilePhotoException
    implements Exception {
  const CloudinaryProfilePhotoException(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}