import 'package:cloud_firestore/cloud_firestore.dart';

class TeamMatchSummary {
  const TeamMatchSummary({
    required this.id,
    required this.tournamentId,
    required this.leagueId,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.awayTeamId,
    required this.awayTeamName,
    required this.status,
    this.courtId,
    this.courtName,
    this.startsAt,
    this.homeScore,
    this.awayScore,
  });

  final String id;

  final String tournamentId;
  final String leagueId;

  final String homeTeamId;
  final String homeTeamName;

  final String awayTeamId;
  final String awayTeamName;

  final String status;

  final String? courtId;
  final String? courtName;

  final DateTime? startsAt;

  final int? homeScore;
  final int? awayScore;

  // ============================================================
  // ESTADOS
  // ============================================================

  bool get isScheduled =>
      status == 'scheduled';

  bool get isPostponed =>
      status == 'postponed';

  bool get isCompleted =>
      status == 'completed';

  bool get hasResult =>
      homeScore != null &&
      awayScore != null;

  bool get hasCourt =>
      courtId != null &&
      courtId!.trim().isNotEmpty;

  bool get hasDate =>
      startsAt != null;

  bool get isPlayable =>
      isScheduled &&
      hasDate &&
      hasCourt;

  // ============================================================
  // EQUIPOS
  // ============================================================

  bool involvesTeam(
    String teamId,
  ) {
    final cleanTeamId =
        teamId.trim();

    return homeTeamId ==
            cleanTeamId ||
        awayTeamId ==
            cleanTeamId;
  }

  String opponentName(
    String teamId,
  ) {
    final cleanTeamId =
        teamId.trim();

    if (homeTeamId ==
        cleanTeamId) {
      return awayTeamName;
    }

    if (awayTeamId ==
        cleanTeamId) {
      return homeTeamName;
    }

    return '';
  }

  bool isHomeTeam(
    String teamId,
  ) {
    return homeTeamId ==
        teamId.trim();
  }

  // ============================================================
  // FECHA LOCAL
  // ============================================================

  DateTime? get localStartsAt =>
      startsAt?.toLocal();

  bool happensOnLocalDay(
    DateTime day,
  ) {
    final start =
        localStartsAt;

    if (start == null) {
      return false;
    }

    return start.year ==
            day.year &&
        start.month ==
            day.month &&
        start.day ==
            day.day;
  }

  // ============================================================
  // FIRESTORE
  // ============================================================

  factory TeamMatchSummary.fromFirestore(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        document,
  ) {
    final data =
        document.data();

    return TeamMatchSummary(
      id: document.id,

      tournamentId:
          _readString(
        data['tournamentId'],
      ),

      leagueId:
          _readString(
        data['leagueId'],
      ),

      homeTeamId:
          _readString(
        data['homeTeamId'],
      ),

      homeTeamName:
          _readString(
        data['homeTeamName'],
      ),

      awayTeamId:
          _readString(
        data['awayTeamId'],
      ),

      awayTeamName:
          _readString(
        data['awayTeamName'],
      ),

      status:
          _readString(
                    data['status'],
                  )
                  .isEmpty
              ? 'scheduled'
              : _readString(
                  data['status'],
                ),

      courtId:
          _readNullableString(
        data['courtId'],
      ),

      courtName:
          _readNullableString(
        data['courtName'],
      ),

      startsAt:
          _readDateTime(
        data['startsAt'],
      ),

      homeScore:
          _readNullableInt(
        data['homeScore'],
      ),

      awayScore:
          _readNullableInt(
        data['awayScore'],
      ),
    );
  }

  static String _readString(
    dynamic value,
  ) {
    if (value is! String) {
      return '';
    }

    return value.trim();
  }

  static String?
      _readNullableString(
    dynamic value,
  ) {
    final clean =
        _readString(value);

    if (clean.isEmpty) {
      return null;
    }

    return clean;
  }

  static DateTime?
      _readDateTime(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      );
    }

    return null;
  }

  static int?
      _readNullableInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return null;
  }
}

// ================================================================
// GRUPO DE PARTIDOS POR DÍA
// ================================================================
//
// Ejemplo:
//
// SÁBADO 31
//   17:00 Tijuana vs Pachuca
//   18:00 Tigres vs León
//   18:00 Rayados vs Atlas
//
// ================================================================

