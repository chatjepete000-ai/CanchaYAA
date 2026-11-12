// ================================================================
// F05 · TABLA DE POSICIONES
// ================================================================
//
// La tabla NO se guarda: se calcula siempre a partir de los
// partidos finalizados con marcador. Por eso:
//
// - Una corrección de resultado (F08) se refleja de inmediato y
//   nunca suma dos veces.
// - Los partidos programados, pospuestos o sin marcador no cuentan.
//
// Reglas del plan de trabajo (sección 3):
//
//   Victoria 3 · Empate 1 · Derrota 0
//   Desempate: diferencia de goles, goles a favor y, al final,
//   el nombre del equipo (para que el orden sea siempre el mismo).
// ================================================================

const int pointsPerWin = 3;
const int pointsPerDraw = 1;
const int pointsPerLoss = 0;

/// Datos mínimos de un partido para calcular la tabla.
///
/// Se mantiene independiente de Firestore para poder probarlo con
/// pruebas unitarias.
class StandingsMatch {
  const StandingsMatch({
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    required this.status,
    this.homeScore,
    this.awayScore,
  });

  final String homeTeamId;
  final String homeTeamName;
  final String awayTeamId;
  final String awayTeamName;
  final String status;
  final int? homeScore;
  final int? awayScore;

  bool get countsForStandings =>
      status == 'completed' &&
      homeScore != null &&
      awayScore != null &&
      homeScore! >= 0 &&
      awayScore! >= 0 &&
      homeTeamId.isNotEmpty &&
      awayTeamId.isNotEmpty &&
      homeTeamId != awayTeamId;
}

class StandingRow {
  const StandingRow({
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  final int position;
  final String teamId;
  final String teamName;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  int get goalDifference => goalsFor - goalsAgainst;

  int get points =>
      won * pointsPerWin +
      drawn * pointsPerDraw +
      lost * pointsPerLoss;
}

class _Accumulator {
  _Accumulator(this.teamId, this.teamName);

  final String teamId;
  String teamName;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get played => won + drawn + lost;
  int get goalDifference => goalsFor - goalsAgainst;
  int get points =>
      won * pointsPerWin +
      drawn * pointsPerDraw +
      lost * pointsPerLoss;

  void addResult(int scored, int conceded) {
    goalsFor += scored;
    goalsAgainst += conceded;

    if (scored > conceded) {
      won++;
    } else if (scored == conceded) {
      drawn++;
    } else {
      lost++;
    }
  }
}

class StandingsCalculator {
  const StandingsCalculator();

  /// Calcula la tabla.
  ///
  /// Todos los equipos que aparecen en algún partido del torneo
  /// (aunque aún no jueguen) aparecen en la tabla con ceros.
  ///
  /// [teamNames] permite usar el nombre público más reciente
  /// (por ejemplo, el nombre corto de publicTeams).
  List<StandingRow> calculate(
    Iterable<StandingsMatch> matches, {
    Map<String, String> teamNames = const <String, String>{},
  }) {
    final table = <String, _Accumulator>{};

    _Accumulator entry(String id, String fallbackName) {
      return table.putIfAbsent(
        id,
        () => _Accumulator(
          id,
          _pickName(teamNames[id], fallbackName, id),
        ),
      );
    }

    for (final match in matches) {
      if (match.homeTeamId.isEmpty || match.awayTeamId.isEmpty) {
        continue;
      }

      final home = entry(match.homeTeamId, match.homeTeamName);
      final away = entry(match.awayTeamId, match.awayTeamName);

      if (!match.countsForStandings) {
        continue;
      }

      home.addResult(match.homeScore!, match.awayScore!);
      away.addResult(match.awayScore!, match.homeScore!);
    }

    final sorted = table.values.toList()..sort(_compareEntries);

    return <StandingRow>[
      for (var index = 0; index < sorted.length; index++)
        StandingRow(
          position: index + 1,
          teamId: sorted[index].teamId,
          teamName: sorted[index].teamName,
          played: sorted[index].played,
          won: sorted[index].won,
          drawn: sorted[index].drawn,
          lost: sorted[index].lost,
          goalsFor: sorted[index].goalsFor,
          goalsAgainst: sorted[index].goalsAgainst,
        ),
    ];
  }

  static int _compareEntries(_Accumulator a, _Accumulator b) {
    final byPoints = b.points.compareTo(a.points);
    if (byPoints != 0) return byPoints;

    final byDifference = b.goalDifference.compareTo(a.goalDifference);
    if (byDifference != 0) return byDifference;

    final byGoalsFor = b.goalsFor.compareTo(a.goalsFor);
    if (byGoalsFor != 0) return byGoalsFor;

    final byName = a.teamName.toLowerCase().compareTo(
          b.teamName.toLowerCase(),
        );
    if (byName != 0) return byName;

    return a.teamId.compareTo(b.teamId);
  }

  static String _pickName(String? preferred, String fallback, String id) {
    final clean = preferred?.trim() ?? '';
    if (clean.isNotEmpty) return clean;

    final cleanFallback = fallback.trim();
    if (cleanFallback.isNotEmpty) return cleanFallback;

    return id;
  }
}
