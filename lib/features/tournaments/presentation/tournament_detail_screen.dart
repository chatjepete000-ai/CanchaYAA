import 'package:flutter/material.dart';

import '../../teams/data/team_repository.dart';
import '../../teams/domain/team_models.dart';
import '../data/tournament_repository.dart';
import '../domain/tournament_summary.dart';

class TournamentDetailScreen extends StatelessWidget {
  const TournamentDetailScreen({
    super.key,
    required this.tournament,
    required this.canManage,
  });

  final TournamentSummary tournament;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final tournamentRepository = TournamentRepository();
    final teamRepository = TeamRepository();

    return Scaffold(
      appBar: AppBar(title: Text(tournament.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _TournamentHeader(tournament: tournament),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Equipos inscritos',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (canManage)
                IconButton.filledTonal(
                  tooltip: 'Inscribir equipo',
                  onPressed: () => _showEnrollTeam(
                    context,
                    tournamentRepository: tournamentRepository,
                    teamRepository: teamRepository,
                  ),
                  icon: const Icon(Icons.group_add_outlined),
                ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<TournamentTeamEntry>>(
            stream: tournamentRepository.watchEnrolledTeams(tournament.id),
            builder: (context, snapshot) {
              final teams = snapshot.data ?? const [];

              if (teams.isEmpty) {
                return const _EmptyCard(
                  icon: Icons.groups_outlined,
                  message: 'Todavía no hay equipos inscritos.',
                );
              }

              return Column(
                children: teams
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.shield_outlined),
                            ),
                            title: Text(
                              entry.teamName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: const Text('Inscrito'),
                            trailing: canManage
                                ? IconButton(
                                    tooltip: 'Retirar del torneo',
                                    onPressed: () => _confirmRemoveTeam(
                                      context,
                                      repository: tournamentRepository,
                                      entry: entry,
                                    ),
                                    icon: const Icon(
                                      Icons.person_remove_alt_1_outlined,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Partidos',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (canManage)
                IconButton.filled(
                  tooltip: 'Programar partido',
                  onPressed: () => _showScheduleMatch(
                    context,
                    repository: tournamentRepository,
                  ),
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<ScheduledMatch>>(
            stream: tournamentRepository.watchMatches(tournament.id),
            builder: (context, snapshot) {
              final matches = snapshot.data ?? const [];

              if (matches.isEmpty) {
                return const _EmptyCard(
                  icon: Icons.calendar_month_outlined,
                  message: 'Todavía no hay partidos programados.',
                );
              }

              return StreamBuilder<List<TournamentTeamEntry>>(
                stream:
                    tournamentRepository.watchEnrolledTeams(tournament.id),
                builder: (context, teamSnapshot) {
                  final names = {
                    for (final team in teamSnapshot.data ?? const [])
                      team.teamId: team.teamName,
                  };

                  return Column(
                    children: matches
                        .map(
                          (match) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MatchCard(
                              match: match,
                              homeName:
                                  names[match.homeTeamId] ?? match.homeTeamId,
                              awayName:
                                  names[match.awayTeamId] ?? match.awayTeamId,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEnrollTeam(
    BuildContext context, {
    required TournamentRepository tournamentRepository,
    required TeamRepository teamRepository,
  }) async {
    final allTeams = await teamRepository.watchAllTeams().first;

    if (!context.mounted) return;

    if (allTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero debe existir al menos un equipo.'),
        ),
      );
      return;
    }

    TeamSummary selected = allTeams.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Inscribir equipo'),
          content: DropdownButtonFormField<TeamSummary>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Equipo'),
            items: allTeams
                .map(
                  (team) => DropdownMenuItem(
                    value: team,
                    child: Text(team.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await tournamentRepository.enrollTeam(
                    tournamentId: tournament.id,
                    team: selected,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo inscribir: $error')),
                  );
                }
              },
              child: const Text('Inscribir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveTeam(
    BuildContext context, {
    required TournamentRepository repository,
    required TournamentTeamEntry entry,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Retirar del torneo'),
            content: Text(
              '¿Retirar a ${entry.teamName} de este torneo? Esto no elimina el equipo ni las cuentas de sus jugadores.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Retirar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await repository.removeTeam(
        tournamentId: tournament.id,
        teamId: entry.teamId,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo retirar: $error')),
      );
    }
  }

  Future<void> _showScheduleMatch(
    BuildContext context, {
    required TournamentRepository repository,
  }) async {
    final enrolled = await repository.watchEnrolledTeams(tournament.id).first;

    if (!context.mounted) return;

    if (enrolled.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Necesitas al menos dos equipos inscritos para programar un partido.',
          ),
        ),
      );
      return;
    }

    var homeTeamId = enrolled.first.teamId;
    var awayTeamId = enrolled[1].teamId;
    var date = DateTime.now().add(const Duration(days: 1));
    var time = const TimeOfDay(hour: 18, minute: 0);

    final venue = TextEditingController();
    final field = TextEditingController();
    final zone = TextEditingController();
    final referee = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Programar partido'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: homeTeamId,
                  decoration: const InputDecoration(labelText: 'Local'),
                  items: enrolled
                      .map(
                        (team) => DropdownMenuItem(
                          value: team.teamId,
                          child: Text(team.teamName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => homeTeamId = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: awayTeamId,
                  decoration: const InputDecoration(labelText: 'Visitante'),
                  items: enrolled
                      .map(
                        (team) => DropdownMenuItem(
                          value: team.teamId,
                          child: Text(team.teamName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => awayTeamId = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: venue,
                  decoration: const InputDecoration(
                    labelText: 'Sede / complejo',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: field,
                  decoration: const InputDecoration(labelText: 'Cancha'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: zone,
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: referee,
                  decoration: const InputDecoration(labelText: 'Árbitro'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    '${date.day.toString().padLeft(2, '0')}/'
                    '${date.month.toString().padLeft(2, '0')}/${date.year}',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 730)),
                        initialDate: date,
                      );
                      if (picked != null) setState(() => date = picked);
                    },
                    child: const Text('Cambiar'),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(time.format(dialogContext)),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: time,
                      );
                      if (picked != null) setState(() => time = picked);
                    },
                    child: const Text('Cambiar'),
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
                final kickoff = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );

                try {
                  await repository.createMatch(
                    tournamentId: tournament.id,
                    homeTeamId: homeTeamId,
                    awayTeamId: awayTeamId,
                    venue: venue.text,
                    field: field.text,
                    zone: zone.text,
                    referee: referee.text,
                    kickoff: kickoff,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo programar: $error')),
                  );
                }
              },
              child: const Text('Programar'),
            ),
          ],
        ),
      ),
    );

    venue.dispose();
    field.dispose();
    zone.dispose();
    referee.dispose();
  }
}

class _TournamentHeader extends StatelessWidget {
  const _TournamentHeader({required this.tournament});

  final TournamentSummary tournament;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            color: colors.onPrimary,
            size: 40,
          ),
          const SizedBox(height: 14),
          Text(
            tournament.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (tournament.category.isNotEmpty) tournament.category,
              if (tournament.city.isNotEmpty) tournament.city,
            ].join(' · '),
            style: TextStyle(
              color: colors.onPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.homeName,
    required this.awayName,
  });

  final ScheduledMatch match;
  final String homeName;
  final String awayName;

  @override
  Widget build(BuildContext context) {
    final kickoff = match.kickoff;
    final dateLabel = kickoff == null
        ? 'Fecha pendiente'
        : '${kickoff.day.toString().padLeft(2, '0')}/'
            '${kickoff.month.toString().padLeft(2, '0')}/${kickoff.year} '
            '${kickoff.hour.toString().padLeft(2, '0')}:'
            '${kickoff.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$homeName  vs  $awayName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 12),
            _MatchInfo(icon: Icons.schedule_outlined, text: dateLabel),
            _MatchInfo(
              icon: Icons.stadium_outlined,
              text: [
                match.venue,
                match.field,
              ].where((value) => value.isNotEmpty).join(' · '),
            ),
            if (match.zone.isNotEmpty)
              _MatchInfo(icon: Icons.map_outlined, text: match.zone),
            if (match.referee.isNotEmpty)
              _MatchInfo(
                icon: Icons.sports_outlined,
                text: 'Árbitro: ${match.referee}',
              ),
          ],
        ),
      ),
    );
  }
}

class _MatchInfo extends StatelessWidget {
  const _MatchInfo({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
