import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/user_location.dart';

// ================================================================
// BÚSQUEDA DE CIUDADES Y MUNICIPIOS DE MÉXICO
// ================================================================
//
// Usa Nominatim (OpenStreetMap), el mismo proveedor de los mapas de
// canchas. Es gratuito, sin clave, y su política de uso pide:
// - como máximo una búsqueda por segundo (la pantalla espera a que
//   el usuario deje de escribir y guarda resultados en memoria);
// - identificar la aplicación (User-Agent en Android; en la web el
//   navegador envía el Referer automáticamente);
// - dar crédito a OpenStreetMap (se muestra en la pantalla).
//
// Se puede cambiar el servidor con:
//   --dart-define=GEOCODER_URL=https://otro-servidor/search
// ================================================================

class LocationSearchException implements Exception {
  const LocationSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationSearchService {
  LocationSearchService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String _endpoint = String.fromEnvironment(
    'GEOCODER_URL',
    defaultValue: 'https://nominatim.openstreetmap.org/search',
  );

  final http.Client _client;
  final Map<String, List<UserLocation>> _cache = {};

  /// Mínimo de letras antes de buscar.
  static const int minQueryLength = 3;

  Future<List<UserLocation>> search(String query) async {
    final clean = query.trim();

    if (clean.length < minQueryLength) {
      return const <UserLocation>[];
    }

    final key = normalizePlaceName(clean);
    final cached = _cache[key];

    if (cached != null) {
      return cached;
    }

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: <String, String>{
        'q': clean,
        'countrycodes': 'mx',
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '8',
        'accept-language': 'es',
        'featureType': 'settlement',
      },
    );

    http.Response response;

    try {
      response = await _client
          .get(
            uri,
            headers: kIsWeb
                ? const <String, String>{}
                : const <String, String>{
                    'User-Agent': 'CanchaYA/1.0 (app de ligas de futbol)',
                  },
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const LocationSearchException(
        'No hay conexión. Elige una de las ciudades con canchas o '
        'inténtalo de nuevo.',
      );
    }

    if (response.statusCode == 429) {
      throw const LocationSearchException(
        'Demasiadas búsquedas seguidas. Espera unos segundos.',
      );
    }

    if (response.statusCode != 200) {
      throw const LocationSearchException(
        'El buscador de ciudades no respondió. Inténtalo más tarde.',
      );
    }

    final results = parseNominatimResults(utf8.decode(response.bodyBytes));
    _cache[key] = results;

    return results;
  }
}

/// Convierte la respuesta JSON de Nominatim en ciudades sin repetir.
///
/// Se separa para poder probarla sin conexión.
List<UserLocation> parseNominatimResults(String body) {
  final Object? decoded;

  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return const <UserLocation>[];
  }

  if (decoded is! List) {
    return const <UserLocation>[];
  }

  final results = <UserLocation>[];
  final seen = <String>{};

  for (final item in decoded) {
    if (item is! Map) continue;

    final address = item['address'];
    final addressMap = address is Map ? address : const {};

    final countryCode = (addressMap['country_code'] as String?) ?? 'mx';

    if (countryCode.toLowerCase() != 'mx') continue;

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = addressMap[key];

        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }

      return '';
    }

    final name = (item['name'] as String?)?.trim() ?? '';
    final city = name.isNotEmpty
        ? name
        : pick(['city', 'town', 'village', 'municipality', 'county']);
    final state = pick(['state']);

    if (city.isEmpty) continue;

    final latitude = double.tryParse('${item['lat']}');
    final longitude = double.tryParse('${item['lon']}');

    final location = UserLocation(
      city: city,
      state: state,
      latitude: latitude,
      longitude: longitude,
    );

    final key =
        '${normalizePlaceName(location.city)}|${normalizePlaceName(location.state)}';

    if (seen.add(key)) {
      results.add(location);
    }
  }

  return results;
}
