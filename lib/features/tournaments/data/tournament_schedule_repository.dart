import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/round_robin_generator.dart';

class TournamentMatchRecord {
  const TournamentMatchRecord({
    required this.id,
    required this.tournamentId,
    required this.leagueId,
    required this.roundNumber,
    required this.matchNumber,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    required this.status,
  });

  final String id;

  final String tournamentId;
  final String leagueId;

  final int roundNumber;
  final int matchNumber;

  final String homeTeamId;
  final String homeTeamName;

  final String awayTeamId;
  final String awayTeamName;

  final String status;

  factory TournamentMatchRecord.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return TournamentMatchRecord(
      id: id,
      tournamentId:
          (data['tournamentId'] as String?)?.trim() ?? '',
      leagueId:
          (data['leagueId'] as String?)?.trim() ?? '',
      roundNumber:
          (data['roundNumber'] as num?)?.toInt() ?? 0,
      matchNumber:
          (data['matchNumber'] as num?)?.toInt() ?? 0,
      homeTeamId:
          (data['homeTeamId'] as String?)?.trim() ?? '',
      homeTeamName:
          (data['homeTeamName'] as String?)?.trim() ?? '',
      awayTeamId:
          (data['awayTeamId'] as String?)?.trim() ?? '',
      awayTeamName:
          (data['awayTeamName'] as String?)?.trim() ?? '',
      status:
          (data['status'] as String?)?.trim() ?? 'scheduled',
    );
  }
}

class TournamentScheduleRepository {
  TournamentScheduleRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>
      get _matches =>
          _firestore.collection(
            'tournamentMatches',
          );

  Stream<List<TournamentMatchRecord>>
      watchMatchesForTournament({
    required String leagueId,
    required String tournamentId,
  }) {
    final cleanLeagueId =
        leagueId.trim();

    final cleanTournamentId =
        tournamentId.trim();

    if (cleanLeagueId.isEmpty ||
        cleanTournamentId.isEmpty) {
      return Stream<List<TournamentMatchRecord>>.value(
        const <TournamentMatchRecord>[],
      );
    }

    return _matches
        .where(
          'leagueId',
          isEqualTo: cleanLeagueId,
        )
        .where(
          'tournamentId',
          isEqualTo: cleanTournamentId,
        )
        .snapshots()
        .map(
          (snapshot) {
            final matches = snapshot.docs
                .map(
                  (doc) =>
                      TournamentMatchRecord.fromMap(
                    doc.id,
                    doc.data(),
                  ),
                )
                .toList();

            matches.sort(
              (a, b) {
                final roundComparison =
                    a.roundNumber.compareTo(
                  b.roundNumber,
                );

                if (roundComparison != 0) {
                  return roundComparison;
                }

                return a.matchNumber.compareTo(
                  b.matchNumber,
                );
              },
            );

            return matches;
          },
        );
  }

  Future<List<TournamentMatchRecord>>
      getMatchesForTournament({
    required String leagueId,
    required String tournamentId,
  }) async {
    final cleanLeagueId =
        leagueId.trim();

    final cleanTournamentId =
        tournamentId.trim();

    if (cleanLeagueId.isEmpty ||
        cleanTournamentId.isEmpty) {
      return const <TournamentMatchRecord>[];
    }

    final snapshot = await _matches
        .where(
          'leagueId',
          isEqualTo: cleanLeagueId,
        )
        .where(
          'tournamentId',
          isEqualTo: cleanTournamentId,
        )
        .get();

    final matches = snapshot.docs
        .map(
          (doc) =>
              TournamentMatchRecord.fromMap(
            doc.id,
            doc.data(),
          ),
        )
        .toList();

    matches.sort(
      (a, b) {
        final roundComparison =
            a.roundNumber.compareTo(
          b.roundNumber,
        );

        if (roundComparison != 0) {
          return roundComparison;
        }

        return a.matchNumber.compareTo(
          b.matchNumber,
        );
      },
    );

    return matches;
  }