class MatchDayGroup {
  const MatchDayGroup({
    required this.date,
    required this.matches,
  });

  final DateTime date;

  final List<TeamMatchSummary>
      matches;
}

class TeamMatchRepository {
  TeamMatchRepository({
    FirebaseFirestore? firestore,
  }) : _firestore =
            firestore ??
                FirebaseFirestore
                    .instance;

  final FirebaseFirestore
      _firestore;

  CollectionReference<
          Map<String, dynamic>>
      get _matches =>
          _firestore.collection(
            'tournamentMatches',
          );

  // ============================================================
  // TODOS LOS PARTIDOS PÚBLICOS
  // ============================================================
  //
  // Esta será la fuente para una pantalla tipo:
  //
  // "Partidos"
  //
  // donde cualquier jugador podrá ver todos los encuentros.
  //
  // ============================================================

  Stream<List<TeamMatchSummary>>
      watchAllMatches() {
    return _matches
        .snapshots()
        .map(
      (snapshot) {
        final matches =
            snapshot.docs
                .map(
                  TeamMatchSummary
                      .fromFirestore,
                )
                .toList();

        matches.sort(
          _sortPublicSchedule,
        );

        return matches;
      },
    );
  }

  // ============================================================
  // PARTIDOS DE UN DÍA ESPECÍFICO
  // ============================================================

  Stream<List<TeamMatchSummary>>
      watchMatchesForDay(
    DateTime day,
  ) {
    return watchAllMatches().map(
      (matches) {
        final dayMatches =
            matches
                .where(
                  (match) =>
                      match
                          .happensOnLocalDay(
                    day,
                  ),
                )
                .toList();

        dayMatches.sort(
          _sortPublicSchedule,
        );

        return dayMatches;
      },
    );
  }

  // ============================================================
  // PRÓXIMOS PARTIDOS DE TODOS
  // ============================================================

  Stream<List<TeamMatchSummary>>
      watchUpcomingMatches() {
    return watchAllMatches().map(
      (matches) {
        final now =
            DateTime.now();

        final upcoming =
            matches
                .where(
                  (match) =>
                      match.isScheduled &&
                      match.startsAt !=
                          null &&
                      !match.startsAt!
                          .isBefore(
                        now,
                      ),
                )
                .toList();

        upcoming.sort(
          _sortPublicSchedule,
        );

        return upcoming;
      },
    );
  }

  // ============================================================
  // TODOS LOS PARTIDOS AGRUPADOS POR DÍA
  // ============================================================

  Stream<List<MatchDayGroup>>
      watchUpcomingMatchesGroupedByDay() {
    return watchUpcomingMatches().map(
      groupMatchesByDay,
    );
  }

  // ============================================================
  // PARTIDOS DE UN EQUIPO
  // ============================================================

  Stream<List<TeamMatchSummary>>
      watchMatchesForTeam({
    required String tournamentId,
    required String teamId,
  }) {
    final cleanTournamentId =
        tournamentId.trim();

    final cleanTeamId =
        teamId.trim();

    if (cleanTournamentId.isEmpty ||
        cleanTeamId.isEmpty) {
      return Stream<
          List<TeamMatchSummary>>.value(
        const <TeamMatchSummary>[],
      );
    }

    return _matches
        .where(
          'tournamentId',
          isEqualTo:
              cleanTournamentId,
        )
        .snapshots()
        .map(
      (snapshot) {
        final matches =
            snapshot.docs
                .map(
                  TeamMatchSummary
                      .fromFirestore,
                )
                .where(
                  (match) =>
                      match.involvesTeam(
                    cleanTeamId,
                  ),
                )
                .toList();

        matches.sort(
          _sortPublicSchedule,
        );

        return matches;
      },
    );
  }

  // ============================================================
  // PARTIDOS DE UN EQUIPO UNA SOLA VEZ
  // ============================================================

  Future<List<TeamMatchSummary>>
      getMatchesForTeam({
    required String tournamentId,
    required String teamId,
  }) async {
    final cleanTournamentId =
        tournamentId.trim();

    final cleanTeamId =
        teamId.trim();

    if (cleanTournamentId.isEmpty ||
        cleanTeamId.isEmpty) {
      return const <
          TeamMatchSummary>[];
    }

    final snapshot =
        await _matches
            .where(
              'tournamentId',
              isEqualTo:
                  cleanTournamentId,
            )
            .get();

    final matches =
        snapshot.docs
            .map(
              TeamMatchSummary
                  .fromFirestore,
            )
            .where(
              (match) =>
                  match.involvesTeam(
                cleanTeamId,
              ),
            )
            .toList();

    matches.sort(
      _sortPublicSchedule,
    );

    return matches;
  }

