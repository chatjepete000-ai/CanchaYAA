import 'package:cancha_ya/features/notifications/domain/match_alerts.dart';
import 'package:cancha_ya/features/notifications/services/match_crest_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final kickoff = DateTime.utc(2026, 11, 14, 0); // 6:00 PM en Monterrey

  test('recordatorios 24 h, 1 h y al inicio', () {
    expect(
      reminderFireTime(kickoff, MatchReminderKind.dayBefore),
      DateTime.utc(2026, 11, 13, 0),
    );
    expect(
      reminderFireTime(kickoff, MatchReminderKind.hourBefore),
      DateTime.utc(2026, 11, 13, 23),
    );
    expect(reminderFireTime(kickoff, MatchReminderKind.kickoff), kickoff);
  });

  test('con tiempo suficiente se programan los tres', () {
    final now = kickoff.subtract(const Duration(days: 3));

    expect(upcomingReminders(kickoff, now), MatchReminderKind.values);
  });

  test('si faltan menos de 24 h se omite el de 24 h', () {
    final now = kickoff.subtract(const Duration(hours: 5));

    expect(
      upcomingReminders(kickoff, now),
      [MatchReminderKind.hourBefore, MatchReminderKind.kickoff],
    );
  });

  test('partido ya iniciado no programa nada', () {
    expect(upcomingReminders(kickoff, kickoff.add(const Duration(minutes: 1))),
        isEmpty);
  });

  test('recordatorios vencidos que van a la bandeja', () {
    final now = kickoff.subtract(const Duration(minutes: 30));

    expect(
      dueReminders(kickoff, now),
      [MatchReminderKind.dayBefore, MatchReminderKind.hourBefore],
    );
  });

  test('partidos viejos no llenan la bandeja', () {
    final now = kickoff.add(const Duration(days: 5));

    expect(dueReminders(kickoff, now), isEmpty);
  });

  test('IDs estables: el mismo aviso siempre tiene el mismo ID', () {
    final first = reminderNotificationId('m1', MatchReminderKind.hourBefore);
    final second = reminderNotificationId('m1', MatchReminderKind.hourBefore);

    expect(first, second);
    expect(first, isNonNegative);
    expect(
      first,
      isNot(reminderNotificationId('m1', MatchReminderKind.dayBefore)),
    );
    expect(
      first,
      isNot(reminderNotificationId('m2', MatchReminderKind.hourBefore)),
    );
  });

  test('ID del documento de la bandeja', () {
    expect(
      matchNotificationDocId(
        matchId: 'm1',
        eventKey: scheduleEventKey(kickoff),
        recipientUserId: 'u1',
      ),
      'm1_sched_${kickoff.millisecondsSinceEpoch}_u1',
    );
    expect(resultEventKey(2), 'result_v2');
    expect(MatchReminderKind.dayBefore.key, 'r24');
  });

  test('texto corto con hora AM/PM y cancha', () {
    final local = DateTime(2026, 11, 14, 18);

    expect(
      reminderShortBody(
        kind: MatchReminderKind.hourBefore,
        startsAt: local,
        courtName: 'Cancha Escuela',
      ),
      'Falta 1 hora · 6:00 PM · Dirígete a Cancha Escuela.',
    );
    expect(
      reminderShortBody(
        kind: MatchReminderKind.kickoff,
        startsAt: local,
        courtName: '',
      ),
      'Dirígete a la cancha.',
    );
  });

  test('mensaje completo para la bandeja', () {
    final body = reminderFullBody(
      kind: MatchReminderKind.dayBefore,
      myTeam: 'Diablos Emiliano',
      rival: 'Tigres',
      startsAt: DateTime(2026, 11, 14, 18),
      courtName: 'Cancha Escuela',
    );

    expect(body, contains('Faltan 24 horas'));
    expect(body, contains('Diablos Emiliano vs Tigres'));
    expect(body, contains('sábado 14 nov'));
    expect(body, contains('6:00 PM'));
    expect(body, contains('Cancha Escuela'));
  });

  test('imagen con escudos genéricos cuando no hay logo', () async {
    final bytes = await MatchCrestImage.build(
      homeName: 'Diablos Emiliano',
      awayName: 'Tigres',
    );

    expect(bytes, isNotNull);
    // Firma PNG.
    expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
