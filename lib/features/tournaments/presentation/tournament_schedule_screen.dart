import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../leagues/domain/league_models.dart';
import '../../teams/domain/team_models.dart';
import '../domain/round_robin_generator.dart';

class TournamentScheduleScreen extends StatefulWidget {
  const TournamentScheduleScreen({
    super.key,
    required this.tournament,
  });

  final Tournament tournament;

  @override
  State<TournamentScheduleScreen> createState() =>
      _TournamentScheduleScreenState();
}

class _TournamentScheduleScreenState
    extends State<TournamentScheduleScreen> {
  final RoundRobinGenerator _generator =
      const RoundRobinGenerator();

  RoundRobinSchedule? _schedule;

  String? _generationError;

  Stream<List<Team>> _watchTournamentTeams() {
    return FirebaseFirestore.instance
        .collection('teams')
        .where(
          'leagueId',
          isEqualTo: widget.tournament.leagueId,
        )
        .where(
          'tournamentId',
          isEqualTo: widget.tournament.id,
        )
        .snapshots()
        .map(
          (snapshot) {
            final teams = snapshot.docs
                .map(
                  (doc) => Team.fromMap(
                    doc.id,
                    doc.data(),
                  ),
                )
                .where(
                  (team) =>
                      team.status ==
                      TeamStatus.active,
                )
                .toList();

            teams.sort(
              (a, b) => a.name
                  .toLowerCase()
                  .compareTo(
                    b.name.toLowerCase(),
                  ),
            );

            return teams;
          },
        );
  }

  void _generateSchedule(
    List<Team> teams,
  ) {
    if (teams.length < 2) {
      setState(() {
        _schedule = null;
        _generationError =
            'Necesitas al menos 2 equipos activos para generar el calendario.';
      });

      return;
    }

    try {
      final roundRobinTeams =
          teams
              .map(
                (team) =>
                    RoundRobinTeam(
                  id: team.id,
                  name: team.name,
                ),
              )
              .toList();

      final schedule =
          _generator.generate(
        roundRobinTeams,
      );

      setState(() {
        _schedule = schedule;
        _generationError = null;
      });
    } catch (error) {
      setState(() {
        _schedule = null;
        _generationError =
            'No se pudo generar el calendario: $error';
      });
    }
  }

  void _clearSchedule() {
    setState(() {
      _schedule = null;
      _generationError = null;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendario del torneo',
        ),
      ),
      body: StreamBuilder<List<Team>>(
        stream:
            _watchTournamentTeams(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message:
                  'No se pudieron cargar los equipos.\n${snapshot.error}',
            );
          }

          final teams =
              snapshot.data ??
                  const <Team>[];

          return ListView(
            physics:
                const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              34,
            ),
            children: [
              Container(
                padding:
                    const EdgeInsets.all(
                  22,
                ),
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      colors.primary,
                      colors.primary
                          .withValues(
                        alpha: 0.76,
                      ),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    26,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration:
                          BoxDecoration(
                        color: colors
                            .onPrimary
                            .withValues(
                          alpha:
                              0.15,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          17,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons
                            .sportscourt_fill,
                        color:
                            colors.onPrimary,
                        size: 28,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    Text(
                      widget
                          .tournament.name,
                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color: colors
                                .onPrimary,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      '${widget.tournament.category} · '
                      '${widget.tournament.format.label}',
                      style:
                          TextStyle(
                        color: colors
                            .onPrimary
                            .withValues(
                          alpha: 0.9,
                        ),
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    if (widget
                        .tournament
                        .season
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        widget
                            .tournament
                            .season,
                        style:
                            TextStyle(
                          color: colors
                              .onPrimary
                              .withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        _SummaryCard(
                      icon:
                          CupertinoIcons
                              .person_3_fill,
                      value:
                          '${teams.length}',
                      label:
                          'Equipos',
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child:
                        _SummaryCard(
                      icon:
                          CupertinoIcons
                              .calendar,
                      value:
                          _schedule == null
                              ? '—'
                              : '${_schedule!.totalRounds}',
                      label:
                          'Jornadas',
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child:
                        _SummaryCard(
                      icon:
                          CupertinoIcons
                              .sportscourt,
                      value:
                          _schedule == null
                              ? '—'
                              : '${_schedule!.totalMatches}',
                      label:
                          'Partidos',
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 26,
              ),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Equipos participantes',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                    ),
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primaryContainer,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Text(
                      '${teams.length}',
                      style:
                          TextStyle(
                        color:
                            colors.primary,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              if (teams.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.all(
                    24,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colors
                        .surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        CupertinoIcons
                            .person_3,
                        size: 44,
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      Text(
                        'No hay equipos inscritos',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight
                                  .w900,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(
                        height: 6,
                      ),
                      Text(
                        'Registra equipos en este torneo antes de generar el calendario.',
                        textAlign:
                            TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...teams.map(
                  (team) =>
                      Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 9,
                    ),
                    child:
                        _TeamTile(
                      team:
                          team,
                    ),
                  ),
                ),

              const SizedBox(
                height: 22,
              ),

              if (_schedule == null)
                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton.icon(
                    onPressed:
                        teams.length < 2
                            ? null
                            : () {
                                _generateSchedule(
                                  teams,
                                );
                              },
                    icon:
                        const Icon(
                      CupertinoIcons
                          .wand_stars,
                    ),
                    label:
                        const Text(
                      'Generar calendario',
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _clearSchedule,
                        icon:
                            const Icon(
                          CupertinoIcons
                              .refresh,
                        ),
                        label:
                            const Text(
                          'Regenerar',
                        ),
                      ),
                    ),
                  ],
                ),

              if (_generationError !=
                  null) ...[
                const SizedBox(
                  height: 16,
                ),

                Container(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colors
                        .errorContainer,
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons
                            .exclamationmark_triangle_fill,
                        color: colors
                            .onErrorContainer,
                      ),

                      const SizedBox(
                        width: 11,
                      ),

                      Expanded(
                        child: Text(
                          _generationError!,
                          style:
                              TextStyle(
                            color: colors
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_schedule !=
                  null) ...[
                const SizedBox(
                  height: 28,
                ),

                _ScheduleValidationCard(
                  schedule:
                      _schedule!,
                ),

                const SizedBox(
                  height: 24,
                ),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Calendario generado',
                        style: theme
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                      ),
                    ),

                    Icon(
                      CupertinoIcons
                          .check_mark_circled_solid,
                      color:
                          colors.primary,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 14,
                ),

                ..._schedule!.rounds.map(
                  (round) =>
                      Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 16,
                    ),
                    child:
                        _RoundCard(
                      round:
                          round,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Container(
                  padding:
                      const EdgeInsets.all(
                    18,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colors
                        .surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.info,
                      ),

                      SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child: Text(
                          'Este calendario todavía es una vista previa. '
                          'En el siguiente paso lo guardaremos en Firestore.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 16,
      ),
      decoration:
          BoxDecoration(
        color: colors
            .primaryContainer,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color:
                colors.primary,
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            value,
            style: Theme.of(
              context,
            )
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            label,
            textAlign:
                TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TeamTile
    extends StatelessWidget {
  const _TeamTile({
    required this.team,
  });

  final Team team;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        border:
            Border.all(
          color: colors
              .outlineVariant,
        ),
        borderRadius:
            BorderRadius.circular(
          17,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(
              color: colors
                  .primaryContainer,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: team
                    .logoUrl
                    .isEmpty
                ? Icon(
                    CupertinoIcons
                        .shield_fill,
                    color:
                        colors.primary,
                  )
                : ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    child:
                        Image.network(
                      team.logoUrl,
                      fit:
                          BoxFit.cover,
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return Icon(
                          CupertinoIcons
                              .shield_fill,
                          color:
                              colors.primary,
                        );
                      },
                    ),
                  ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  '${team.totalPlayers} jugadores',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          Icon(
            CupertinoIcons
                .check_mark_circled_solid,
            color:
                colors.primary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _ScheduleValidationCard
    extends StatelessWidget {
  const _ScheduleValidationCard({
    required this.schedule,
  });

  final RoundRobinSchedule schedule;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final isValid =
        schedule.isComplete;

    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),
      decoration:
          BoxDecoration(
        color: isValid
            ? colors.primaryContainer
            : colors.errorContainer,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            isValid
                ? CupertinoIcons
                    .check_mark_circled_solid
                : CupertinoIcons
                    .exclamationmark_triangle_fill,
            color: isValid
                ? colors.primary
                : colors
                    .onErrorContainer,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  isValid
                      ? 'Calendario válido'
                      : 'Calendario incompleto',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  isValid
                      ? '${schedule.totalMatches} partidos sin enfrentamientos duplicados.'
                      : 'Revisa la configuración antes de continuar.',
                ),

                if (schedule
                    .hasOddNumberOfTeams) ...[
                  const SizedBox(
                    height: 5,
                  ),
                  const Text(
                    'Número impar de equipos: cada equipo tendrá una jornada de descanso.',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundCard
    extends StatelessWidget {
  const _RoundCard({
    required this.round,
  });

  final RoundRobinRound round;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      decoration:
          BoxDecoration(
        border:
            Border.all(
          color: colors
              .outlineVariant,
        ),
        borderRadius:
            BorderRadius.circular(
          21,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 13,
            ),
            decoration:
                BoxDecoration(
              color: colors
                  .surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.only(
                topLeft:
                    Radius.circular(
                  20,
                ),
                topRight:
                    Radius.circular(
                  20,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons
                      .calendar,
                  color:
                      colors.primary,
                  size: 20,
                ),

                const SizedBox(
                  width: 9,
                ),

                Text(
                  'Jornada ${round.number}',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 16,
                  ),
                ),

                const Spacer(),

                Text(
                  '${round.matches.length} '
                  '${round.matches.length == 1 ? 'partido' : 'partidos'}',
                  style:
                      Theme.of(context)
                          .textTheme
                          .bodySmall,
                ),
              ],
            ),
          ),

          ...round.matches.map(
            (match) =>
                _MatchTile(
              match:
                  match,
            ),
          ),

          if (round.bye != null)
            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                13,
                16,
                15,
              ),
              decoration:
                  BoxDecoration(
                color: colors
                    .primaryContainer
                    .withValues(
                  alpha: 0.35,
                ),
                borderRadius:
                    const BorderRadius.only(
                  bottomLeft:
                      Radius.circular(
                    20,
                  ),
                  bottomRight:
                      Radius.circular(
                    20,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons
                        .moon_zzz_fill,
                    color:
                        colors.primary,
                    size: 20,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: Text(
                      '${round.bye!.team.name} descansa',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MatchTile
    extends StatelessWidget {
  const _MatchTile({
    required this.match,
  });

  final RoundRobinMatch match;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              match.homeTeam.name,
              textAlign:
                  TextAlign.right,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration:
                BoxDecoration(
              color: colors
                  .primaryContainer,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Text(
              'VS',
              style:
                  TextStyle(
                color:
                    colors.primary,
                fontWeight:
                    FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Text(
              match.awayTeam.name,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState
    extends StatelessWidget {
  const _ErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(
            20,
          ),
          decoration:
              BoxDecoration(
            color: Theme.of(
              context,
            )
                .colorScheme
                .errorContainer,
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                CupertinoIcons
                    .exclamationmark_triangle_fill,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Text(
                  message,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}