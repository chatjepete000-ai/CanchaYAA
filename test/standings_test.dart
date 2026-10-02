import 'package:flutter_test/flutter_test.dart';

import 'package:cancha_ya/features/tournaments/domain/standings.dart';
import 'package:cancha_ya/features/tournaments/domain/tournament_summary.dart';

void main() {
  test('tabla usa 3 puntos por victoria y desempata por diferencia', () {
    const teams = [
      TournamentTeamEntry(teamId: 'a', teamName: 'Águilas'),
      TournamentTeamEntry(teamId: 'b', teamName: 'Bravos'),
      TournamentTeamEntry(teamId: 'c', teamName: 'Canarios'),
    ];

    const matches = [
      ScheduledMatch(
        id: 'm1',
        homeTeamId: 'a',
        awayTeamId: 'b',
        venue: '',
        field: '',
        zone: '',
        referee: '',
        kickoff: null,
        status: 'completed',
        homeGoals: 2,
        awayGoals: 0,
      ),
      ScheduledMatch(
        id: 'm2',
        homeTeamId: 'c',
        awayTeamId: 'a',
        venue: '',
        field: '',
        zone: '',
        referee: '',
        kickoff: null,
        status: 'completed',
        homeGoals: 1,
        awayGoals: 1,
      ),
    ];

    final rows = calculateStandings(teams: teams, matches: matches);

    expect(rows.first.teamId, 'a');
    expect(rows.first.points, 4);
    expect(rows.first.played, 2);
    expect(rows.first.goalDifference, 2);
    expect(rows[1].teamId, 'c');
    expect(rows[1].points, 1);
  });

  test('partidos no terminados no modifican la tabla', () {
    const teams = [
      TournamentTeamEntry(teamId: 'a', teamName: 'A'),
      TournamentTeamEntry(teamId: 'b', teamName: 'B'),
    ];

    const matches = [
      ScheduledMatch(
        id: 'm1',
        homeTeamId: 'a',
        awayTeamId: 'b',
        venue: '',
        field: '',
        zone: '',
        referee: '',
        kickoff: null,
        status: 'scheduled',
      ),
    ];

    final rows = calculateStandings(teams: teams, matches: matches);

    expect(rows[0].played, 0);
    expect(rows[1].points, 0);
  });
}
