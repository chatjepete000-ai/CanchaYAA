import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../courts/domain/court.dart';
import '../data/public_team_repository.dart';
import '../data/team_match_repository.dart';
import '../domain/public_team.dart';

class TeamCalendarScreen extends StatefulWidget {
  const TeamCalendarScreen({
    super.key,
    this.highlightedTeamIds = const <String>{},
  });

  final Set<String> highlightedTeamIds;

  @override
  State<TeamCalendarScreen> createState() =>
      _TeamCalendarScreenState();
}

class _TeamCalendarScreenState
    extends State<TeamCalendarScreen> {
  late final TeamMatchRepository _repository;

  late final PublicTeamRepository
      _publicTeamRepository;

  Timer? _clockTimer;

  late DateTime _now;

  int _selectedDayOffset = 0;

  bool _showResults = false;

  @override
  void initState() {
    super.initState();

    _repository =
        TeamMatchRepository();

    _publicTeamRepository =
        PublicTeamRepository();

    _now = DateTime.now();

    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _now = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();

    super.dispose();
  }

  DateTime get _today {
    return DateTime(
      _now.year,
      _now.month,
      _now.day,
    );
  }

  DateTime get _selectedDate {
    return _today.add(
      Duration(
        days: _selectedDayOffset,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Calendario',
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<
            List<TeamMatchSummary>>(
          stream:
              _repository.watchAllMatches(),
          builder: (
            context,
            matchSnapshot,
          ) {
            if (matchSnapshot
                        .connectionState ==
                    ConnectionState.waiting &&
                !matchSnapshot.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            if (matchSnapshot.hasError) {
              return _CalendarError(
                error:
                    matchSnapshot.error,
              );
            }

            final allMatches =
                matchSnapshot.data ??
                    const <
                        TeamMatchSummary>[];

            // ==================================================
            // INFORMACIÓN PÚBLICA DE EQUIPOS
            // ==================================================
            //
            // Aquí obtenemos:
            //
            // - shortName
            // - logoUrl
            // - name
            //
            // sin consultar los datos privados de teams.
            // ==================================================

            return StreamBuilder<
                List<PublicTeam>>(
              stream: _publicTeamRepository
                  .watchAllTeams(),
              builder: (
                context,
                publicTeamsSnapshot,
              ) {
                final publicTeams =
                    publicTeamsSnapshot.data ??
                        const <
                            PublicTeam>[];

                final teamsById =
                    _publicTeamRepository
                        .mapById(
                  publicTeams,
                );

                final visibleMatches =
                    _showResults
                        ? _resultMatches(
                            allMatches,
                          )
                        : _matchesForSelectedDay(
                            allMatches,
                          );

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _now =
                          DateTime.now();
                    });
                  },
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(
                      parent:
                          BouncingScrollPhysics(),
                    ),
                    padding:
                        const EdgeInsets.fromLTRB(
                      18,
                      14,
                      18,
                      32,
                    ),
                    children: [
                      // =========================================
                      // HERO
                      // =========================================

                      _CalendarHero(
                        now: _now,
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // =========================================
                      // FILTROS
                      // =========================================

                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection:
                              Axis.horizontal,
                          children: [
                            for (
                              int offset =
                                  0;
                              offset < 6;
                              offset++
                            )
                              Padding(
                                padding:
                                    const EdgeInsets.only(
                                  right: 8,
                                ),
                                child:
                                    ChoiceChip(
                                  selected:
                                      !_showResults &&
                                          _selectedDayOffset ==
                                              offset,
                                  label:
                                      Text(
                                    _dayChipLabel(
                                      _today.add(
                                        Duration(
                                          days:
                                              offset,
                                        ),
                                      ),
                                      offset,
                                    ),
                                  ),
                                  onSelected:
                                      (_) {
                                    setState(
                                      () {
                                        _showResults =
                                            false;

                                        _selectedDayOffset =
                                            offset;
                                      },
                                    );
                                  },
                                ),
                              ),

                            ChoiceChip(
                              selected:
                                  _showResults,
                              avatar:
                                  const Icon(
                                CupertinoIcons
                                    .check_mark_circled,
                                size: 17,
                              ),
                              label:
                                  const Text(
                                'Resultados',
                              ),
                              onSelected:
                                  (_) {
                                setState(
                                  () {
                                    _showResults =
                                        true;
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 22,
                      ),

                      // =========================================
                      // TÍTULO DEL DÍA
                      // =========================================

                      _CalendarSectionHeader(
                        title: _showResults
                            ? 'Resultados'
                            : _dateSectionTitle(
                                _selectedDate,
                              ),
                        count:
                            visibleMatches
                                .length,
                        results:
                            _showResults,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // =========================================
                      // PARTIDOS
                      // =========================================

                      if (visibleMatches
                          .isEmpty)
                        _EmptyCalendar(
                          showingResults:
                              _showResults,
                          date:
                              _selectedDate,
                        )
                      else
                        ...visibleMatches.map(
                          (
                            match,
                          ) {
                            final highlighted =
                                widget
                                        .highlightedTeamIds
                                        .contains(
                                      match.homeTeamId,
                                    ) ||
                                    widget
                                        .highlightedTeamIds
                                        .contains(
                                      match.awayTeamId,
                                    );

                            final homeTeam =
                                teamsById[
                                    match.homeTeamId];

                            final awayTeam =
                                teamsById[
                                    match.awayTeamId];

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child:
                                  _MatchCard(
                                match:
                                    match,
                                homeTeam:
                                    homeTeam,
                                awayTeam:
                                    awayTeam,
                                highlighted:
                                    highlighted,
                                showingResults:
                                    _showResults,
                              ),
                            );
                          },
                        ),

                      if (widget
                          .highlightedTeamIds
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 8,
                        ),

                        const _HighlightedInfo(),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<TeamMatchSummary>
      _matchesForSelectedDay(
    List<TeamMatchSummary> matches,
  ) {
    final filtered =
        matches
            .where(
              (
                match,
              ) =>
                  match.isScheduled &&
                  match.startsAt !=
                      null &&
                  match.happensOnLocalDay(
                    _selectedDate,
                  ),
            )
            .toList();

    filtered.sort(
      (
        first,
        second,
      ) {
        final firstDate =
            first.startsAt;

        final secondDate =
            second.startsAt;

        if (firstDate == null &&
            secondDate == null) {
          return 0;
        }

        if (firstDate == null) {
          return 1;
        }

        if (secondDate == null) {
          return -1;
        }

        return firstDate.compareTo(
          secondDate,
        );
      },
    );

    return filtered;
  }

  List<TeamMatchSummary>
      _resultMatches(
    List<TeamMatchSummary> matches,
  ) {
    final filtered =
        matches
            .where(
              (
                match,
              ) =>
                  match.isCompleted &&
                  match.hasResult,
            )
            .toList();

    filtered.sort(
      (
        first,
        second,
      ) {
        final firstDate =
            first.startsAt ??
                DateTime
                    .fromMillisecondsSinceEpoch(
                  0,
                );

        final secondDate =
            second.startsAt ??
                DateTime
                    .fromMillisecondsSinceEpoch(
                  0,
                );

        return secondDate.compareTo(
          firstDate,
        );
      },
    );

    return filtered;
  }
}

// ================================================================
// HERO
// ================================================================

class _CalendarHero
    extends StatelessWidget {
  const _CalendarHero({
    required this.now,
  });

  final DateTime now;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        24,
      ),
      child: SizedBox(
        height: 156,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/home/hero_match.jpg',
              fit: BoxFit.cover,
            ),

            Container(
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topLeft,
                  end:
                      Alignment.bottomRight,
                  colors: [
                    Colors.black
                        .withValues(
                      alpha: 0.60,
                    ),
                    Colors.black
                        .withValues(
                      alpha: 0.34,
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withValues(
                        alpha: 0.18,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child:
                        const Icon(
                      CupertinoIcons
                          .calendar,
                      color:
                          Colors.white,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  const Text(
                    'Partidos y resultados',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          21,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    _formatFullDate(
                      now,
                    ),
                    style:
                        TextStyle(
                      color: Colors.white
                          .withValues(
                        alpha: 0.88,
                      ),
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// ENCABEZADO
// ================================================================

class _CalendarSectionHeader
    extends StatelessWidget {
  const _CalendarSectionHeader({
    required this.title,
    required this.count,
    required this.results,
  });

  final String title;

  final int count;

  final bool results;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
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
        ),

        Text(
          results
              ? '$count resultados'
              : '$count partidos',
          style: Theme.of(
            context,
          )
              .textTheme
              .bodySmall,
        ),
      ],
    );
  }
}

// ================================================================
// TARJETA DE PARTIDO
// ================================================================

class _MatchCard
    extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.homeTeam,
    required this.awayTeam,
    required this.highlighted,
    required this.showingResults,
  });

  final TeamMatchSummary match;

  final PublicTeam? homeTeam;

  final PublicTeam? awayTeam;

  final bool highlighted;

  final bool showingResults;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final start =
        match.localStartsAt;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        12,
      ),
      decoration:
          BoxDecoration(
        color: highlighted
            ? colors
                .surfaceContainerHighest
                .withValues(
                  alpha: 0.88,
                )
            : colors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: highlighted
              ? colors.primary
                  .withValues(
                    alpha: 0.28,
                  )
              : colors
                  .outlineVariant
                  .withValues(
                    alpha: 0.62,
                  ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.035,
            ),
            blurRadius: 12,
            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          // =====================================================
          // HORA / TU EQUIPO
          // =====================================================

          Row(
            children: [
              _TimeBadge(
                date: start,
              ),

              const Spacer(),

              if (highlighted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colors.primary
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      100,
                    ),
                  ),
                  child:
                      Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons
                            .person_2_fill,
                        color:
                            colors.primary,
                        size: 14,
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      Text(
                        'Tu equipo',
                        style:
                            TextStyle(
                          color:
                              colors.primary,
                          fontSize:
                              11,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          // =====================================================
          // EQUIPOS + ESCUDOS REALES
          // =====================================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                    _TeamSide(
                  officialName:
                      match.homeTeamName,
                  publicTeam:
                      homeTeam,
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  8,
                  23,
                  8,
                  0,
                ),
                child:
                    showingResults &&
                            match.hasResult
                        ? _Score(
                            match:
                                match,
                          )
                        : Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration:
                                BoxDecoration(
                              color: colors
                                  .surfaceContainerHighest,
                              borderRadius:
                                  BorderRadius.circular(
                                100,
                              ),
                            ),
                            child:
                                const Text(
                              'VS',
                              style:
                                  TextStyle(
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ),
              ),

              Expanded(
                child:
                    _TeamSide(
                  officialName:
                      match.awayTeamName,
                  publicTeam:
                      awayTeam,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 17,
          ),

          Divider(
            height: 1,
            color: colors
                .outlineVariant
                .withValues(
              alpha: 0.55,
            ),
          ),

          const SizedBox(
            height: 11,
          ),

          // =====================================================
          // CANCHA
          // =====================================================

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons
                    .location_solid,
                size: 16,
                color:
                    colors.primary,
              ),

              const SizedBox(
                width: 6,
              ),

              Flexible(
                child: Text(
                  match.courtName ??
                      'Cancha por asignar',
                  textAlign:
                      TextAlign.center,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    fontSize:
                        12,
                    fontWeight:
                        FontWeight.w700,
                    color: match.courtName ==
                            null
                        ? colors
                            .onSurfaceVariant
                        : null,
                  ),
                ),
              ),
            ],
          ),

          // =====================================================
          // CÓMO LLEGAR
          // =====================================================

          if (!showingResults &&
              match.hasCourt) ...[
            const SizedBox(
              height: 8,
            ),

            Center(
              child:
                  TextButton.icon(
                style:
                    TextButton.styleFrom(
                  visualDensity:
                      VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
                onPressed:
                    () {
                  _openCourt(
                    context,
                    match,
                  );
                },
                icon:
                    const Icon(
                  CupertinoIcons
                      .location,
                  size: 14,
                ),
                label:
                    const Text(
                  'Cómo llegar',
                  style:
                      TextStyle(
                    fontSize:
                        11,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],

          // =====================================================
          // RESUMEN DE RESULTADO
          // =====================================================

          if (showingResults) ...[
            const SizedBox(
              height: 8,
            ),

            Center(
              child:
                  TextButton.icon(
                style:
                    TextButton.styleFrom(
                  visualDensity:
                      VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
                onPressed:
                    () {
                  _showMatchSummary(
                    context,
                    match,
                    homeTeam:
                        homeTeam,
                    awayTeam:
                        awayTeam,
                  );
                },
                icon:
                    const Icon(
                  CupertinoIcons
                      .doc_text,
                  size: 14,
                ),
                label:
                    const Text(
                  'Resumen',
                  style:
                      TextStyle(
                    fontSize:
                        11,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ================================================================
// EQUIPO + ESCUDO
// ================================================================

class _TeamSide
    extends StatelessWidget {
  const _TeamSide({
    required this.officialName,
    required this.publicTeam,
  });

  final String officialName;

  final PublicTeam? publicTeam;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final displayName =
        publicTeam?.displayName ??
            _compactTeamName(
              officialName,
            );

    final logoUrl =
        publicTeam?.logoUrl
                .trim() ??
            '';

    final hasLogo =
        logoUrl.isNotEmpty;

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        // =======================================================
        // ESCUDO
        // =======================================================

        Container(
          width: 62,
          height: 62,
          padding:
              hasLogo
                  ? const EdgeInsets.all(
                      3,
                    )
                  : EdgeInsets.zero,
          decoration:
              BoxDecoration(
            color: colors
                .primaryContainer,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border:
                Border.all(
              color: colors.primary
                  .withValues(
                    alpha: 0.12,
                  ),
            ),
          ),
          child: hasLogo
              ? ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  child:
                      Image.network(
                    logoUrl,
                    fit:
                        BoxFit.cover,
                    errorBuilder:
                        (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return _FallbackShield(
                        color:
                            colors.primary,
                      );
                    },
                  ),
                )
              : _FallbackShield(
                  color:
                      colors.primary,
                ),
        ),

        const SizedBox(
          height: 9,
        ),

        // =======================================================
        // NOMBRE CORTO
        // =======================================================

        Text(
          displayName,
          textAlign:
              TextAlign.center,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontSize:
                13,
            height:
                1.15,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _FallbackShield
    extends StatelessWidget {
  const _FallbackShield({
    required this.color,
  });

  final Color color;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Icon(
        CupertinoIcons
            .shield_fill,
        color:
            color,
        size:
            29,
      ),
    );
  }
}

// ================================================================
// HORA AM / PM
// ================================================================

class _TimeBadge
    extends StatelessWidget {
  const _TimeBadge({
    required this.date,
  });

  final DateTime? date;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final time =
        date == null
            ? '--:--'
            : _formatTime12(
                date!,
              );

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        color: colors
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons
                .clock_fill,
            size: 14,
            color:
                colors.primary,
          ),

          const SizedBox(
            width: 5,
          ),

          Text(
            time,
            style:
                const TextStyle(
              fontSize:
                  12,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// MARCADOR
// ================================================================

class _Score
    extends StatelessWidget {
  const _Score({
    required this.match,
  });

  final TeamMatchSummary match;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      '${match.homeScore ?? '-'}'
      ' - '
      '${match.awayScore ?? '-'}',
      style: Theme.of(
        context,
      )
          .textTheme
          .titleLarge
          ?.copyWith(
            fontWeight:
                FontWeight.w900,
          ),
    );
  }
}

// ================================================================
// INFORMACIÓN EQUIPO RESALTADO
// ================================================================

class _HighlightedInfo
    extends StatelessWidget {
  const _HighlightedInfo();

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
        color: colors
            .surfaceContainerHighest
            .withValues(
          alpha: 0.60,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child:
          const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons
                .info_circle,
            size: 18,
          ),

          SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              'Los partidos donde participa uno de tus equipos aparecen resaltados.',
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SIN PARTIDOS
// ================================================================

class _EmptyCalendar
    extends StatelessWidget {
  const _EmptyCalendar({
    required this.showingResults,
    required this.date,
  });

  final bool showingResults;

  final DateTime date;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        28,
      ),
      decoration:
          BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(
          alpha: 0.45,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Column(
        children: [
          Icon(
            showingResults
                ? CupertinoIcons
                    .check_mark_circled
                : CupertinoIcons
                    .calendar,
            size: 34,
            color:
                colors.primary,
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            showingResults
                ? 'Todavía no hay resultados publicados.'
                : 'No hay partidos programados para ${_formatShortDate(date)}.',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ERROR
// ================================================================

class _CalendarError
    extends StatelessWidget {
  const _CalendarError({
    required this.error,
  });

  final Object? error;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Container(
          padding:
              const EdgeInsets.all(
            18,
          ),
          decoration:
              BoxDecoration(
            color:
                colors.errorContainer,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons
                    .exclamationmark_triangle_fill,
                color: colors
                    .onErrorContainer,
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                'No se pudo cargar el calendario.',
                style:
                    TextStyle(
                  color: colors
                      .onErrorContainer,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                '$error',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color: colors
                      .onErrorContainer,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ABRIR MAPA
// ================================================================

Future<void> _openCourt(
  BuildContext context,
  TeamMatchSummary match,
) async {
  final courtId =
      match.courtId?.trim() ??
          '';

  if (courtId.isEmpty) {
    _showMessage(
      context,
      'Este partido todavía no tiene cancha asignada.',
    );

    return;
  }

  try {
    final snapshot =
        await FirebaseFirestore
            .instance
            .collection(
              'courts',
            )
            .doc(
              courtId,
            )
            .get();

    final data =
        snapshot.data();

    if (!snapshot.exists ||
        data == null) {
      if (context.mounted) {
        _showMessage(
          context,
          'No se encontró la información de la cancha.',
        );
      }

      return;
    }

    final court =
        Court.fromMap(
      snapshot.id,
      data,
    );

    final opened =
        await launchUrl(
      court.directionsUri,
      mode:
          LaunchMode.externalApplication,
    );

    if (!opened &&
        context.mounted) {
      _showMessage(
        context,
        'No se pudo abrir la aplicación de mapas.',
      );
    }
  } catch (_) {
    if (!context.mounted) {
      return;
    }

    _showMessage(
      context,
      'No se pudo abrir la ubicación de la cancha.',
    );
  }
}

// ================================================================
// RESUMEN
// ================================================================

void _showMatchSummary(
  BuildContext context,
  TeamMatchSummary match, {
  PublicTeam? homeTeam,
  PublicTeam? awayTeam,
}) {
  final homeName =
      homeTeam?.displayName ??
          _compactTeamName(
            match.homeTeamName,
          );

  final awayName =
      awayTeam?.displayName ??
          _compactTeamName(
            match.awayTeamName,
          );

  showModalBottomSheet<void>(
    context:
        context,
    showDragHandle:
        true,
    isScrollControlled:
        true,
    builder:
        (
      context,
    ) {
      return SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            4,
            20,
            28,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Text(
                'Resumen del partido',
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
                height: 22,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        _SummaryTeam(
                      name:
                          homeName,
                      logoUrl:
                          homeTeam
                                  ?.logoUrl ??
                              '',
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: Text(
                      '${match.homeScore ?? '-'} - ${match.awayScore ?? '-'}',
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w900,
                          ),
                    ),
                  ),

                  Expanded(
                    child:
                        _SummaryTeam(
                      name:
                          awayName,
                      logoUrl:
                          awayTeam
                                  ?.logoUrl ??
                              '',
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 24,
              ),

              const _SummarySection(
                icon:
                    CupertinoIcons
                        .sportscourt,
                title:
                    'Goles',
              ),

              const SizedBox(
                height: 10,
              ),

              const _SummarySection(
                icon:
                    CupertinoIcons
                        .rectangle_fill,
                title:
                    'Tarjetas',
              ),

              const SizedBox(
                height: 10,
              ),

              const _SummarySection(
                icon:
                    CupertinoIcons
                        .arrow_right_arrow_left,
                title:
                    'Cambios',
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SummaryTeam
    extends StatelessWidget {
  const _SummaryTeam({
    required this.name,
    required this.logoUrl,
  });

  final String name;

  final String logoUrl;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final hasLogo =
        logoUrl.trim().isNotEmpty;

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration:
              BoxDecoration(
            color: colors
                .primaryContainer,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: hasLogo
              ? ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  child:
                      Image.network(
                    logoUrl,
                    fit:
                        BoxFit.cover,
                    errorBuilder:
                        (
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
                )
              : Icon(
                  CupertinoIcons
                      .shield_fill,
                  color:
                      colors.primary,
                ),
        ),

        const SizedBox(
          height: 7,
        ),

        Text(
          name,
          textAlign:
              TextAlign.center,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SummarySection
    extends StatelessWidget {
  const _SummarySection({
    required this.icon,
    required this.title,
  });

  final IconData icon;

  final String title;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color: colors
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                colors.primary,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),

          Text(
            'Sin eventos',
            style: Theme.of(
              context,
            )
                .textTheme
                .bodySmall,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// FALLBACK PARA EQUIPOS SIN publicTeams
// ================================================================

String _compactTeamName(
  String name,
) {
  final clean =
      name.trim();

  if (clean.isEmpty) {
    return 'Equipo';
  }

  if (clean.length <= 18) {
    return clean;
  }

  const removableWords =
      <String>{
    'el',
    'la',
    'los',
    'las',
    'de',
    'del',
  };

  final words =
      clean
          .split(
            RegExp(
              r'\s+',
            ),
          )
          .where(
            (
              word,
            ) =>
                !removableWords
                    .contains(
              word.toLowerCase(),
            ),
          )
          .toList();

  final compact =
      words.join(
    ' ',
  );

  if (compact.length <= 20) {
    return compact;
  }

  if (words.length >= 2) {
    final short =
        '${words.first} ${words.last}';

    if (short.length <= 20) {
      return short;
    }
  }

  return clean.length <= 20
      ? clean
      : '${clean.substring(0, 17)}...';
}

// ================================================================
// HORA 12 HORAS
// ================================================================

String _formatTime12(
  DateTime date,
) {
  final period =
      date.hour >= 12
          ? 'PM'
          : 'AM';

  var hour =
      date.hour % 12;

  if (hour == 0) {
    hour = 12;
  }

  final minute =
      date.minute
          .toString()
          .padLeft(
            2,
            '0',
          );

  return '$hour:$minute $period';
}

void _showMessage(
  BuildContext context,
  String message,
) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(
    SnackBar(
      content:
          Text(
        message,
      ),
    ),
  );
}

String _dayChipLabel(
  DateTime date,
  int offset,
) {
  if (offset == 0) {
    return 'Hoy';
  }

  if (offset == 1) {
    return 'Mañana';
  }

  const weekdays =
      <String>[
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  return '${weekdays[date.weekday - 1]} ${date.day}';
}

String _dateSectionTitle(
  DateTime date,
) {
  const weekdays =
      <String>[
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  return '${weekdays[date.weekday - 1]} ${date.day}';
}

String _formatShortDate(
  DateTime date,
) {
  const months =
      <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  return '${date.day} de ${months[date.month - 1]}';
}

String _formatFullDate(
  DateTime date,
) {
  const weekdays =
      <String>[
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  const months =
      <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  return '${weekdays[date.weekday - 1]} '
      '${date.day} de '
      '${months[date.month - 1]} de '
      '${date.year}';
}