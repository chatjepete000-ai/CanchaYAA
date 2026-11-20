import 'package:cancha_ya/features/notifications/domain/app_notification.dart';
import 'package:cancha_ya/features/notifications/domain/match_alerts.dart';
import 'package:cancha_ya/features/tournaments/domain/match_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estados del partido', () {
    test('etiquetas en español', () {
      expect(matchStatusLabel('scheduled'), 'Programado');
      expect(matchStatusLabel('postponed'), 'Suspendido');
      expect(matchStatusLabel('cancelled'), 'Cancelado');
      expect(matchStatusLabel('completed'), 'Finalizado');
    });

    test('detalle con motivo y nota', () {
      expect(
        matchStatusDetail(status: 'postponed', reason: 'weather'),
        'Suspendido · Clima',
      );
      expect(
        matchStatusDetail(
          status: 'cancelled',
          reason: 'court',
          note: 'Cancha inundada',
        ),
        'Cancelado · Cancha no disponible (Cancha inundada)',
      );
      expect(matchStatusDetail(status: 'postponed'), 'Suspendido');
    });

    test('motivos se leen y escriben igual que en las reglas', () {
      for (final reason in MatchStatusReason.values) {
        expect(MatchStatusReasonX.fromValue(reason.value), reason);
      }
      expect(MatchStatusReasonX.fromValue('lluvia'), isNull);
    });

    test('la nota se limpia y se recorta', () {
      expect(cleanMatchStatusNote('  tormenta \n eléctrica '),
          'tormenta eléctrica');
      expect(cleanMatchStatusNote('x' * 200).length, maxMatchStatusNoteLength);
    });
  });

  group('avisos de suspensión o cancelación', () {
    final start = DateTime.utc(2026, 11, 21, 0);

    test('clave única por cada cambio y dentro del límite', () {
      final key = statusChangeEventKey(
        cancelled: false,
        changedAt: DateTime.utc(2026, 11, 20, 12),
      );

      expect(key, startsWith('susp_'));
      expect(key.length, lessThanOrEqualTo(40));
      expect(
        statusChangeEventKey(cancelled: true, changedAt: start),
        startsWith('cancel_'),
      );
    });

    test('textos de suspensión por clima', () {
      expect(
        statusChangeTitle(cancelled: false, home: 'Tigres', away: 'Leones'),
        'Suspendido: Tigres vs Leones',
      );

      final body = statusChangeFullBody(
        cancelled: false,
        home: 'Tigres',
        away: 'Leones',
        reasonLabel: 'Clima',
        note: 'tormenta eléctrica',
        previousStartsAt: start,
      );

      expect(body, contains('Se suspendió el partido Tigres vs Leones'));
      expect(body, contains('por clima (tormenta eléctrica)'));
      expect(body, contains('nuevo horario'));
    });

    test('texto de cancelación aclara que no cuenta en la tabla', () {
      final body = statusChangeFullBody(
        cancelled: true,
        home: 'A',
        away: 'B',
        reasonLabel: 'Otro motivo',
      );

      expect(body, contains('Se canceló'));
      expect(body, contains('no cuenta en la tabla'));
    });

    test('título largo no rebasa 120 caracteres', () {
      final title = statusChangeTitle(
        cancelled: true,
        home: 'x' * 80,
        away: 'y' * 80,
      );

      expect(title.length, lessThanOrEqualTo(120));
    });

    test('tipos nuevos en la bandeja', () {
      expect(
        AppNotificationTypeX.fromValue('match_postponed'),
        AppNotificationType.matchPostponed,
      );
      expect(
        AppNotificationTypeX.fromValue('match_cancelled'),
        AppNotificationType.matchCancelled,
      );
      expect(AppNotificationType.matchPostponed.label, 'Partido suspendido');
    });
  });
}
