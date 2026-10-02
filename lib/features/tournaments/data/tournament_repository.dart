import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/tournament_summary.dart';

class TournamentRepository {
  TournamentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
