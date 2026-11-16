import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ================================================================
// CANCHAS SUGERIDAS (OPENSTREETMAP)
// ================================================================
//
// Busca canchas de fútbol que ya existen en OpenStreetMap alrededor
// de la ciudad elegida (Overpass API, gratuita y sin clave).
//
// Son SUGERENCIAS: no están registradas en CanchaYA, no se pueden
// usar para programar partidos y solo muestran ubicación y ruta. Un
// administrador puede registrarlas como cancha de CanchaYA.
//
// Se puede cambiar el servidor con:
//   --dart-define=OVERPASS_URL=https://otro-servidor/api/interpreter
// ================================================================

class OsmPitch {
  const OsmPitch({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.surface = '',
    this.street = '',
  });

  /// "way/123", "node/456"...
  final String id;

  /// Nombre en OpenStreetMap ('' si no tiene).
  final String name;
  final double latitude;
  final double longitude;
  final String surface;
  final String street;

  String get displayName =>
      name.trim().isEmpty ? 'Cancha de fútbol' : name.trim();

  /// Superficie en español (pasto, sintético...).
  String get surfaceLabel {
    switch (surface) {
      case 'grass':
        return 'Pasto natural';
      case 'artificial_turf':
        return 'Pasto sintético';
      case 'dirt':
      case 'ground':
      case 'earth':
      case 'sand':
        return 'Tierra';
      case 'concrete':
      case 'asphalt':
      case 'paved':
        return 'Cemento';
      default:
        return '';
    }
  }

  Uri get directionsUri => Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
      });
}

class OsmPitchException implements Exception {
  const OsmPitchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OsmPitchService {
  OsmPitchService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String _endpoint = String.fromEnvironment(
    'OVERPASS_URL',
    defaultValue: 'https://overpass-api.de/api/interpreter',
  );

  /// Radio de búsqueda alrededor de la ciudad.
  static const int radiusMeters = 10000;

  /// Máximo de canchas sugeridas.
  static const int maxResults = 60;

  final http.Client _client;
  final Map<String, List<OsmPitch>> _cache = {};

  Future<List<OsmPitch>> pitchesAround(double latitude, double longitude) async {
    // Se redondea para reutilizar resultados de la misma ciudad.
    final key =
        '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';
    final cached = _cache[key];

    if (cached != null) {
      return cached;
    }

    final query = '''
[out:json][timeout:25];
nwr["leisure"="pitch"]["sport"~"soccer|football|futsal"](around:$radiusMeters,$latitude,$longitude);
out center $maxResults;
''';

    http.Response response;

    try {
      response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: kIsWeb
                ? const <String, String>{}
                : const <String, String>{
                    'User-Agent': 'CanchaYA/1.0 (app de ligas de futbol)',
                  },
            body: <String, String>{'data': query},
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const OsmPitchException(
        'No se pudieron consultar canchas en OpenStreetMap. Revisa tu '
        'conexión.',
      );
    }

    if (response.statusCode == 429 || response.statusCode == 504) {
      throw const OsmPitchException(
        'OpenStreetMap está ocupado. Inténtalo en unos minutos.',
      );
    }

    if (response.statusCode != 200) {
      throw const OsmPitchException(
        'OpenStreetMap no respondió. Inténtalo más tarde.',
      );
    }

    final pitches = parseOverpassPitches(utf8.decode(response.bodyBytes));
    _cache[key] = pitches;

    return pitches;
  }
}

/// Convierte la respuesta de Overpass (`out center`) en canchas.
///
/// Los nodos traen lat/lon; las áreas (way/relation) traen `center`.
List<OsmPitch> parseOverpassPitches(String body) {
  final Object? decoded;

  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return const <OsmPitch>[];
  }

  if (decoded is! Map || decoded['elements'] is! List) {
    return const <OsmPitch>[];
  }

  final pitches = <OsmPitch>[];
  final seen = <String>{};

  for (final element in decoded['elements'] as List) {
    if (element is! Map) continue;

    final type = '${element['type'] ?? ''}';
    final id = '$type/${element['id'] ?? ''}';

    final center = element['center'];
    final latitude = _toDouble(
      center is Map ? center['lat'] : element['lat'],
    );
    final longitude = _toDouble(
      center is Map ? center['lon'] : element['lon'],
    );

    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      continue;
    }

    if (!seen.add(id)) continue;

    final tags = element['tags'] is Map ? element['tags'] as Map : const {};

    String tag(String key) {
      final value = tags[key];
      return value is String ? value.trim() : '';
    }

    pitches.add(
      OsmPitch(
        id: id,
        name: tag('name'),
        latitude: latitude,
        longitude: longitude,
        surface: tag('surface'),
        street: tag('addr:street'),
      ),
    );
  }

  return pitches;
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
