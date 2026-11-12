import 'package:cancha_ya/features/teams/data/team_match_repository.dart';
import 'package:cancha_ya/features/teams/domain/public_team.dart';
import 'package:cancha_ya/features/tournaments/presentation/widgets/tournament_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {double width = 320}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  test('hora en formato de 12 horas', () {
    expect(formatMatchTime(DateTime(2026, 11, 14, 18)), '6:00 PM');
    expect(formatMatchTime(DateTime(2026, 11, 14, 0, 5)), '12:05 AM');
    expect(formatMatchTime(DateTime(2026, 11, 14, 12, 30)), '12:30 PM');
  });

  test('fecha corta en español', () {
    expect(formatMatchDay(DateTime(2026, 11, 14)), 'sáb 14 nov');
  });

  testWidgets('tarjeta con nombres largos no se desborda en pantalla angosta',
      (tester) async {
    final match = TeamMatchSummary(
      id: 'm',
      tournamentId: 't',
      leagueId: 'l',
      homeTeamId: 'a',
      homeTeamName: 'Club Deportivo Los Diablos De La Emiliano Zapata',
      awayTeamId: 'b',
      awayTeamName: 'Atlético Unión de Vecinos del Barrio Norte',
      status: 'scheduled',
      courtName: 'Unidad Deportiva Municipal Cancha 3',
      startsAt: DateTime(2026, 11, 14, 18),
    );

    await tester.pumpWidget(
      _wrap(
        TournamentMatchCard(
          match: match,
          teams: const {
            'a': PublicTeam(
              id: 'a',
              name: 'Club Deportivo Los Diablos De La Emiliano Zapata',
              shortName: 'Diablos Emiliano',
              leagueId: 'l',
              tournamentId: 't',
            ),
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Diablos Emiliano'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('sáb 14 nov · 6:00 PM'), findsOneWidget);
  });

  testWidgets('partido finalizado muestra el marcador', (tester) async {
    const match = TeamMatchSummary(
      id: 'm',
      tournamentId: 't',
      leagueId: 'l',
      homeTeamId: 'a',
      homeTeamName: 'A',
      awayTeamId: 'b',
      awayTeamName: 'B',
      status: 'completed',
      homeScore: 3,
      awayScore: 1,
    );

    await tester.pumpWidget(
      _wrap(const TournamentMatchCard(match: match, teams: {})),
    );

    expect(find.text('3 - 1'), findsOneWidget);
    expect(find.text('Finalizado'), findsOneWidget);
  });
}
