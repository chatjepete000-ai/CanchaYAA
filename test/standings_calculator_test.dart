import 'package:cancha_ya/features/tournaments/domain/standings_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

StandingsMatch played(
  String home,
  int homeScore,
  String away,
  int awayScore,
) {
  return StandingsMatch(
    homeTeamId: home,
    homeTeamName: home,
    awayTeamId: away,
    awayTeamName: away,
    status: 'completed',
    homeScore: homeScore,
    awayScore: awayScore,
  );
}

StandingsMatch pending(String home, String away, {String status = 'scheduled'}) {
  return StandingsMatch(
    homeTeamId: home,
    homeTeamName: home,
    awayTeamId: away,
    awayTeamName: away,
    status: status,
  );
}

void main() {
  const calculator = StandingsCalculator();

  StandingRow rowFor(List<StandingRow> table, String id) =>
      table.firstWhere((row) => row.teamId == id);

  test('victoria 3, empate 1, derrota 0', () {
    final table = calculator.calculate([
      played('A', 2, 'B', 0),
      played('A', 1, 'C', 1),
      played('B', 0, 'C', 3),
    ]);

    expect(rowFor(table, 'A').points, 4);
    expect(rowFor(table, 'C').points, 4);
    expect(rowFor(table, 'B').points, 0);

    final a = rowFor(table, 'A');
    expect(
      [a.played, a.won, a.drawn, a.lost, a.goalsFor, a.goalsAgainst, a.goalDifference],
      [2, 1, 1, 0, 3, 1, 2],
    );
  });

  test('desempate por diferencia de goles', () {
    final table = calculator.calculate([
      played('A', 1, 'X', 0),
      played('B', 5, 'Y', 0),
    ]);

    expect(table.first.teamId, 'B');
    expect(table[1].teamId, 'A');
  });

  test('desempate por goles a favor cuando la diferencia es igual', () {
    final table = calculator.calculate([
      played('A', 1, 'X', 0),
      played('B', 3, 'Y', 2),
    ]);

    expect(table.first.teamId, 'B');
    expect(table[1].teamId, 'A');
  });

  test('desempate final por nombre: el orden siempre es el mismo', () {
    final first = calculator.calculate([
      played('Zorros', 1, 'Águilas', 1),
    ]);
    final second = calculator.calculate([
      played('Águilas', 1, 'Zorros', 1),
    ]);

    expect(first.map((row) => row.teamId), second.map((row) => row.teamId));
  });

  test('programados, pospuestos y sin marcador no cuentan, pero el equipo aparece', () {
    final table = calculator.calculate([
      played('A', 2, 'B', 1),
      pending('C', 'D'),
      pending('A', 'C', status: 'postponed'),
      const StandingsMatch(
        homeTeamId: 'B',
        homeTeamName: 'B',
        awayTeamId: 'D',
        awayTeamName: 'D',
        status: 'completed',
      ),
    ]);

    expect(table.length, 4);
    expect(rowFor(table, 'C').played, 0);
    expect(rowFor(table, 'D').played, 0);
    expect(rowFor(table, 'A').played, 1);
    expect(rowFor(table, 'B').played, 1);
  });

  test('una corrección reemplaza el resultado, no suma dos veces', () {
    final original = calculator.calculate([played('A', 1, 'B', 0)]);
    final corrected = calculator.calculate([played('A', 1, 'B', 1)]);

    expect(rowFor(original, 'A').points, 3);
    expect(rowFor(corrected, 'A').points, 1);
    expect(rowFor(corrected, 'A').played, 1);
    expect(rowFor(corrected, 'B').points, 1);
  });

  test('usa el nombre público cuando está disponible', () {
    final table = calculator.calculate(
      [played('a1', 1, 'b1', 0)],
      teamNames: const {'a1': 'Diablos Emiliano'},
    );

    expect(rowFor(table, 'a1').teamName, 'Diablos Emiliano');
    expect(rowFor(table, 'b1').teamName, 'b1');
  });

  test('posiciones consecutivas desde 1', () {
    final table = calculator.calculate([
      played('A', 1, 'B', 0),
      played('C', 0, 'D', 0),
    ]);

    expect(table.map((row) => row.position), [1, 2, 3, 4]);
  });

  test('torneo sin partidos produce tabla vacía', () {
    expect(calculator.calculate(const []), isEmpty);
  });
}
