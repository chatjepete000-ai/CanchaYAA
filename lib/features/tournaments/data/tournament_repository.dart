import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../teams/domain/team_models.dart';
import '../domain/tournament_summary.dart';

class TournamentRepository {
  TournamentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<TournamentSummary>> watchTournaments() {
    return _firestore
        .collection('tournaments')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TournamentSummary.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<TournamentTeamEntry>> watchEnrolledTeams(String tournamentId) {
    return _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('teams')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => TournamentTeamEntry.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  Stream<List<ScheduledMatch>> watchMatches(String tournamentId) {
    return _firestore
        .collection('matches')
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snapshot) {
      final matches = snapshot.docs
          .map((doc) => ScheduledMatch.fromMap(doc.id, doc.data()))
          .toList();

      matches.sort((a, b) {
        final aDate = a.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });

      return matches;
    });
  }

  Future<void> createTournament({
    required String leagueId,
    required String name,
    required String category,
    required String city,
  }) async {
    await _firestore.collection('tournaments').add({
      'leagueId': leagueId,
      'name': name.trim(),
      'category': category.trim(),
      'city': city.trim(),
      'format': 'roundRobinSingleLeg',
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> enrollTeam({
    required String tournamentId,
    required TeamSummary team,
  }) async {
    await _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('teams')
        .doc(team.id)
        .set({
      'teamName': team.name,
      'status': 'active',
      'enrolledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeTeam({
    required String tournamentId,
    required String teamId,
  }) async {
    await _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('teams')
        .doc(teamId)
        .delete();
  }

  Future<void> saveResult({
    required ScheduledMatch match,
    required int homeGoals,
    required int awayGoals,
  }) async {
    if (homeGoals < 0 || awayGoals < 0) {
      throw ArgumentError('Los goles no pueden ser negativos.');
    }

    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay una sesión activa.');

    final matchRef = _firestore.collection('matches').doc(match.id);
    final auditRef = matchRef.collection('resultAudits').doc();
    final batch = _firestore.batch();

    batch.set(auditRef, {
      'changedBy': user.uid,
      'previousHomeGoals': match.homeGoals,
      'previousAwayGoals': match.awayGoals,
      'newHomeGoals': homeGoals,
      'newAwayGoals': awayGoals,
      'changedAt': FieldValue.serverTimestamp(),
    });

    batch.update(matchRef, {
      'homeGoals': homeGoals,
      'awayGoals': awayGoals,
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> createMatch({
    required String tournamentId,
    required String homeTeamId,
    required String awayTeamId,
    required String venue,
    required String field,
    required String zone,
    required String referee,
    required DateTime kickoff,
  }) async {
    if (homeTeamId == awayTeamId) {
      throw ArgumentError('Los equipos del partido deben ser diferentes.');
    }

    await _firestore.collection('matches').add({
      'tournamentId': tournamentId,
      'homeTeamId': homeTeamId,
      'awayTeamId': awayTeamId,
      'venue': venue.trim(),
      'field': field.trim(),
      'zone': zone.trim(),
      'referee': referee.trim(),
      'kickoff': Timestamp.fromDate(kickoff.toUtc()),
      'status': 'scheduled',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
