import 'dart:convert';

import 'package:cancha_ya/features/courts/domain/court.dart';
import 'package:cancha_ya/features/location/data/location_controller.dart';
import 'package:cancha_ya/features/location/data/location_search_service.dart';
import 'package:cancha_ya/features/location/domain/user_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Respuesta con el formato jsonv2 documentado de Nominatim.
const String _nominatimSample = '''
[
  {
    "place_id": 1, "lat": "24.8597", "lon": "-99.5664",
    "category": "place", "type": "city", "addresstype": "city",
    "name": "Linares", "display_name": "Linares, Nuevo León, México",
    "address": {"city": "Linares", "state": "Nuevo León",
      "country": "México", "country_code": "mx"}
  },
  {
    "place_id": 2, "lat": "24.86", "lon": "-99.57",
    "category": "boundary", "type": "administrative",
    "addresstype": "municipality", "name": "Linares",
    "address": {"municipality": "Linares", "state": "Nuevo León",
      "country_code": "mx"}
  },
  {
    "place_id": 3, "lat": "20.6", "lon": "-103.3",
    "addresstype": "town", "name": "",
    "address": {"town": "Tlaquepaque", "state": "Jalisco",
      "country_code": "mx"}
  },
  {
    "place_id": 4, "lat": "29.4", "lon": "-98.5",
    "addresstype": "city", "name": "San Antonio",
    "address": {"city": "San Antonio", "state": "Texas",
      "country_code": "us"}
  },
  {"place_id": 5, "lat": "x", "lon": "y", "name": "Sin coordenadas",
    "address": {"state": "Coahuila", "country_code": "mx"}}
]
''';

void main() {
  group('UserLocation', () {
    test('etiqueta corta con abreviatura del estado', () {
      expect(UserLocation.montemorelos.label, 'Montemorelos, N.L.');
      expect(
        const UserLocation(city: 'Guadalajara', state: 'Jalisco').label,
        'Guadalajara, Jal.',
      );
      expect(
        const UserLocation(city: 'Ciudad X', state: '').label,
        'Ciudad X',
      );
    });

    test('compara ciudades sin acentos ni mayúsculas', () {
      const location = UserLocation(city: 'San Nicolás', state: 'Nuevo León');

      expect(location.matchesCity('san nicolas'), isTrue);
      expect(location.matchesCity('  SAN   NICOLÁS '), isTrue);
      expect(location.matchesCity('Linares'), isFalse);
    });

    test('distancia en km y null sin coordenadas', () {
      final km = UserLocation.montemorelos.distanceKmTo(25.187, -99.828);
      expect(km, closeTo(0, 0.01));

      // Montemorelos -> Linares: ~40 km en línea recta.
      final linares = UserLocation.montemorelos.distanceKmTo(24.8597, -99.5664);
      expect(linares, inInclusiveRange(30, 55));

      const noCoords = UserLocation(city: 'X', state: '');
      expect(noCoords.distanceKmTo(25, -99), isNull);
    });

    test('perfil sin ciudad usa Montemorelos', () {
      expect(UserLocation.fromMap(null), UserLocation.montemorelos);
      expect(UserLocation.fromMap(const {'city': ''}), UserLocation.montemorelos);
    });

    test('ida y vuelta con el perfil', () {
      const linares = UserLocation(
        city: 'Linares',
        state: 'Nuevo León',
        latitude: 24.86,
        longitude: -99.57,
      );

      final restored = UserLocation.fromMap(linares.toMap());

      expect(restored, linares);
      expect(restored.latitude, 24.86);
      expect(linares.toMap().keys,
          containsAll(['city', 'state', 'latitude', 'longitude']));
    });

    test('coordenadas fuera de rango no se guardan', () {
      const bad = UserLocation(
        city: 'X',
        state: '',
        latitude: 120,
        longitude: 0,
      );

      expect(bad.hasCoordinates, isFalse);
      expect(bad.toMap()['latitude'], isNull);
      expect(bad.toMap()['longitude'], isNull);
    });
  });

  group('Búsqueda de ciudades', () {
    test('interpreta la respuesta de Nominatim', () {
      final results = parseNominatimResults(_nominatimSample);

      // Linares aparece una vez, Tlaquepaque se toma de "town",
      // San Antonio (EE.UU.) se descarta.
      expect(results.map((r) => r.label), [
        'Linares, N.L.',
        'Tlaquepaque, Jal.',
        'Sin coordenadas, Coah.',
      ]);
      expect(results.first.latitude, 24.8597);
      expect(results.last.hasCoordinates, isFalse);
    });

    test('respuesta inválida no rompe la app', () {
      expect(parseNominatimResults('no es json'), isEmpty);
      expect(parseNominatimResults('{"error": "x"}'), isEmpty);
    });

    test('consulta solo México, en español, y guarda en memoria', () async {
      var calls = 0;
      late Uri lastUri;

      final service = LocationSearchService(
        client: MockClient((request) async {
          calls++;
          lastUri = request.url;
          return http.Response.bytes(utf8.encode(_nominatimSample), 200);
        }),
      );

      final first = await service.search('Linares');
      final second = await service.search('  linares ');

      expect(first, isNotEmpty);
      expect(second, first);
      expect(calls, 1);
      expect(lastUri.queryParameters['countrycodes'], 'mx');
      expect(lastUri.queryParameters['accept-language'], 'es');
    });

    test('menos de 3 letras no consulta', () async {
      var calls = 0;
      final service = LocationSearchService(
        client: MockClient((_) async {
          calls++;
          return http.Response('[]', 200);
        }),
      );

      expect(await service.search('Li'), isEmpty);
      expect(calls, 0);
    });

    test('errores con mensaje claro', () async {
      final limited = LocationSearchService(
        client: MockClient((_) async => http.Response('', 429)),
      );
      final offline = LocationSearchService(
        client: MockClient((_) async => throw Exception('sin red')),
      );

      expect(
        () => limited.search('Linares'),
        throwsA(isA<LocationSearchException>()),
      );
      expect(
        () => offline.search('Linares'),
        throwsA(isA<LocationSearchException>()),
      );
    });
  });

  group('Ciudades con canchas', () {
    test('agrupa por ciudad y promedia coordenadas reales', () {
      final cities = citiesFromCourts(const [
        Court(id: 'a', name: 'A', address: 'x', city: 'Montemorelos',
            latitude: 25.0, longitude: -99.0),
        Court(id: 'b', name: 'B', address: 'x', city: 'montemorelos',
            latitude: 25.2, longitude: -99.2),
        Court(id: 'c', name: 'C', address: 'x', city: 'Allende'),
        Court(id: 'd', name: 'D', address: 'x', city: 'Linares',
            active: false, latitude: 24.8, longitude: -99.5),
      ]);

      expect(cities.map((c) => c.city), ['Allende', 'Montemorelos']);
      expect(cities.first.hasCoordinates, isFalse);
      expect(cities.last.latitude, closeTo(25.1, 0.0001));
      expect(cities.last.longitude, closeTo(-99.1, 0.0001));
    });
  });
}