  Future<void> saveSchedule({
    required String leagueId,
    required String tournamentId,
    required RoundRobinSchedule schedule,
  }) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión para guardar el calendario.',
      );
    }

    final cleanLeagueId =
        leagueId.trim();

    final cleanTournamentId =
        tournamentId.trim();

    if (cleanLeagueId.isEmpty) {
      throw ArgumentError(
        'La liga no es válida.',
      );
    }

    if (cleanTournamentId.isEmpty) {
      throw ArgumentError(
        'El torneo no es válido.',
      );
    }

    if (!schedule.isComplete) {
      throw StateError(
        'El calendario no es válido y no puede guardarse.',
      );
    }

    final existing =
        await getMatchesForTournament(
      leagueId:
          cleanLeagueId,
      tournamentId:
          cleanTournamentId,
    );

    if (existing.isNotEmpty) {
      throw StateError(
        'Este torneo ya tiene un calendario guardado.',
      );
    }

    final batch =
        _firestore.batch();

    for (final round in schedule.rounds) {
      for (final match in round.matches) {
        final documentId =
            '${cleanTournamentId}_'
            'R${round.number}_'
            'M${match.matchNumber}';

        final ref =
            _matches.doc(
          documentId,
        );

        batch.set(
          ref,
          <String, dynamic>{
            'tournamentId':
                cleanTournamentId,
            'leagueId':
                cleanLeagueId,
            'roundNumber':
                round.number,
            'matchNumber':
                match.matchNumber,
            'homeTeamId':
                match.homeTeam.id,
            'homeTeamName':
                match.homeTeam.name,
            'awayTeamId':
                match.awayTeam.id,
            'awayTeamName':
                match.awayTeam.name,
            'status':
                'scheduled',
            'homeScore':
                null,
            'awayScore':
                null,
            'createdByUserId':
                user.uid,
            'createdAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      }
    }

    await batch.commit();
  }

  Future<void> replaceSchedule({
    required String leagueId,
    required String tournamentId,
    required RoundRobinSchedule schedule,
  }) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión para regenerar el calendario.',
      );
    }

    final cleanLeagueId =
        leagueId.trim();

    final cleanTournamentId =
        tournamentId.trim();

    if (cleanLeagueId.isEmpty ||
        cleanTournamentId.isEmpty) {
      throw ArgumentError(
        'La liga o el torneo no son válidos.',
      );
    }

    if (!schedule.isComplete) {
      throw StateError(
        'El calendario no es válido.',
      );
    }

    final existingSnapshot =
        await _matches
            .where(
              'leagueId',
              isEqualTo: cleanLeagueId,
            )
            .where(
              'tournamentId',
              isEqualTo:
                  cleanTournamentId,
            )
            .get();

    final batch =
        _firestore.batch();

    for (final doc
        in existingSnapshot.docs) {
      batch.delete(
        doc.reference,
      );
    }

    for (final round in schedule.rounds) {
      for (final match in round.matches) {
        final documentId =
            '${cleanTournamentId}_'
            'R${round.number}_'
            'M${match.matchNumber}';

        final ref =
            _matches.doc(
          documentId,
        );

        batch.set(
          ref,
          <String, dynamic>{
            'tournamentId':
                cleanTournamentId,
            'leagueId':
                cleanLeagueId,
            'roundNumber':
                round.number,
            'matchNumber':
                match.matchNumber,
            'homeTeamId':
                match.homeTeam.id,
            'homeTeamName':
                match.homeTeam.name,
            'awayTeamId':
                match.awayTeam.id,
            'awayTeamName':
                match.awayTeam.name,
            'status':
                'scheduled',
            'homeScore':
                null,
            'awayScore':
                null,
            'createdByUserId':
                user.uid,
            'createdAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      }
    }

    await batch.commit();
  }
}