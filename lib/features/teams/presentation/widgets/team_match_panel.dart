import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../courts/domain/court.dart';
import '../../data/team_match_repository.dart';

class TeamMatchPanel extends StatelessWidget {
  const TeamMatchPanel({
    super.key,
    required this.teamId,
    required this.tournamentId,
  });

  final String teamId;
  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    final repository = TeamMatchRepository();

    return StreamBuilder<List<TeamMatchSummary>>(
      stream: repository.watchMatchesForTeam(
        tournamentId: tournamentId,
        teamId: teamId,
      ),
      builder: (
        context,
        snapshot,
      ) {
        // =====================================================
        // CARGANDO
        // =====================================================

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(
              top: 14,
            ),
            child: LinearProgressIndicator(),
          );
        }

        // =====================================================
        // ERROR
        // =====================================================
        //
        // Dejamos el error real visible temporalmente para
        // identificar exactamente qué está rechazando Firestore.
        //
        // Por ejemplo:
        //
        // permission-denied
        // failed-precondition
        // unavailable
        //
        // =====================================================

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(
              top: 14,
            ),
            child: _InfoBox(
              icon: CupertinoIcons
                  .exclamationmark_triangle,
              text:
                  'No se pudo consultar el calendario del equipo.\n\n'
                  '${snapshot.error}',
              isError: true,
            ),
          );
        }

        final matches =
            snapshot.data ??
                const <TeamMatchSummary>[];

        // =====================================================
        // SIN ENFRENTAMIENTOS
        // =====================================================

        if (matches.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(
              top: 14,
            ),
            child: _InfoBox(
              icon: CupertinoIcons.calendar,
              text:
                  'Este equipo todavía no tiene enfrentamientos registrados.',
            ),
          );
        }

        final now = DateTime.now();

        // =====================================================
        // PARTIDOS POSPUESTOS
        // =====================================================

        final postponed = matches
            .where(
              (match) => match.isPostponed,
            )
            .toList();

        // =====================================================
        // PRÓXIMOS PARTIDOS CON FECHA
        // =====================================================

        final upcoming = matches
            .where(
              (match) =>
                  match.isScheduled &&
                  match.startsAt != null &&
                  !match.startsAt!.isBefore(
                    now.subtract(
                      const Duration(
                        minutes: 5,
                      ),
                    ),
                  ),
            )
            .toList();

        upcoming.sort(
          (
            first,
            second,
          ) =>
              first.startsAt!.compareTo(
            second.startsAt!,
          ),
        );

        final nextMatch =
            upcoming.isEmpty
                ? null
                : upcoming.first;

        // =====================================================
        // PARTIDOS GENERADOS PERO TODAVÍA SIN HORARIO
        // =====================================================

        final waitingForSchedule = matches
            .where(
              (match) =>
                  match.isScheduled &&
                  match.startsAt == null,
            )
            .toList();

        final pendingMatch =
            waitingForSchedule.isEmpty
                ? null
                : waitingForSchedule.first;

        // =====================================================
        // ÚLTIMO RESULTADO
        // =====================================================

        final completed = matches
            .where(
              (match) =>
                  match.isCompleted &&
                  match.hasResult,
            )
            .toList();

        completed.sort(
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

        final latestResult =
            completed.isEmpty
                ? null
                : completed.first;

        // =====================================================
        // CONTENIDO
        // =====================================================

        return Padding(
          padding: const EdgeInsets.only(
            top: 14,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // -------------------------------------------------
              // POSPUESTO
              // -------------------------------------------------

              if (postponed.isNotEmpty)
                _PostponedMatchCard(
                  match: postponed.first,
                  teamId: teamId,
                ),

              if (postponed.isNotEmpty &&
                  nextMatch != null)
                const SizedBox(
                  height: 10,
                ),

              // -------------------------------------------------
              // PRÓXIMO PARTIDO
              // -------------------------------------------------

              if (nextMatch != null)
                _NextMatchCard(
                  match: nextMatch,
                  teamId: teamId,
                )

              // -------------------------------------------------
              // ENFRENTAMIENTO SIN CANCHA/HORARIO
              // -------------------------------------------------

              else if (pendingMatch != null)
                _PendingMatchCard(
                  match: pendingMatch,
                  teamId: teamId,
                ),

              // -------------------------------------------------
              // SEPARACIÓN RESULTADO
              // -------------------------------------------------

              if ((postponed.isNotEmpty ||
                      nextMatch != null ||
                      pendingMatch != null) &&
                  latestResult != null)
                const SizedBox(
                  height: 10,
                ),

              // -------------------------------------------------
              // ÚLTIMO RESULTADO
              // -------------------------------------------------

              if (latestResult != null)
                _LatestResultCard(
                  match: latestResult,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ================================================================
// PRÓXIMO PARTIDO
// ================================================================

class _NextMatchCard extends StatelessWidget {
  const _NextMatchCard({
    required this.match,
    required this.teamId,
  });

  final TeamMatchSummary match;
  final String teamId;

  Future<void> _openCourt(
    BuildContext context,
  ) async {
    final courtId =
        match.courtId?.trim() ?? '';

    if (courtId.isEmpty) {
      _showMessage(
        context,
        'Este partido todavía no tiene una cancha asignada.',
      );

      return;
    }

    try {
      // ==========================================================
      // CONSULTAR LA CANCHA QUE ASIGNÓ EL ADMINISTRADOR
      // ==========================================================

      final snapshot =
          await FirebaseFirestore.instance
              .collection(
                'courts',
              )
              .doc(
                courtId,
              )
              .get();

      final data = snapshot.data();

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

      final court = Court.fromMap(
        snapshot.id,
        data,
      );

      // ==========================================================
      // ABRIR MAPA / NAVEGACIÓN
      // ==========================================================

      final opened = await launchUrl(
        court.directionsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened &&
          context.mounted) {
        _showMessage(
          context,
          'No se pudo abrir la aplicación de mapas.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showMessage(
          context,
          'No se pudo abrir la ubicación de la cancha.',
        );
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    final start =
        match.startsAt!.toLocal();

    final opponent =
        match.opponentName(
      teamId,
    );

    final courtName =
        match.courtName
                    ?.trim()
                    .isNotEmpty ==
                true
            ? match.courtName!.trim()
            : 'Cancha por confirmar';

    final hasCourt =
        match.courtId
                ?.trim()
                .isNotEmpty ==
            true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer
            .withValues(
          alpha: 0.45,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: colors.primary
              .withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons
                    .sportscourt_fill,
                color: colors.primary,
                size: 19,
              ),

              const SizedBox(
                width: 8,
              ),

              const Expanded(
                child: Text(
                  'Próximo partido',
                  style: TextStyle(
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

          Text(
            'vs $opponent',
            style: Theme.of(
              context,
            )
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
          ),

          const SizedBox(
            height: 12,
          ),

          // =====================================================
          // FECHA
          // =====================================================

          _MatchDetailRow(
            icon:
                CupertinoIcons.calendar,
            text:
                _formatDate(
              start,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          // =====================================================
          // HORA
          // =====================================================

          _MatchDetailRow(
            icon:
                CupertinoIcons.clock_fill,
            text:
                _formatTime(
              start,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          // =====================================================
          // CANCHA
          // =====================================================

          InkWell(
            onTap: hasCourt
                ? () => _openCourt(
                      context,
                    )
                : null,
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            child: Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                vertical: 5,
              ),
              child:
                  _MatchDetailRow(
                icon:
                    CupertinoIcons
                        .location_solid,
                text:
                    courtName,
                emphasized:
                    hasCourt,
              ),
            ),
          ),

          // =====================================================
          // CÓMO LLEGAR
          // =====================================================

          if (hasCourt) ...[
            const SizedBox(
              height: 14,
            ),

            SizedBox(
              width: double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed: () =>
                    _openCourt(
                  context,
                ),
                icon: const Icon(
                  CupertinoIcons
                      .map_fill,
                ),
                label: const Text(
                  'Cómo llegar',
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
// ENFRENTAMIENTO GENERADO PERO TODAVÍA SIN CANCHA/HORA
// ================================================================

class _PendingMatchCard
    extends StatelessWidget {
  const _PendingMatchCard({
    required this.match,
    required this.teamId,
  });

  final TeamMatchSummary match;
  final String teamId;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons
                    .calendar_badge_plus,
                color: colors.primary,
              ),

              const SizedBox(
                width: 9,
              ),

              const Expanded(
                child: Text(
                  'Próximo enfrentamiento',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          Text(
            'vs ${match.opponentName(teamId)}',
            style: const TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          const Text(
            'El enfrentamiento ya fue generado, '
            'pero el administrador todavía no asigna '
            'cancha, fecha y horario.',
          ),
        ],
      ),
    );
  }
}

// ================================================================
// PARTIDO POSPUESTO
// ================================================================

class _PostponedMatchCard
    extends StatelessWidget {
  const _PostponedMatchCard({
    required this.match,
    required this.teamId,
  });

  final TeamMatchSummary match;
  final String teamId;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: colors.errorContainer
            .withValues(
          alpha: 0.78,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons
                .exclamationmark_triangle_fill,
            color:
                colors.onErrorContainer,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Partido pospuesto',
                  style: TextStyle(
                    color: colors
                        .onErrorContainer,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  'vs ${match.opponentName(teamId)}. '
                  'Espera la nueva cancha, fecha y horario.',
                  style: TextStyle(
                    color: colors
                        .onErrorContainer,
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

// ================================================================
// ÚLTIMO RESULTADO
// ================================================================

class _LatestResultCard
    extends StatelessWidget {
  const _LatestResultCard({
    required this.match,
  });

  final TeamMatchSummary match;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        15,
      ),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons
                    .check_mark_circled_solid,
                color: colors.primary,
                size: 20,
              ),

              const SizedBox(
                width: 8,
              ),

              const Text(
                'Último resultado',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          Text(
            '${match.homeTeamName} '
            '${match.homeScore} - '
            '${match.awayScore} '
            '${match.awayTeamName}',
            style: Theme.of(
              context,
            )
                .textTheme
                .titleMedium
                ?.copyWith(
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
// FILA DE INFORMACIÓN
// ================================================================

class _MatchDetailRow
    extends StatelessWidget {
  const _MatchDetailRow({
    required this.icon,
    required this.text,
    this.emphasized = false,
  });

  final IconData icon;
  final String text;
  final bool emphasized;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: colors.primary,
        ),

        const SizedBox(
          width: 8,
        ),

        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontWeight:
                  emphasized
                      ? FontWeight.w900
                      : FontWeight.w600,
              decoration:
                  emphasized
                      ? TextDecoration
                          .underline
                      : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// MENSAJE INFORMATIVO / ERROR
// ================================================================

class _InfoBox
    extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: isError
            ? colors.errorContainer
                .withValues(
                alpha: 0.65,
              )
            : colors
                .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isError
                ? colors
                    .onErrorContainer
                : colors.primary,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isError
                    ? colors
                        .onErrorContainer
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// MOSTRAR MENSAJE
// ================================================================

void _showMessage(
  BuildContext context,
  String message,
) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(
    SnackBar(
      content: Text(
        message,
      ),
    ),
  );
}

// ================================================================
// FORMATO DE FECHA
// ================================================================

String _formatDate(
  DateTime value,
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

  return '${weekdays[value.weekday - 1]} '
      '${value.day} de '
      '${months[value.month - 1]}';
}

// ================================================================
// FORMATO DE HORA
// ================================================================

String _formatTime(
  DateTime value,
) {
  final hour =
      value.hour
          .toString()
          .padLeft(
            2,
            '0',
          );

  final minute =
      value.minute
          .toString()
          .padLeft(
            2,
            '0',
          );

  return '$hour:$minute h';
}