import 'dart:convert';

import 'package:cancha_ya/features/courts/data/osm_pitch_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Formato de Overpass con "out center": los nodos traen lat/lon y las
// áreas (way/relation) traen "center".
const String _overpassSample = '''
{
  "version": 0.6,
  "elements": [
    {"type": "node", "id": 1, "lat": 26.08, "lon": -98.29,
     "tags": {"leisure": "pitch", "sport": "soccer", "name": "Cancha Las Fuentes"}},
    {"type": "way", "id": 2, "center": {"lat": 26.09, "lon": -98.30},
     "tags": {"leisure": "pitch", "sport": "soccer", "surface": "artificial_turf",
              "addr:street": "Calle Morelos"}},
    {"type": "way", "id": 2, "center": {"lat": 26.09, "lon": -98.30},
     "tags": {"leisure": "pitch", "sport": "soccer"}},
    {"type": "way", "id": 3, "tags": {"leisure": "pitch"}},
    {"type": "node", "id": 4, "lat": 999, "lon": 0, "tags": {}}
  ]
}
''';

void main() {
  test('lee nodos y áreas, sin duplicados ni coordenadas inválidas', () {
    final pitches = parseOverpassPitches(_overpassSample);

    expect(pitches.map((p) => p.id), ['node/1', 'way/2']);
    expect(pitches.first.displayName, 'Cancha Las Fuentes');
    expect(pitches.first.latitude, 26.08);
    expect(pitches.last.displayName, 'Cancha de fútbol');
    expect(pitches.last.surfaceLabel, 'Pasto sintético');
    expect(pitches.last.street, 'Calle Morelos');
  });

  test('respuesta inválida no rompe la app', () {
    expect(parseOverpassPitches('no es json'), isEmpty);
    expect(parseOverpassPitches('{"remark": "timeout"}'), isEmpty);
  });

  test('ruta hacia la cancha por coordenadas', () {
    const pitch = OsmPitch(id: 'n/1', name: '', latitude: 26.1, longitude: -98.3);

    expect(pitch.directionsUri.queryParameters['destination'], '26.1,-98.3');
  });

  test('consulta Overpass, amplía el radio si hay pocas y guarda en memoria',
      () async {
    final radii = <String>[];

    final service = OsmPitchService(
      endpoints: const ['https://overpass.test/api/interpreter'],
      client: MockClient((request) async {
        final body = Uri.decodeQueryComponent(request.body);
        radii.add(RegExp(r'around:(\d+),').firstMatch(body)!.group(1)!);
        expect(body, contains('"leisure"="pitch"'));
        return http.Response(_overpassSample, 200);
      }),
    );

    final first = await service.search(26.0801, -98.2901);
    final second = await service.search(26.0799, -98.2899);

    // La muestra tiene 2 canchas (< 3): se prueban 10, 25 y 50 km.
    expect(radii, ['10000', '25000', '50000']);
    expect(first.pitches.length, 2);
    expect(first.radiusKm, 50);
    expect(second, same(first));
  });

  test('con suficientes canchas no amplía el radio', () async {
    final radii = <String>[];
    final many = jsonEncode({
      'elements': [
        for (var i = 0; i < 4; i++)
          {'type': 'node', 'id': i, 'lat': 26.0 + i / 100, 'lon': -98.0},
      ],
    });

    final service = OsmPitchService(
      endpoints: const ['https://overpass.test/api/interpreter'],
      client: MockClient((request) async {
        final body = Uri.decodeQueryComponent(request.body);
        radii.add(RegExp(r'around:(\d+),').firstMatch(body)!.group(1)!);
        return http.Response(many, 200);
      }),
    );

    final result = await service.search(26.0, -98.0);

    expect(radii, ['${OsmPitchService.radiusMeters}']);
    expect(result.radiusKm, 10);
    // Ordenadas de la más cercana a la más lejana.
    expect(result.pitches.first.id, 'node/0');
  });

  test('si un servidor está ocupado usa el siguiente', () async {
    final hosts = <String>[];

    final service = OsmPitchService(
      endpoints: const [
        'https://ocupado.test/api/interpreter',
        'https://respaldo.test/api/interpreter',
      ],
      client: MockClient((request) async {
        hosts.add(request.url.host);
        return request.url.host == 'ocupado.test'
            ? http.Response('', 429)
            : http.Response(_overpassSample, 200);
      }),
    );

    final result = await service.pitchesAround(26.0, -98.0);

    expect(result.length, 2);
    expect(hosts.first, 'ocupado.test');
    expect(hosts, contains('respaldo.test'));
  });

  test('errores con mensaje claro', () async {
    final busy = OsmPitchService(
      client: MockClient((_) async => http.Response('', 429)),
    );
    final offline = OsmPitchService(
      client: MockClient((_) async => throw Exception('sin red')),
    );

    expect(() => busy.pitchesAround(26, -98), throwsA(isA<OsmPitchException>()));
    expect(() => offline.pitchesAround(26, -98), throwsA(isA<OsmPitchException>()));
  });
}
