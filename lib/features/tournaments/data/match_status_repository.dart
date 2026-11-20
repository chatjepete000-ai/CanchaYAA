import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/match_status.dart';
import 'tournament_schedule_repository.dart';

// ================================================================
// SUSPENDER O CANCELAR UN PARTIDO (solo administrador de la liga)
// ================================================================
//
// En un solo batch:
//   1. Se borra la reserva de la cancha (courtBookings) y las de los
//      dos equipos (teamBookings), para que ese horario quede libre.
//   2. El partido pasa a postponed (suspendido) o cancelled
//      (cancelado), sin cancha ni horario, con el motivo.
//
// firestore.rules exige que las reservas queden liberadas en el
// mismo batch y que el motivo sea válido. Los avisos a los equipos
// los envía después MatchNotificationPublisher.
// ================================================================

class MatchStatusRepository {
  MatchStatusRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> suspend({
    required TournamentMatchRecord match,
    required MatchStatusReason reason,
    String note = '',
  }) {
    return _change(
      match: match,
      status: 'postponed',
      reason: reason,
      note: note,
      allowedFrom: const {'scheduled'},
    );
  }

  Future<void> cancel({
    required TournamentMatchRecord match,
    required MatchStatusReason reason,
    String note = '',
  }) {
    return _change(
      match: match,
      status: 'cancelled',
      reason: reason,
      note: note,
      allowedFrom: const {'scheduled', 'postponed'},
    );
  }

  Future<void> _change({
    required TournamentMatchRecord match,
    required String status,
    required MatchStatusReason reason,
    required String note,
    required Set<String> allowedFrom,
  }) async {
    final matchRef = _firestore.collection('tournamentMatches').doc(match.id);

    final snapshot = await matchRef.get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw StateError('El partido ya no existe.');
    }

    final current = data['status'] as String? ?? 'scheduled';

    if (!allowedFrom.contains(current)) {
      throw StateError(
        current == 'completed'
            ? 'El partido ya tiene resultado.'
            : 'El partido ya está ${matchStatusLabel(current).toLowerCase()}.',
      );
    }

    final batch = _firestore.batch();

    final bookingId = data['bookingId'] as String?;
    final startsAt = data['startsAt'] as Timestamp?;

    if (bookingId != null && bookingId.isNotEmpty) {
      batch.delete(_firestore.collection('courtBookings').doc(bookingId));
    }

    if (startsAt != null) {
      for (final key in ['homeTeamId', 'awayTeamId']) {
        final teamId = data[key] as String? ?? '';

        if (teamId.isEmpty) continue;

        batch.delete(
          _firestore
              .collection('teamBookings')
              .doc('${teamId}_${startsAt.millisecondsSinceEpoch}'),
        );
      }
    }

    final cleanNote = cleanMatchStatusNote(note);

    batch.update(matchRef, <String, dynamic>{
      'status': status,
      'statusReason': reason.value,
      'statusNote': cleanNote.isEmpty ? FieldValue.delete() : cleanNote,
      if (data.containsKey('courtId')) 'courtId': FieldValue.delete(),
      if (data.containsKey('courtName')) 'courtName': FieldValue.delete(),
      if (data.containsKey('startsAt')) 'startsAt': FieldValue.delete(),
      if (data.containsKey('bookingId')) 'bookingId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
