import 'package:cancha_ya/features/courts/domain/court.dart';
import 'package:cancha_ya/features/tournaments/data/tournament_schedule_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Routes use coordinates when valid and address when missing', () {
    const located = Court(
      id: 'a',
      name: 'Escuela',
      address: 'Calle 1',
      latitude: 25.1,
      longitude: -99.8,
    );
    expect(located.directionsUri.queryParameters['destination'], '25.1,-99.8');
    const missing = Court(
      id: 'b',
      name: 'Escuela #2',
      address: 'Calle Niños & Héroes',
    );
    expect(missing.hasCoordinates, isFalse);
    expect(
      missing.directionsUri.queryParameters['destination'],
      contains('Niños & Héroes'),
    );
    expect(missing.directionsUri.queryParameters['api'], '1');
  });
  test('Rejects out-of-range, partial and non-finite map positions', () {
    for (final values in [
      [91.0, 0.0],
      [0.0, 181.0],
      [double.nan, 0.0],
      [0.0, double.infinity],
    ]) {
      expect(
        Court(
          id: 'a',
          name: 'a',
          address: 'a',
          latitude: values[0],
          longitude: values[1],
        ).hasCoordinates,
        isFalse,
      );
    }
    expect(
      const Court(
        id: 'a',
        name: 'a',
        address: 'a',
        latitude: 25,
      ).hasCoordinates,
      isFalse,
    );
  });
  test('Existing unscheduled matches remain compatible', () {
    final old = TournamentMatchRecord.fromMap('m', {
      'homeTeamName': 'A',
      'awayTeamName': 'B',
    });
    expect(old.startsAt, isNull);
    expect(old.courtId, isNull);
    final time = DateTime.utc(2027, 1, 1, 18);
    final scheduled = TournamentMatchRecord.fromMap('m', {
      'courtId': 'c',
      'startsAt': Timestamp.fromDate(time),
    });
    expect(scheduled.startsAt!.toUtc(), time);
    expect(scheduled.courtId, 'c');
  });
  test(
    'Example import IDs are unique and unverified coordinates are absent',
    () {
      expect(
        montemorelosCourts.map((c) => c.id).toSet().length,
        montemorelosCourts.length,
      );
      expect(montemorelosCourts.where((c) => c.hasCoordinates).length, 1);
      expect(montemorelosCourts.every((c) => c.address.isNotEmpty), isTrue);
    },
  );
}
