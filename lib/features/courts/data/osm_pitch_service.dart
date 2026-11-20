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

/// Resultado de una búsqueda: las canchas y el radio que se usó.
class OsmPitchSearch {
  const OsmPitchSearch({required this.pitches, required this.radiusMeters});

  final List<OsmPitch> pitches;
  final int radiusMeters;

  int get radiusKm => (radiusMeters / 1000).round();
}

class OsmPitchService {
  OsmPitchService({http.Client? client, List<String>? endpoints})
    : _client = client ?? http.Client(),
      _endpoints = endpoints ?? defaultEndpoints;

  static const String _customEndpoint = String.fromEnvironment('OVERPASS_URL');

  /// Servidores públicos de Overpass. Si el primero está ocupado
  /// (429/504) o no responde, se intenta con el siguiente.
  static List<String> get defaultEndpoints => [
    if (_customEndpoint.isNotEmpty) _customEndpoint,
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  /// Primer radio de búsqueda alrededor de la ciudad.
  static const int radiusMeters = 10000;

  /// Si hay pocas canchas, se amplía el radio en estos pasos (pueblos
  /// pequeños o centros de municipio alejados de la cabecera).
  static const List<int> radiusStepsMeters = [10000, 25000, 50000];

  /// Con al menos estas canchas ya no se amplía el radio.
  static const int enoughResults = 3;

  /// Máximo de canchas sugeridas.
  static const int maxResults = 60;

  final http.Client _client;
  final List<String> _endpoints;
  final Map<String, OsmPitchSearch> _cache = {};

  Future<List<OsmPitch>> pitchesAround(
    double latitude,
    double longitude,
  ) async {
    return (await search(latitude, longitude)).pitches;
  }

  /// Busca alrededor del punto y amplía el radio si hay muy pocas.
  Future<OsmPitchSearch> search(double latitude, double longitude) async {
    // Se redondea para reutilizar resultados de la misma ciudad.
    final key =
        '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';
    final cached = _cache[key];

    if (cached != null) {
      return cached;
    }

    OsmPitchSearch? found;

    for (final radius in radiusStepsMeters) {
      List<OsmPitch> pitches;

      try {
        pitches = await _query(latitude, longitude, radius);
      } on OsmPitchException {
        // Si un radio mayor falla, se queda lo que ya se encontró.
        if (found != null) break;
        rethrow;
      }

      found = OsmPitchSearch(pitches: pitches, radiusMeters: radius);

      if (pitches.length >= enoughResults) break;
    }

    _cache[key] = found!;

    return found;
  }

  Future<List<OsmPitch>> _query(
    double latitude,
    double longitude,
    int radius,
  ) async {
    final query =
        '''
[out:json][timeout:25];
nwr["leisure"="pitch"]["sport"~"soccer|football|futsal"](around:$radius,$latitude,$longitude);
out center $maxResults;
''';

    OsmPitchException? lastError;

    for (final endpoint in _endpoints) {
      http.Response response;

      try {
        response = await _client
            .post(
              Uri.parse(endpoint),
              headers: kIsWeb
                  ? const <String, String>{}
                  : const <String, String>{
                      'User-Agent': 'CanchaYA/1.0 (app de ligas de futbol)',
                    },
              body: <String, String>{'data': query},
            )
            .timeout(const Duration(seconds: 30));
      } catch (_) {
        lastError = const OsmPitchException(
          'No se pudieron consultar canchas en OpenStreetMap. Revisa tu '
          'conexión.',
        );
        continue;
      }

      if (response.statusCode == 429 || response.statusCode == 504) {
        lastError = const OsmPitchException(
          'OpenStreetMap está ocupado. Inténtalo en unos minutos.',
        );
        continue;
      }

      if (response.statusCode != 200) {
        lastError = const OsmPitchException(
          'OpenStreetMap no respondió. Inténtalo más tarde.',
        );
        continue;
      }

      final pitches = parseOverpassPitches(utf8.decode(response.bodyBytes));

      pitches.sort(
        (a, b) => _squaredDistance(
          a,
          latitude,
          longitude,
        ).compareTo(_squaredDistance(b, latitude, longitude)),
      );

      return pitches;
    }

    throw lastError ??
        const OsmPitchException(
          'OpenStreetMap no respondió. Inténtalo más tarde.',
        );
  }

  static double _squaredDistance(OsmPitch pitch, double lat, double lon) {
    final dLat = pitch.latitude - lat;
    final dLon = pitch.longitude - lon;
    return dLat * dLat + dLon * dLon;
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
    final latitude = _toDouble(center is Map ? center['lat'] : element['lat']);
    final longitude = _toDouble(center is Map ? center['lon'] : element['lon']);

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
