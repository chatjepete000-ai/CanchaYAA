import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryTeamLogoService {
  static const String _cloudName =
      'ns45i2wp';

  // Reutilizamos el preset que ya funciona actualmente
  // para las imágenes de CanchaYA.
  //
  // Más adelante, si quieres separar físicamente
  // perfiles y escudos dentro de Cloudinary,
  // podemos crear un preset exclusivo para equipos.
  static const String _uploadPreset =
      'canchaya_profile_photos';

  static const int _maxFileSizeBytes =
      5 * 1024 * 1024;

  Uri get _uploadUri => Uri.parse(
        'https://api.cloudinary.com/v1_1/'
        '$_cloudName/image/upload',
      );

  // ============================================================
  // SUBIR ESCUDO
  // ============================================================

  Future<String> uploadTeamLogo(
    XFile image,
  ) async {
    final bytes =
        await image.readAsBytes();

    if (bytes.isEmpty) {
      throw const CloudinaryTeamLogoException(
        'La imagen seleccionada está vacía.',
      );
    }

    if (bytes.length >
        _maxFileSizeBytes) {
      throw const CloudinaryTeamLogoException(
        'El escudo debe pesar menos de 5 MB.',
      );
    }

    final extension =
        _getFileExtension(
      image.name,
    );

    if (!_isAllowedExtension(
      extension,
    )) {
      throw const CloudinaryTeamLogoException(
        'El formato de la imagen no es compatible. '
        'Usa JPG, JPEG, PNG o WEBP.',
      );
    }

    final request =
        http.MultipartRequest(
      'POST',
      _uploadUri,
    );

    request.fields[
            'upload_preset'] =
        _uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename:
            image.name,
      ),
    );

    http.StreamedResponse
        response;

    try {
      response =
          await request.send();
    } catch (_) {
      throw const CloudinaryTeamLogoException(
        'No se pudo conectar con el servicio de imágenes. '
        'Revisa tu conexión a internet.',
      );
    }

    final responseBody =
        await response.stream
            .bytesToString();

    Map<String, dynamic>
        data;

    try {
      final decoded =
          jsonDecode(
        responseBody,
      );

      if (decoded
          is! Map<String, dynamic>) {
        throw const FormatException();
      }

      data =
          decoded;
    } catch (_) {
      throw const CloudinaryTeamLogoException(
        'Cloudinary devolvió una respuesta no válida.',
      );
    }

    if (response.statusCode <
            200 ||
        response.statusCode >=
            300) {
      final error =
          data['error'];

      String? message;

      if (error
          is Map<String, dynamic>) {
        final cloudinaryMessage =
            error['message'];

        if (cloudinaryMessage
            is String) {
          message =
              cloudinaryMessage;
        }
      }

      throw CloudinaryTeamLogoException(
        message == null
            ? 'No se pudo subir el escudo.'
            : 'No se pudo subir el escudo: $message',
      );
    }

    final secureUrl =
        data['secure_url'];

    if (secureUrl
            is! String ||
        secureUrl
            .trim()
            .isEmpty) {
      throw const CloudinaryTeamLogoException(
        'Cloudinary no devolvió la URL del escudo.',
      );
    }

    final cleanUrl =
        secureUrl.trim();

    final uri =
        Uri.tryParse(
      cleanUrl,
    );

    if (uri == null ||
        uri.scheme !=
            'https' ||
        uri.host.isEmpty) {
      throw const CloudinaryTeamLogoException(
        'La URL del escudo generada no es válida.',
      );
    }

    return cleanUrl;
  }

  // ============================================================
  // EXTENSIÓN
  // ============================================================

  String _getFileExtension(
    String filename,
  ) {
    final separator =
        filename.lastIndexOf(
      '.',
    );

    if (separator == -1 ||
        separator ==
            filename.length -
                1) {
      return '';
    }

    return filename
        .substring(
          separator + 1,
        )
        .toLowerCase();
  }

  // ============================================================
  // FORMATOS PERMITIDOS
  // ============================================================

  bool _isAllowedExtension(
    String extension,
  ) {
    return const <String>{
      'jpg',
      'jpeg',
      'png',
      'webp',
    }.contains(
      extension,
    );
  }
}

// ================================================================
// EXCEPCIÓN CONTROLADA
// ================================================================

class CloudinaryTeamLogoException
    implements Exception {
  const CloudinaryTeamLogoException(
    this.message,
  );

  final String message;

  @override
  String toString() =>
      message;
}