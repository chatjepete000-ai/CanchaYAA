import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_card.dart';
import '../../leagues/domain/league_models.dart';
import '../data/public_tournament_repository.dart';
import '../domain/public_tournament.dart';
import 'tournament_detail_screen.dart';

// ================================================================
// SECCIÓN TORNEOS
// ================================================================
//
// Centro de información deportiva general. Cualquier usuario
// autenticado consulta aquí los torneos publicados y, dentro de
// cada uno, calendario, resultados, tabla y equipos.
//
// Solo lectura: administrar torneos sigue en la sección Admin.
// ================================================================

class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = <Widget>[
      Text(
        'Torneos',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Calendario, resultados y tabla de posiciones.',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 20),
    ];

    // Las pruebas de widgets no inicializan Firebase.
    if (Firebase.apps.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ...header,
          const EmptyStateCard(
            icon: Icons.emoji_events_outlined,
            title: 'Sin torneos registrados',
            message: 'Aquí aparecerán calendario, resultados y '
                'posiciones de cada torneo.',
          ),
        ],
      );
    }

    return StreamBuilder<List<PublicTournament>>(
      stream: PublicTournamentRepository().watchListedTournaments(),
      builder: (context, snapshot) {
        final Widget content;

        if (snapshot.hasError) {
          content = const EmptyStateCard(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'No se pudieron cargar los torneos',
            message: 'Revisa tu conexión e inténtalo de nuevo.',
          );
        } else if (!snapshot.hasData) {
          content = const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.data!.isEmpty) {
          content = const EmptyStateCard(
            icon: Icons.emoji_events_outlined,
            title: 'Sin torneos registrados',
            message: 'Cuando un administrador publique un torneo, '
                'aparecerá aquí.',
          );
        } else {
          content = Column(
            children: [
              for (final tournament in snapshot.data!)
                _TournamentCard(tournament: tournament),
            ],
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            ...header,
            content,
          ],
        );
      },
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({
    required this.tournament,
  });

  final PublicTournament tournament;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final details = <String>[
      tournament.format.label,
      if (tournament.category.isNotEmpty) tournament.category,
      if (tournament.city.isNotEmpty) tournament.city,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TournamentDetailScreen(
                  tournament: tournament,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    CupertinoIcons.star_circle_fill,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details.join(' · '),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      _StatusChip(status: tournament.status),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
  });

  final TournamentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // "Borrador" es un término administrativo; para el público se
    // muestra como "Próximamente".
    final label = status == TournamentStatus.draft
        ? 'Próximamente'
        : status.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
