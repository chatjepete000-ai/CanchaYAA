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

  test('consulta Overpass con radio y guarda en memoria', () async {
    var calls = 0;
    late String body;

    final service = OsmPitchService(
      client: MockClient((request) async {
        calls++;
        body = Uri.decodeQueryComponent(request.body);
        return http.Response(_overpassSample, 200);
      }),
    );

    final first = await service.pitchesAround(26.0801, -98.2901);
    final second = await service.pitchesAround(26.0799, -98.2899);

    expect(first.length, 2);
    expect(second, same(first));
    expect(calls, 1);
    expect(body, contains('around:${OsmPitchService.radiusMeters},26.0801,-98.2901'));
    expect(body, contains('"leisure"="pitch"'));
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
