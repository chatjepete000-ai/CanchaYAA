import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_card.dart';
import '../../leagues/domain/league_models.dart';
import '../../teams/data/public_team_repository.dart';
import '../../teams/data/team_match_repository.dart';
import '../../teams/domain/public_team.dart';
import '../../teams/presentation/team_calendar_screen.dart';
import '../domain/public_tournament.dart';
import '../domain/standings_calculator.dart';
import 'widgets/tournament_widgets.dart';

// ================================================================
// DETALLE DEL TORNEO (consulta pública)
// ================================================================
//
// Cualquier usuario autenticado puede consultar; nadie edita desde
// aquí. Los datos salen de:
//
// - publicTournaments/{id}   → encabezado
// - tournamentMatches        → calendario, resultados y tabla
// - publicTeams              → nombres cortos y escudos
//
// La tabla se calcula en el momento con StandingsCalculator.
// ================================================================

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({
    super.key,
    required this.tournament,
  });

  final PublicTournament tournament;

  @override
  State<TournamentDetailScreen> createState() =>
      _TournamentDetailScreenState();
}

class _TournamentDetailScreenState
    extends State<TournamentDetailScreen> {
  final TeamMatchRepository _matchRepository = TeamMatchRepository();

  final PublicTeamRepository _publicTeamRepository =
      PublicTeamRepository();

  late final Stream<List<TeamMatchSummary>> _matches =
      _matchRepository.watchMatchesForTournament(
    widget.tournament.id,
  );

  late final Stream<List<PublicTeam>> _publicTeams =
      _publicTeamRepository.watchAllTeams();

  @override
  Widget build(
    BuildContext context,
  ) {
    final tournament = widget.tournament;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            tournament.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Calendario'),
              Tab(text: 'Resultados'),
              Tab(text: 'Tabla'),
              Tab(text: 'Equipos'),
            ],
          ),
        ),
        body: StreamBuilder<List<TeamMatchSummary>>(
          stream: _matches,
          builder: (context, matchSnapshot) {
            if (matchSnapshot.hasError) {
              return const _CenteredMessage(
                icon: CupertinoIcons.exclamationmark_triangle,
                title: 'No se pudo cargar el torneo',
                message: 'Revisa tu conexión e inténtalo de nuevo.',
              );
            }

            if (!matchSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final matches = matchSnapshot.data!;

            return StreamBuilder<List<PublicTeam>>(
              stream: _publicTeams,
              builder: (context, teamSnapshot) {
                final teams = _publicTeamRepository.mapById(
                  (teamSnapshot.data ?? const <PublicTeam>[]).where(
                    (team) => team.tournamentId == tournament.id,
                  ),
                );

                final standings = const StandingsCalculator().calculate(
                  matches.map(
                    (match) => StandingsMatch(
                      homeTeamId: match.homeTeamId,
                      homeTeamName: match.homeTeamName,
                      awayTeamId: match.awayTeamId,
                      awayTeamName: match.awayTeamName,
                      status: match.status,
                      homeScore: match.homeScore,
                      awayScore: match.awayScore,
                    ),
                  ),
                  teamNames: {
                    for (final team in teams.values)
                      team.id: team.displayName,
                  },
                );

                return TabBarView(
                  children: [
                    _CalendarTab(
                      tournament: tournament,
                      matches: matches,
                      teams: teams,
                    ),
                    _ResultsTab(
                      matches: matches,
                      teams: teams,
                    ),
                    _StandingsTab(
                      rows: standings,
                      teams: teams,
                    ),
                    _TeamsTab(
                      rows: standings,
                      matches: matches,
                      teams: teams,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ================================================================
// RESUMEN (encabezado de las pestañas)
// ================================================================

class _TournamentSummary extends StatelessWidget {
  const _TournamentSummary({
    required this.tournament,
    required this.matches,
  });

  final PublicTournament tournament;
  final List<TeamMatchSummary> matches;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final played = matches.where((match) => match.isCompleted).length;

    final details = <String>[
      tournament.format.label,
      if (tournament.category.isNotEmpty) tournament.category,
      if (tournament.city.isNotEmpty) tournament.city,
      if (tournament.season.isNotEmpty) tournament.season,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            details.join(' · '),
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SummaryStat(
                value: '${matches.length}',
                label: 'Partidos',
              ),
              _SummaryStat(
                value: '$played',
                label: 'Jugados',
              ),
              _SummaryStat(
                value: '${matches.length - played}',
                label: 'Pendientes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// CALENDARIO
// ================================================================

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({
    required this.tournament,
    required this.matches,
    required this.teams,
  });

  final PublicTournament tournament;
  final List<TeamMatchSummary> matches;
  final Map<String, PublicTeam> teams;

  @override
  Widget build(
    BuildContext context,
  ) {
    final pending =
        matches.where((match) => !match.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        _TournamentSummary(
          tournament: tournament,
          matches: matches,
        ),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TeamCalendarScreen(
                  tournamentId: tournament.id,
                  title: tournament.name,
                ),
              ),
            );
          },
          icon: const Icon(CupertinoIcons.calendar_today),
          label: const Text('Ver calendario por día'),
        ),
        const SizedBox(height: 16),
        if (matches.isEmpty)
          const EmptyStateCard(
            icon: CupertinoIcons.calendar,
            title: 'Calendario sin publicar',
            message: 'El administrador todavía no genera los partidos '
                'de este torneo.',
          )
        else if (pending.isEmpty)
          const EmptyStateCard(
            icon: CupertinoIcons.checkmark_seal,
            title: 'Todos los partidos se jugaron',
            message: 'Consulta los marcadores en Resultados.',
          )
        else
          ..._groupByRound(pending).entries.expand(
                (round) => [
                  _SectionTitle(text: 'Jornada ${round.key}'),
                  for (final match in round.value)
                    TournamentMatchCard(
                      match: match,
                      teams: teams,
                    ),
                ],
              ),
      ],
    );
  }
}

Map<int, List<TeamMatchSummary>> _groupByRound(
  List<TeamMatchSummary> matches,
) {
  final rounds = <int, List<TeamMatchSummary>>{};

  for (final match in matches) {
    rounds.putIfAbsent(match.roundNumber, () => []).add(match);
  }

  final sortedKeys = rounds.keys.toList()..sort();

  return {
    for (final key in sortedKeys) key: rounds[key]!,
  };
}

// ================================================================
// RESULTADOS
// ================================================================

class _ResultsTab extends StatelessWidget {
  const _ResultsTab({
    required this.matches,
    required this.teams,
  });

  final List<TeamMatchSummary> matches;
  final Map<String, PublicTeam> teams;

  @override
  Widget build(
    BuildContext context,
  ) {
    final results = matches
        .where((match) => match.isCompleted && match.hasResult)
        .toList()
      ..sort((a, b) {
        final byDate = (b.startsAt ?? DateTime(2000)).compareTo(
          a.startsAt ?? DateTime(2000),
        );
        if (byDate != 0) return byDate;
        return b.roundNumber.compareTo(a.roundNumber);
      });

    if (results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          EmptyStateCard(
            icon: CupertinoIcons.sportscourt,
            title: 'Aún no hay resultados',
            message: 'Los marcadores aparecerán aquí cuando el '
                'administrador los publique.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        for (final match in results)
          TournamentMatchCard(
            match: match,
            teams: teams,
          ),
      ],
    );
  }
}

// ================================================================
// TABLA DE POSICIONES
// ================================================================

class _StandingsTab extends StatelessWidget {
  const _StandingsTab({
    required this.rows,
    required this.teams,
  });

  final List<StandingRow> rows;
  final Map<String, PublicTeam> teams;

  static const double _numberWidth = 34;
  static const double _teamWidth = 150;

  @override
  Widget build(
    BuildContext context,
  ) {
    if (rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          EmptyStateCard(
            icon: CupertinoIcons.list_number,
            title: 'Tabla sin equipos',
            message: 'La tabla aparecerá cuando se publique el '
                'calendario del torneo.',
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    const headers = ['PJ', 'G', 'E', 'P', 'GF', 'GC', 'DG', 'PTS'];

    Widget number(String text, {bool bold = false, Color? color}) {
      return SizedBox(
        width: _numberWidth,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: colors.primary.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      number('POS', bold: true, color: colors.primary),
                      SizedBox(
                        width: _teamWidth,
                        child: Text(
                          'EQUIPO',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      for (final header in headers)
                        number(header, bold: true, color: colors.primary),
                    ],
                  ),
                ),
                for (final row in rows)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        number('${row.position}', bold: true),
                        SizedBox(
                          width: _teamWidth,
                          child: Row(
                            children: [
                              TeamCrest(team: teams[row.teamId], size: 26),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  row.teamName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        number('${row.played}'),
                        number('${row.won}'),
                        number('${row.drawn}'),
                        number('${row.lost}'),
                        number('${row.goalsFor}'),
                        number('${row.goalsAgainst}'),
                        number(
                          row.goalDifference > 0
                              ? '+${row.goalDifference}'
                              : '${row.goalDifference}',
                        ),
                        number(
                          '${row.points}',
                          bold: true,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Victoria 3 pts · Empate 1 · Derrota 0. Desempate: diferencia '
          'de goles, goles a favor y nombre del equipo. Solo cuentan '
          'los partidos finalizados.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ================================================================
// EQUIPOS PARTICIPANTES
// ================================================================

class _TeamsTab extends StatelessWidget {
  const _TeamsTab({
    required this.rows,
    required this.matches,
    required this.teams,
  });

  final List<StandingRow> rows;
  final List<TeamMatchSummary> matches;
  final Map<String, PublicTeam> teams;

  TeamMatchSummary? _nextMatch(String teamId) {
    final now = DateTime.now();

    final upcoming = matches
        .where(
          (match) =>
              match.isScheduled &&
              match.startsAt != null &&
              match.startsAt!.isAfter(now) &&
              (match.homeTeamId == teamId || match.awayTeamId == teamId),
        )
        .toList()
      ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));

    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          EmptyStateCard(
            icon: CupertinoIcons.person_3,
            title: 'Sin equipos todavía',
            message: 'Los equipos aparecerán cuando se publique el '
                'calendario del torneo.',
          ),
        ],
      );
    }

    final sortedByName = [...rows]..sort(
        (a, b) => a.teamName.toLowerCase().compareTo(
              b.teamName.toLowerCase(),
            ),
      );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        for (final row in sortedByName)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: TeamCrest(team: teams[row.teamId], size: 44),
              title: Text(
                row.teamName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                _subtitle(row, teams[row.teamId]),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${row.position}°',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text('${row.points} pts'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _subtitle(StandingRow row, PublicTeam? team) {
    final lines = <String>[];

    if (team != null && team.name.trim() != row.teamName) {
      lines.add(team.name.trim());
    }

    final next = _nextMatch(row.teamId);

    if (next == null) {
      lines.add('${row.played} partidos jugados');
    } else {
      final rival = next.homeTeamId == row.teamId
          ? teamDisplayName(teams, next.awayTeamId, next.awayTeamName)
          : teamDisplayName(teams, next.homeTeamId, next.homeTeamName);

      lines.add(
        'Próximo: vs $rival · ${formatMatchDay(next.startsAt!)} '
        '${formatMatchTime(next.startsAt!)}',
      );
    }

    return lines.join('\n');
  }
}

// ================================================================
// AUXILIARES
// ================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.text,
  });

  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: EmptyStateCard(
          icon: icon,
          title: title,
          message: message,
        ),
      ),
    );
  }
}
