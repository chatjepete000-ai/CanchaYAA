import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentSummary {
  const TournamentSummary({
    required this.id,
    required this.name,
    required this.leagueId,
    required this.category,
    required this.city,
    required this.status,
  });

  final String id;
  final String name;
  final String leagueId;
  final String category;
  final String city;
  final String status;

  factory TournamentSummary.fromMap(String id, Map<String, dynamic> data) {
    return TournamentSummary(
      id: id,
      name: (data['name'] as String?) ?? 'Torneo',
      leagueId: (data['leagueId'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'draft',
    );
  }
}

class TournamentTeamEntry {
  const TournamentTeamEntry({
    required this.teamId,
    required this.teamName,
  });

  final String teamId;
  final String teamName;

  factory TournamentTeamEntry.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return TournamentTeamEntry(
      teamId: id,
      teamName: (data['teamName'] as String?) ?? 'Equipo',
    );
  }
}

class ScheduledMatch {
  const ScheduledMatch({
    required this.id,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.venue,
    required this.field,
    required this.zone,
    required this.referee,
    required this.kickoff,
    required this.status,
  });

  final String id;
  final String homeTeamId;
  final String awayTeamId;
  final String venue;
  final String field;
  final String zone;
  final String referee;
  final DateTime? kickoff;
  final String status;

  factory ScheduledMatch.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['kickoff'];
    return ScheduledMatch(
      id: id,
      homeTeamId: (data['homeTeamId'] as String?) ?? '',
      awayTeamId: (data['awayTeamId'] as String?) ?? '',
      venue: (data['venue'] as String?) ?? '',
      field: (data['field'] as String?) ?? '',
      zone: (data['zone'] as String?) ?? '',
      referee: (data['referee'] as String?) ?? '',
      kickoff: timestamp is Timestamp ? timestamp.toDate().toLocal() : null,
      status: (data['status'] as String?) ?? 'scheduled',
    );
  }
}
