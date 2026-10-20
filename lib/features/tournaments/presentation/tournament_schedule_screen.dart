import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../leagues/domain/league_models.dart';
import '../../teams/domain/team_models.dart';
import '../data/tournament_schedule_repository.dart';
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

  final TournamentScheduleRepository _scheduleRepository =
      TournamentScheduleRepository();

  bool _saving = false;

  String? _errorMessage;

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

  Stream<List<TournamentMatchRecord>>
      _watchSavedMatches() {
    return _scheduleRepository
        .watchMatchesForTournament(
      leagueId:
          widget.tournament.leagueId,
      tournamentId:
          widget.tournament.id,
    );
  }

  Future<void> _generateAndSave(
    List<Team> teams,
  ) async {
    if (_saving) {
      return;
    }

    if (teams.length < 2) {
      _showMessage(
        'Necesitas al menos 2 equipos activos.',
      );

      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

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

      if (!schedule.isComplete) {
        throw StateError(
          'El calendario generado no es válido.',
        );
      }

      await _scheduleRepository.saveSchedule(
        leagueId:
            widget.tournament.leagueId,
        tournamentId:
            widget.tournament.id,
        schedule:
            schedule,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Calendario generado y guardado correctamente.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message;

      switch (error.code) {
        case 'permission-denied':
          message =
              'Firestore rechazó el guardado. '
              'Revisa que las reglas nuevas estén desplegadas.';
          break;

        case 'failed-precondition':
          message =
              'Firestore necesita una configuración adicional '
              'para realizar esta consulta.';
          break;

        default:
          message =
              'Firebase: ${error.code}.';
      }

      setState(() {
        _errorMessage =
            'No se pudo guardar el calendario. $message';
      });
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            error.message.toString();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'No se pudo guardar el calendario: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _confirmGenerate(
    List<Team> teams,
  ) async {
    final expectedMatches =
        (teams.length *
                (teams.length - 1)) ~/
            2;

    final expectedRounds =
        teams.length.isEven
            ? teams.length - 1
            : teams.length;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          icon: const Icon(
            CupertinoIcons
                .calendar_badge_plus,
            size: 40,
          ),
          title: const Text(
            'Generar calendario',
          ),
          content: Text(
            'Se generará el calendario Round-Robin para '
            '${teams.length} equipos.\n\n'
            '$expectedRounds jornadas\n'
            '$expectedMatches partidos\n\n'
            'Cada equipo se enfrentará una sola vez contra los demás.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  false,
                );
              },
              child:
                  const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  true,
                );
              },
              child:
                  const Text(
                'Generar y guardar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    await _generateAndSave(
      teams,
    );
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),
      ),
    );
  }

  int _totalRounds(
    List<TournamentMatchRecord> matches,
  ) {
    if (matches.isEmpty) {
      return 0;
    }

    var highest = 0;

    for (final match in matches) {
      if (match.roundNumber >
          highest) {
        highest =
            match.roundNumber;
      }
    }

    return highest;
  }

  Map<int, List<TournamentMatchRecord>>
      _groupMatchesByRound(
    List<TournamentMatchRecord> matches,
  ) {
    final grouped =
        <int, List<TournamentMatchRecord>>{};

    for (final match in matches) {
      grouped.putIfAbsent(
        match.roundNumber,
        () =>
            <TournamentMatchRecord>[],
      );

      grouped[match.roundNumber]!
          .add(
        match,
      );
    }

    for (final roundMatches
        in grouped.values) {
      roundMatches.sort(
        (a, b) =>
            a.matchNumber.compareTo(
          b.matchNumber,
        ),
      );
    }

    return grouped;
  }

  Team? _findByeTeam({
    required List<Team> teams,
    required List<TournamentMatchRecord>
        roundMatches,
  }) {
    if (teams.length.isEven) {
      return null;
    }

    final playingIds =
        <String>{};

    for (final match
        in roundMatches) {
      playingIds.add(
        match.homeTeamId,
      );

      playingIds.add(
        match.awayTeamId,
      );
    }

    final resting =
        teams
            .where(
              (team) =>
                  !playingIds.contains(
                team.id,
              ),
            )
            .toList();

    if (resting.length != 1) {
      return null;
    }

    return resting.first;
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
          teamsSnapshot,
        ) {
          if (teamsSnapshot.connectionState ==
                  ConnectionState.waiting &&
              !teamsSnapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (teamsSnapshot.hasError) {
            return _ErrorState(
              message:
                  'No se pudieron cargar los equipos.\n'
                  '${teamsSnapshot.error}',
            );
          }

          final teams =
              teamsSnapshot.data ??
                  const <Team>[];

          return StreamBuilder<
              List<TournamentMatchRecord>>(
            stream:
                _watchSavedMatches(),
            builder: (
              context,
              matchesSnapshot,
            ) {
              if (matchesSnapshot.connectionState ==
                      ConnectionState.waiting &&
                  !matchesSnapshot.hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (matchesSnapshot.hasError) {
                return _ErrorState(
                  message:
                      'No se pudo cargar el calendario guardado.\n'
                      '${matchesSnapshot.error}',
                );
              }

              final savedMatches =
                  matchesSnapshot.data ??
                      const <
                          TournamentMatchRecord>[];

              final hasSavedSchedule =
                  savedMatches.isNotEmpty;

              final totalRounds =
                  _totalRounds(
                savedMatches,
              );

              final grouped =
                  _groupMatchesByRound(
                savedMatches,
              );

              final roundNumbers =
                  grouped.keys.toList()
                    ..sort();

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
                            alpha:
                                0.76,
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
                              alpha:
                                  0.9,
                            ),
                            fontWeight:
                                FontWeight
                                    .w600,
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
                                alpha:
                                    0.78,
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
                              hasSavedSchedule
                                  ? '$totalRounds'
                                  : '—',
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
                              hasSavedSchedule
                                  ? '${savedMatches.length}'
                                  : '—',
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
                          horizontal:
                              11,
                          vertical:
                              6,
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
                                FontWeight
                                    .w900,
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
                      child:
                          const Column(
                        children: [
                          Icon(
                            CupertinoIcons
                                .person_3,
                            size: 44,
                          ),
                          SizedBox(
                            height:
                                12,
                          ),
                          Text(
                            'No hay equipos inscritos',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w900,
                              fontSize:
                                  17,
                            ),
                          ),
                          SizedBox(
                            height:
                                6,
                          ),
                          Text(
                            'Registra equipos en este torneo antes de generar el calendario.',
                            textAlign:
                                TextAlign
                                    .center,
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
                          bottom:
                              9,
                        ),
                        child:
                            _TeamTile(
                          team:
                              team,
                        ),
                      ),
                    ),

                  const SizedBox(
                    height: 24,
                  ),

                  if (!hasSavedSchedule)
                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          FilledButton.icon(
                        onPressed:
                            teams.length <
                                        2 ||
                                    _saving
                                ? null
                                : () {
                                    _confirmGenerate(
                                      teams,
                                    );
                                  },
                        icon:
                            _saving
                                ? const SizedBox(
                                    width:
                                        18,
                                    height:
                                        18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                    ),
                                  )
                                : const Icon(
                                    CupertinoIcons
                                        .wand_stars,
                                  ),
                        label:
                            Text(
                          _saving
                              ? 'Generando y guardando...'
                              : 'Generar y guardar calendario',
                        ),
                      ),
                    ),

                  if (_errorMessage !=
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
                            CrossAxisAlignment
                                .start,
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
                              _errorMessage!,
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

                  if (hasSavedSchedule) ...[
                    const SizedBox(
                      height: 4,
                    ),

                    Container(
                      padding:
                          const EdgeInsets.all(
                        17,
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
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons
                                .check_mark_circled_solid,
                            color:
                                colors.primary,
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Calendario guardado',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      3,
                                ),
                                Text(
                                  'Los partidos están guardados en Firestore y seguirán aquí al volver a entrar.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 26,
                    ),

                    Text(
                      'Calendario',
                      style: theme
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    ...roundNumbers.map(
                      (
                        roundNumber,
                      ) {
                        final matches =
                            grouped[
                                    roundNumber] ??
                                const <
                                    TournamentMatchRecord>[];

                        final byeTeam =
                            _findByeTeam(
                          teams:
                              teams,
                          roundMatches:
                              matches,
                        );

                        return Padding(
                          padding:
                              const EdgeInsets.only(
                            bottom:
                                16,
                          ),
                          child:
                              _SavedRoundCard(
                            roundNumber:
                                roundNumber,
                            matches:
                                matches,
                            byeTeam:
                                byeTeam,
                          ),
                        );
                      },
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
                      child:
                          const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Icon(
                            CupertinoIcons
                                .lock_fill,
                          ),

                          SizedBox(
                            width: 12,
                          ),

                          Expanded(
                            child: Text(
                              'El calendario ya está guardado. '
                              'Por seguridad todavía no permitimos regenerarlo '
                              'desde esta pantalla.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryCard
    extends StatelessWidget {
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
        color:
            colors.primaryContainer,
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
                      FontWeight
                          .w900,
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
            child:
                team.logoUrl.isEmpty
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
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  team.name,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight
                            .w900,
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

class _SavedRoundCard
    extends StatelessWidget {
  const _SavedRoundCard({
    required this.roundNumber,
    required this.matches,
    required this.byeTeam,
  });

  final int roundNumber;

  final List<TournamentMatchRecord>
      matches;

  final Team? byeTeam;

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
                  'Jornada $roundNumber',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight
                            .w900,
                    fontSize: 16,
                  ),
                ),

                const Spacer(),

                Text(
                  '${matches.length} '
                  '${matches.length == 1 ? 'partido' : 'partidos'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          ...matches.map(
            (match) =>
                _SavedMatchTile(
              match:
                  match,
            ),
          ),

          if (byeTeam != null)
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
                      '${byeTeam!.name} descansa',
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

class _SavedMatchTile
    extends StatelessWidget {
  const _SavedMatchTile({
    required this.match,
  });

  final TournamentMatchRecord match;

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
              match.homeTeamName,
              textAlign:
                  TextAlign.right,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight
                        .w800,
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
                    FontWeight
                        .w900,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Text(
              match.awayTeamName,
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
                CrossAxisAlignment
                    .start,
            children: [
              const Icon(
                CupertinoIcons
                    .exclamationmark_triangle_fill,
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child:
                    Text(
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