  // ============================================================
  // PRÓXIMO PARTIDO DE MI EQUIPO
  // ============================================================

  Future<TeamMatchSummary?>
      getNextMatchForTeam({
    required String tournamentId,
    required String teamId,
  }) async {
    final matches =
        await getMatchesForTeam(
      tournamentId:
          tournamentId,
      teamId:
          teamId,
    );

    final now =
        DateTime.now();

    final upcoming =
        matches
            .where(
              (match) =>
                  match.isScheduled &&
                  match.startsAt !=
                      null &&
                  !match.startsAt!
                      .isBefore(
                    now,
                  ),
            )
            .toList();

    upcoming.sort(
      _sortPublicSchedule,
    );

    if (upcoming.isEmpty) {
      return null;
    }

    return upcoming.first;
  }

  // ============================================================
  // ÚLTIMO RESULTADO DE MI EQUIPO
  // ============================================================

  Future<TeamMatchSummary?>
      getLatestResultForTeam({
    required String tournamentId,
    required String teamId,
  }) async {
    final matches =
        await getMatchesForTeam(
      tournamentId:
          tournamentId,
      teamId:
          teamId,
    );

    final completed =
        matches
            .where(
              (match) =>
                  match.isCompleted &&
                  match.hasResult,
            )
            .toList();

    if (completed.isEmpty) {
      return null;
    }

    completed.sort(
      (a, b) {
        final aDate =
            a.startsAt ??
                DateTime
                    .fromMillisecondsSinceEpoch(
                  0,
                );

        final bDate =
            b.startsAt ??
                DateTime
                    .fromMillisecondsSinceEpoch(
                  0,
                );

        return bDate.compareTo(
          aDate,
        );
      },
    );

    return completed.first;
  }

  // ============================================================
  // AGRUPAR POR DÍA
  // ============================================================

  static List<MatchDayGroup>
      groupMatchesByDay(
    List<TeamMatchSummary>
        matches,
  ) {
    final groups =
        <DateTime,
            List<TeamMatchSummary>>{};

    for (final match
        in matches) {
      final local =
          match.localStartsAt;

      if (local == null) {
        continue;
      }

      final day =
          DateTime(
        local.year,
        local.month,
        local.day,
      );

      groups
          .putIfAbsent(
            day,
            () =>
                <TeamMatchSummary>[],
          )
          .add(
            match,
          );
    }

    final result =
        groups.entries
            .map(
              (entry) {
                final dayMatches =
                    entry.value
                      ..sort(
                        _sortPublicSchedule,
                      );

                return MatchDayGroup(
                  date:
                      entry.key,
                  matches:
                      dayMatches,
                );
              },
            )
            .toList();

    result.sort(
      (a, b) =>
          a.date.compareTo(
        b.date,
      ),
    );

    return result;
  }

  // ============================================================
  // ORDEN DE CALENDARIO
  // ============================================================
  //
  // Primero:
  // fecha
  //
  // Después:
  // hora
  //
  // Si dos partidos son a la misma hora:
  // nombre de cancha
  //
  // ============================================================

  static int _sortPublicSchedule(
    TeamMatchSummary a,
    TeamMatchSummary b,
  ) {
    final aDate =
        a.startsAt;

    final bDate =
        b.startsAt;

    if (aDate == null &&
        bDate == null) {
      return _compareCourt(
        a,
        b,
      );
    }

    if (aDate == null) {
      return 1;
    }

    if (bDate == null) {
      return -1;
    }

    final dateComparison =
        aDate.compareTo(
      bDate,
    );

    if (dateComparison != 0) {
      return dateComparison;
    }

    return _compareCourt(
      a,
      b,
    );
  }

  static int _compareCourt(
    TeamMatchSummary a,
    TeamMatchSummary b,
  ) {
    final courtComparison =
        (a.courtName ?? '')
            .compareTo(
      b.courtName ?? '',
    );

    if (courtComparison !=
        0) {
      return courtComparison;
    }

    return a.homeTeamName
        .compareTo(
      b.homeTeamName,
    );
  }
}