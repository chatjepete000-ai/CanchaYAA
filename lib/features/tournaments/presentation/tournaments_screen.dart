import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/access_policy.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../data/tournament_repository.dart';
import '../domain/tournament_summary.dart';

class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const _TournamentMessage(
        message: 'Inicia la app con Firebase para consultar torneos.',
      );
    }

    final profileRepository = ProfileRepository();
    final tournamentRepository = TournamentRepository();

    return StreamBuilder<UserProfile?>(
      stream: profileRepository.watchCurrentProfile(),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final canManage = profile != null &&
            AccessPolicy.canManageLeague(profile.adminScope);

        return StreamBuilder<List<TournamentSummary>>(
          stream: tournamentRepository.watchTournaments(),
          builder: (context, tournamentSnapshot) {
            final tournaments = tournamentSnapshot.data ?? const [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Torneos',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Competencias, calendario y clasificación.',
                          ),
                        ],
                      ),
                    ),
                    if (canManage)
                      IconButton.filled(
                        tooltip: 'Crear torneo',
                        onPressed: () => _createTournament(
                          context,
                          repository: tournamentRepository,
                          profile: profile,
                        ),
                        icon: const Icon(Icons.add),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (tournaments.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.emoji_events_outlined, size: 56),
                          const SizedBox(height: 14),
                          const Text(
                            'Todavía no hay torneos publicados',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            canManage
                                ? 'Como administrador puedes crear el primer torneo de tu liga.'
                                : 'Cuando una liga publique un torneo podrás consultarlo aquí.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...tournaments.map(
                    (tournament) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TournamentCard(tournament: tournament),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<void> _createTournament(
    BuildContext context, {
    required TournamentRepository repository,
    required UserProfile profile,
  }) async {
    final name = TextEditingController();
    final category = TextEditingController();
    final city = TextEditingController();
    final leagueId = TextEditingController(
      text: profile.managedLeagueIds.isNotEmpty
          ? profile.managedLeagueIds.first
          : '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear torneo'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Categoría'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'Ciudad'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: leagueId,
                readOnly: profile.adminScope.name == 'league',
                decoration: const InputDecoration(
                  labelText: 'ID de liga',
                  helperText:
                      'El administrador de liga trabaja solo dentro de sus ligas asignadas.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty || leagueId.text.trim().isEmpty) {
                return;
              }

              try {
                await repository.createTournament(
                  leagueId: leagueId.text,
                  name: name.text,
                  category: category.text,
                  city: city.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo crear: $error')),
                );
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    name.dispose();
    category.dispose();
    city.dispose();
    leagueId.dispose();
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament});

  final TournamentSummary tournament;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.secondaryContainer,
              child: Icon(
                Icons.emoji_events_outlined,
                color: colors.secondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tournament.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (tournament.category.isNotEmpty) tournament.category,
                      if (tournament.city.isNotEmpty) tournament.city,
                    ].join(' · '),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      tournament.status == 'draft'
                          ? 'Borrador'
                          : tournament.status,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _TournamentMessage extends StatelessWidget {
  const _TournamentMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Torneos',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(message),
          ),
        ),
      ],
    );
  }
}
