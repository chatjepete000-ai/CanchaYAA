import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../teams/data/team_match_repository.dart';
import '../../../teams/domain/public_team.dart';

// ================================================================
// WIDGETS COMPARTIDOS DE LA SECCIÓN TORNEOS
// ================================================================

const List<String> _weekdays = <String>[
  'lun',
  'mar',
  'mié',
  'jue',
  'vie',
  'sáb',
  'dom',
];

const List<String> _months = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Hora en formato de 12 horas: 6:00 PM.
String formatMatchTime(
  DateTime date,
) {
  final local = date.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minutes = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour < 12 ? 'AM' : 'PM';

  return '$hour12:$minutes $suffix';
}

/// Fecha corta: sáb 14 nov.
String formatMatchDay(
  DateTime date,
) {
  final local = date.toLocal();

  return '${_weekdays[local.weekday - 1]} '
      '${local.day} ${_months[local.month - 1]}';
}

/// Escudo del equipo con respaldo genérico.
class TeamCrest extends StatelessWidget {
  const TeamCrest({
    super.key,
    required this.team,
    this.size = 40,
  });

  final PublicTeam? team;
  final double size;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors = Theme.of(context).colorScheme;
    final logoUrl = team?.logoUrl.trim() ?? '';

    final fallback = Icon(
      CupertinoIcons.shield_fill,
      color: colors.primary,
      size: size * 0.6,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.12),
        ),
      ),
      alignment: Alignment.center,
      child: logoUrl.isEmpty
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.25),
              child: Image.network(
                logoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
    );
  }
}

/// Nombre que se muestra para un equipo del partido:
/// nombre corto público si existe, si no el nombre del partido.
String teamDisplayName(
  Map<String, PublicTeam> teams,
  String teamId,
  String fallbackName,
) {
  final team = teams[teamId];

  if (team != null) {
    return team.displayName;
  }

  final clean = fallbackName.trim();

  return clean.isEmpty ? 'Equipo' : clean;
}

/// Tarjeta de partido: local, marcador o VS, visitante, fecha,
/// hora y cancha.
class TournamentMatchCard extends StatelessWidget {
  const TournamentMatchCard({
    super.key,
    required this.match,
    required this.teams,
  });

  final TeamMatchSummary match;
  final Map<String, PublicTeam> teams;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final String center;
    if (match.isCompleted && match.hasResult) {
      center = '${match.homeScore} - ${match.awayScore}';
    } else {
      center = 'VS';
    }

    final String statusText;
    if (match.isCompleted) {
      statusText = 'Finalizado';
    } else if (match.isPostponed) {
      statusText = 'Pospuesto';
    } else if (match.startsAt == null) {
      statusText = 'Por programar';
    } else {
      statusText =
          '${formatMatchDay(match.startsAt!)} · ${formatMatchTime(match.startsAt!)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Side(
                  team: teams[match.homeTeamId],
                  name: teamDisplayName(
                    teams,
                    match.homeTeamId,
                    match.homeTeamName,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: match.isCompleted
                        ? colors.onSurface
                        : colors.primary,
                  ),
                ),
              ),
              Expanded(
                child: _Side(
                  team: teams[match.awayTeamId],
                  name: teamDisplayName(
                    teams,
                    match.awayTeamId,
                    match.awayTeamName,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
          if (match.courtName != null) ...[
            const SizedBox(height: 2),
            Text(
              match.courtName!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.team,
    required this.name,
  });

  final PublicTeam? team;
  final String name;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        TeamCrest(team: team, size: 46),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}
