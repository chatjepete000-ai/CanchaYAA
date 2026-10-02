import 'tournament_summary.dart';

class StandingRow {
  const StandingRow({
    required this.teamId,
    required this.teamName,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
  });

  final String teamId;
  final String teamName;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int points;

  int get goalDifference => goalsFor - goalsAgainst;
}

List<StandingRow> calculateStandings({
  required List<TournamentTeamEntry> teams,
  required List<ScheduledMatch> matches,
}) {
  final rows = <String, _MutableStanding>{
    for (final team in teams)
      team.teamId: _MutableStanding(
        teamId: team.teamId,
        teamName: team.teamName,
      ),
  };

  for (final match in matches) {
    if (match.status != 'completed' ||
        match.homeGoals == null ||
        match.awayGoals == null) {
      continue;
    }

    final home = rows[match.homeTeamId];
    final away = rows[match.awayTeamId];
    if (home == null || away == null) continue;

    final homeGoals = match.homeGoals!;
    final awayGoals = match.awayGoals!;

    home.played++;
    away.played++;
    home.goalsFor += homeGoals;
    home.goalsAgainst += awayGoals;
    away.goalsFor += awayGoals;
    away.goalsAgainst += homeGoals;

    if (homeGoals > awayGoals) {
      home.won++;
      home.points += 3;
      away.lost++;
    } else if (homeGoals < awayGoals) {
      away.won++;
      away.points += 3;
      home.lost++;
    } else {
      home.drawn++;
      away.drawn++;
      home.points++;
      away.points++;
    }
  }

  final result = rows.values.map((row) => row.toImmutable()).toList();

  result.sort((a, b) {
    var comparison = b.points.compareTo(a.points);
    if (comparison != 0) return comparison;

    comparison = b.goalDifference.compareTo(a.goalDifference);
    if (comparison != 0) return comparison;

    comparison = b.goalsFor.compareTo(a.goalsFor);
    if (comparison != 0) return comparison;

    return a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase());
  });

  return result;
}

class _MutableStanding {
  _MutableStanding({
    required this.teamId,
    required this.teamName,
  });

  final String teamId;
  final String teamName;
  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int points = 0;

  StandingRow toImmutable() {
    return StandingRow(
      teamId: teamId,
      teamName: teamName,
      played: played,
      won: won,
      drawn: drawn,
      lost: lost,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      points: points,
    );
  }
}
