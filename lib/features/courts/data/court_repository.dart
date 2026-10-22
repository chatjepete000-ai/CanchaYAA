import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/court.dart';
import '../../tournaments/data/tournament_schedule_repository.dart';

class CourtRepository {
  CourtRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Stream<List<Court>> watchCourts() => _db.collection('courts').snapshots().map(
    (s) {
      final courts = s.docs.map((d) => Court.fromMap(d.id, d.data())).toList();
      courts.sort((a, b) => a.name.compareTo(b.name));
      return courts;
    },
  );

  Future<void> save(Court court) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Inicia sesión para guardar una cancha.');
    if (court.name.trim().isEmpty ||
        court.address.trim().isEmpty ||
        court.city.trim().isEmpty) {
      throw ArgumentError('Completa el nombre, la dirección y la ciudad.');
    }
    if ((court.latitude != null || court.longitude != null) &&
        !court.hasCoordinates) {
      throw ArgumentError('Selecciona una ubicación válida.');
    }
    final ref = _db
        .collection('courts')
        .doc(court.id.isEmpty ? null : court.id);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        tx.update(ref, {
          ...court.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          ...court.toMap(),
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> importExamples() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Inicia sesión.');
    // Stable IDs and transactions make repeated imports safe, preserving edits.
    for (final court in montemorelosCourts) {
      final ref = _db.collection('courts').doc(court.id);
      await _db.runTransaction((tx) async {
        if (!(await tx.get(ref)).exists) {
          tx.set(ref, {
            ...court.toMap(),
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    }
  }

  Stream<List<TournamentMatchRecord>> watchCourtMatches(String courtId) => _db
      .collection('tournamentMatches')
      .where('courtId', isEqualTo: courtId)
      .where('status', isEqualTo: 'scheduled')
      .snapshots()
      .map((s) {
        final matches = s.docs
            .map((d) => TournamentMatchRecord.fromMap(d.id, d.data()))
            .toList();
        matches.sort(
          (a, b) => (a.startsAt ?? DateTime(2100)).compareTo(
            b.startsAt ?? DateTime(2100),
          ),
        );
        return matches;
      });

  /// Two-hour blocks, aligned to UTC, prevent overlapping bookings atomically.
  Future<void> scheduleMatch(
    TournamentMatchRecord match,
    Court court,
    DateTime startsAt,
  ) async {
    final start = startsAt.toUtc();
    if (!start.isAfter(DateTime.now().toUtc()) ||
        start.millisecondsSinceEpoch % 7200000 != 0) {
      throw ArgumentError('Elige un bloque futuro de dos horas.');
    }
    final bookingId = '${court.id}_${start.millisecondsSinceEpoch}';
    final bookingRef = _db.collection('courtBookings').doc(bookingId);
    final matchRef = _db.collection('tournamentMatches').doc(match.id);
    await _db.runTransaction((tx) async {
      final current = await tx.get(matchRef);
      final booking = await tx.get(bookingRef);
      final courtDoc = await tx.get(_db.collection('courts').doc(court.id));
      final teamIds = [match.homeTeamId, match.awayTeamId];
      for (final teamId in teamIds) {
        final slot = await tx.get(
          _db
              .collection('teamBookings')
              .doc('${teamId}_${start.millisecondsSinceEpoch}'),
        );
        if (slot.exists && slot.data()?['matchId'] != match.id) {
          throw StateError(
            'Uno de los equipos ya juega en ese horario. Elige otro bloque.',
          );
        }
      }
      if (!current.exists || current.data()?['status'] != 'scheduled') {
        throw StateError('Este partido ya no está disponible para programar.');
      }
      if (!courtDoc.exists || courtDoc.data()?['active'] != true) {
        throw StateError('La cancha ya no está disponible.');
      }
      if (booking.exists && booking.data()?['matchId'] != match.id) {
        throw StateError(
          'La cancha ya está ocupada en ese horario. Elige otro bloque.',
        );
      }
      final previous = current.data()?['bookingId'] as String?;
      final previousStart = current.data()?['startsAt'] as Timestamp?;
      for (final teamId in teamIds) {
        if (previousStart != null &&
            previousStart.millisecondsSinceEpoch !=
                start.millisecondsSinceEpoch) {
          tx.delete(
            _db
                .collection('teamBookings')
                .doc('${teamId}_${previousStart.millisecondsSinceEpoch}'),
          );
        }
        tx.set(
          _db
              .collection('teamBookings')
              .doc('${teamId}_${start.millisecondsSinceEpoch}'),
          {
            'teamId': teamId,
            'matchId': match.id,
            'leagueId': match.leagueId,
            'startsAt': Timestamp.fromDate(start),
          },
        );
      }
      if (previous != null && previous != bookingId) {
        tx.delete(_db.collection('courtBookings').doc(previous));
      }
      tx.set(bookingRef, {
        'courtId': court.id,
        'matchId': match.id,
        'leagueId': match.leagueId,
        'startsAt': Timestamp.fromDate(start),
      });
      tx.update(matchRef, {
        'courtId': court.id,
        'courtName': court.name,
        'startsAt': Timestamp.fromDate(start),
        'bookingId': bookingId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
