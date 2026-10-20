class RoundRobinTeam {
  const RoundRobinTeam({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  @override
  String toString() {
    return name;
  }
}

class RoundRobinMatch {
  const RoundRobinMatch({
    required this.roundNumber,
    required this.matchNumber,
    required this.homeTeam,
    required this.awayTeam,
  });

  final int roundNumber;
  final int matchNumber;

  final RoundRobinTeam homeTeam;
  final RoundRobinTeam awayTeam;

  String get id {
    return 'R${roundNumber}_M$matchNumber';
  }

  String get uniquePairKey {
    final ids = <String>[
      homeTeam.id,
      awayTeam.id,
    ]..sort();

    return '${ids[0]}__${ids[1]}';
  }

  @override
  String toString() {
    return '${homeTeam.name} vs ${awayTeam.name}';
  }
}

class RoundRobinBye {
  const RoundRobinBye({
    required this.roundNumber,
    required this.team,
  });

  final int roundNumber;
  final RoundRobinTeam team;

  @override
  String toString() {
    return '${team.name} descansa';
  }
}

class RoundRobinRound {
  const RoundRobinRound({
    required this.number,
    required this.matches,
    this.bye,
  });

  final int number;

  final List<RoundRobinMatch> matches;

  final RoundRobinBye? bye;

  bool get hasBye {
    return bye != null;
  }
}

class RoundRobinSchedule {
  const RoundRobinSchedule({
    required this.teams,
    required this.rounds,
  });

  final List<RoundRobinTeam> teams;

  final List<RoundRobinRound> rounds;

  int get totalTeams {
    return teams.length;
  }

  int get totalRounds {
    return rounds.length;
  }

  int get totalMatches {
    return rounds.fold<int>(
      0,
      (
        total,
        round,
      ) =>
          total + round.matches.length,
    );
  }

  int get expectedMatches {
    return (totalTeams * (totalTeams - 1)) ~/ 2;
  }

  bool get hasOddNumberOfTeams {
    return totalTeams.isOdd;
  }

  bool get hasDuplicateMatches {
    final seenPairs = <String>{};

    for (final round in rounds) {
      for (final match in round.matches) {
        if (!seenPairs.add(
          match.uniquePairKey,
        )) {
          return true;
        }
      }
    }

    return false;
  }

  bool get isComplete {
    return totalMatches == expectedMatches &&
        !hasDuplicateMatches;
  }

  List<RoundRobinMatch> get allMatches {
    return rounds
        .expand(
          (round) => round.matches,
        )
        .toList();
  }
}

class RoundRobinGenerator {
  const RoundRobinGenerator();

  RoundRobinSchedule generate(
    List<RoundRobinTeam> teams,
  ) {
    _validateTeams(
      teams,
    );

    final originalTeams =
        List<RoundRobinTeam>.unmodifiable(
      teams,
    );

    final rotation =
        List<_RotationEntry>.from(
      teams.map(
        (team) => _RotationEntry.team(
          team,
        ),
      ),
    );

    /*
     * Cuando tenemos un número impar de equipos añadimos
     * una plaza virtual de descanso.
     *
     * Ejemplo:
     *
     * A
     * B
     * C
     * D
     * E
     * DESCANSO
     *
     * De esta manera utilizamos exactamente el mismo
     * algoritmo que para una cantidad par.
     */
    if (rotation.length.isOdd) {
      rotation.add(
        const _RotationEntry.bye(),
      );
    }

    final totalSlots =
        rotation.length;

    final totalRounds =
        totalSlots - 1;

    final matchesPerRound =
        totalSlots ~/ 2;

    final rounds =
        <RoundRobinRound>[];

    for (
      var roundIndex = 0;
      roundIndex < totalRounds;
      roundIndex++
    ) {
      final roundNumber =
          roundIndex + 1;

      final matches =
          <RoundRobinMatch>[];

      RoundRobinBye? bye;

      for (
        var pairIndex = 0;
        pairIndex < matchesPerRound;
        pairIndex++
      ) {
        final left =
            rotation[pairIndex];

        final right =
            rotation[
                totalSlots -
                    1 -
                    pairIndex];

        if (left.isBye ||
            right.isBye) {
          final restingTeam =
              left.isBye
                  ? right.team
                  : left.team;

          if (restingTeam != null) {
            bye = RoundRobinBye(
              roundNumber:
                  roundNumber,
              team:
                  restingTeam,
            );
          }

          continue;
        }

        final leftTeam =
            left.team!;

        final rightTeam =
            right.team!;

        /*
         * Alternamos local/visitante para evitar que el
         * equipo fijo quede siempre en la misma condición.
         *
         * Esto no altera qué equipos se enfrentan.
         */
        final reverse =
            pairIndex == 0 &&
                roundIndex.isOdd;

        final homeTeam =
            reverse
                ? rightTeam
                : leftTeam;

        final awayTeam =
            reverse
                ? leftTeam
                : rightTeam;

        matches.add(
          RoundRobinMatch(
            roundNumber:
                roundNumber,
            matchNumber:
                matches.length + 1,
            homeTeam:
                homeTeam,
            awayTeam:
                awayTeam,
          ),
        );
      }

      rounds.add(
        RoundRobinRound(
          number:
              roundNumber,
          matches:
              List<RoundRobinMatch>.unmodifiable(
            matches,
          ),
          bye:
              bye,
        ),
      );

      _rotate(
        rotation,
      );
    }

    final schedule =
        RoundRobinSchedule(
      teams:
          originalTeams,
      rounds:
          List<RoundRobinRound>.unmodifiable(
        rounds,
      ),
    );

    _validateGeneratedSchedule(
      schedule,
    );

    return schedule;
  }

  void _rotate(
    List<_RotationEntry> teams,
  ) {
    if (teams.length <= 2) {
      return;
    }

    /*
     * Método del círculo:
     *
     * El primer equipo permanece fijo.
     * Los demás rotan una posición en cada jornada.
     */
    final last =
        teams.removeLast();

    teams.insert(
      1,
      last,
    );
  }

  void _validateTeams(
    List<RoundRobinTeam> teams,
  ) {
    if (teams.length < 2) {
      throw ArgumentError(
        'Se necesitan al menos 2 equipos para generar un calendario.',
      );
    }

    final ids =
        <String>{};

    for (final team in teams) {
      final id =
          team.id.trim();

      final name =
          team.name.trim();

      if (id.isEmpty) {
        throw ArgumentError(
          'Todos los equipos deben tener un ID válido.',
        );
      }

      if (name.isEmpty) {
        throw ArgumentError(
          'Todos los equipos deben tener un nombre.',
        );
      }

      if (!ids.add(id)) {
        throw ArgumentError(
          'No puede haber equipos repetidos en el calendario.',
        );
      }
    }
  }

  void _validateGeneratedSchedule(
    RoundRobinSchedule schedule,
  ) {
    if (schedule.hasDuplicateMatches) {
      throw StateError(
        'El calendario generado contiene partidos duplicados.',
      );
    }

    if (schedule.totalMatches !=
        schedule.expectedMatches) {
      throw StateError(
        'El calendario generado está incompleto. '
        'Se esperaban ${schedule.expectedMatches} partidos '
        'y se generaron ${schedule.totalMatches}.',
      );
    }

    final pairKeys =
        <String>{};

    for (final round
        in schedule.rounds) {
      final teamsUsedInRound =
          <String>{};

      for (final match
          in round.matches) {
        if (match.homeTeam.id ==
            match.awayTeam.id) {
          throw StateError(
            'Un equipo no puede jugar contra sí mismo.',
          );
        }

        if (!teamsUsedInRound.add(
          match.homeTeam.id,
        )) {
          throw StateError(
            'Un equipo aparece más de una vez en la jornada ${round.number}.',
          );
        }

        if (!teamsUsedInRound.add(
          match.awayTeam.id,
        )) {
          throw StateError(
            'Un equipo aparece más de una vez en la jornada ${round.number}.',
          );
        }

        if (!pairKeys.add(
          match.uniquePairKey,
        )) {
          throw StateError(
            'Se detectó un enfrentamiento repetido.',
          );
        }
      }

      final bye =
          round.bye;

      if (bye != null) {
        if (teamsUsedInRound.contains(
          bye.team.id,
        )) {
          throw StateError(
            'El equipo que descansa también aparece jugando '
            'en la jornada ${round.number}.',
          );
        }
      }
    }

    /*
     * En un torneo impar cada equipo debe descansar
     * exactamente una vez.
     */
    if (schedule.hasOddNumberOfTeams) {
      final byeCounts =
          <String, int>{};

      for (final round
          in schedule.rounds) {
        final bye =
            round.bye;

        if (bye == null) {
          throw StateError(
            'Falta un descanso en la jornada ${round.number}.',
          );
        }

        byeCounts.update(
          bye.team.id,
          (value) =>
              value + 1,
          ifAbsent: () =>
              1,
        );
      }

      for (final team
          in schedule.teams) {
        final count =
            byeCounts[team.id] ?? 0;

        if (count != 1) {
          throw StateError(
            '${team.name} debería descansar exactamente una vez.',
          );
        }
      }
    } else {
      /*
       * Si tenemos cantidad par de equipos no debe
       * existir ningún descanso.
       */
      for (final round
          in schedule.rounds) {
        if (round.bye != null) {
          throw StateError(
            'No debería existir un descanso '
            'cuando la cantidad de equipos es par.',
          );
        }
      }
    }
  }
}

class _RotationEntry {
  const _RotationEntry.team(
    this.team,
  ) : isBye = false;

  const _RotationEntry.bye()
      : team = null,
        isBye = true;

  final RoundRobinTeam? team;

  final bool isBye;
}