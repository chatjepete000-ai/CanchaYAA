import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../teams/data/team_repository.dart';
import '../../teams/domain/team_models.dart';
import '../data/league_repository.dart';
import '../domain/league_models.dart';
import 'invite_team_manager_screen.dart';

class LeagueTeamsScreen extends StatelessWidget {
  const LeagueTeamsScreen({
    super.key,
    required this.league,
  });

  final League league;

  @override
  Widget build(BuildContext context) {
    final teamRepository = TeamRepository();
    final leagueRepository = LeagueRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _CreateTeamScreen(
                league: league,
                teamRepository: teamRepository,
                leagueRepository: leagueRepository,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Crear equipo'),
      ),
      body: _LeagueTeamsContent(
        league: league,
      ),
    );
  }
}

class _LeagueTeamsContent extends StatelessWidget {
  const _LeagueTeamsContent({
    required this.league,
  });

  final League league;

  Stream<List<Team>> _watchTeams() {
    return FirebaseFirestore.instance
        .collection('teams')
        .where(
          'leagueId',
          isEqualTo: league.id,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => Team.fromMap(
                  document.id,
                  document.data(),
                ),
              )
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return StreamBuilder<List<Team>>(
      stream: _watchTeams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _TeamsError(
            message:
                'No se pudieron cargar los equipos.\n${snapshot.error}',
          );
        }

        final teams = snapshot.data ?? const <Team>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            100,
          ),
          children: [
            Text(
              league.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Administra los equipos registrados en esta liga.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _SummaryBox(
                    icon: Icons.groups_2_outlined,
                    value: '${teams.length}',
                    label: 'Equipos',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryBox(
                    icon: Icons.manage_accounts_outlined,
                    value:
                        '${teams.where((team) => team.hasManager).length}',
                    label: 'Con encargado',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            Text(
              'Equipos registrados',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),

            const SizedBox(height: 12),

            if (teams.isEmpty)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.groups_2_outlined,
                        size: 56,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Todavía no hay equipos',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Crea el primer equipo y después podrás asignarle un encargado mediante invitación.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...teams.map(
                (team) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: _TeamCard(
                    team: team,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Después de crear un equipo podrás invitar a un usuario para que sea su encargado temporal durante el torneo.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
  });

  final Team team;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _TeamAdminDetailScreen(
                team: team,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: team.logoUrl.isEmpty
                    ? Icon(
                        Icons.shield_outlined,
                        color: colors.primary,
                        size: 30,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          team.logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return Icon(
                              Icons.shield_outlined,
                              color: colors.primary,
                              size: 30,
                            );
                          },
                        ),
                      ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      team.hasManager
                          ? 'Encargado asignado'
                          : 'Sin encargado',
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${team.totalPlayers} jugadores',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamAdminDetailScreen extends StatelessWidget {
  const _TeamAdminDetailScreen({
    required this.team,
  });

  final Team team;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          team.name,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.primary.withValues(
                    alpha: 0.78,
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: colors.onPrimary.withValues(
                    alpha: 0.15,
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 44,
                    color: colors.onPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  team.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  team.status.label,
                  style: TextStyle(
                    color: colors.onPrimary.withValues(
                      alpha: 0.9,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Administración',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),

          const SizedBox(height: 12),

          _TeamOption(
            icon: Icons.manage_accounts_outlined,
            title: 'Encargado del equipo',
            subtitle: team.hasManager
                ? 'Consulta o cambia al encargado actual.'
                : 'Invita a un usuario para administrar este equipo.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => InviteTeamManagerScreen(
                    team: team,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          _TeamOption(
            icon: Icons.groups_outlined,
            title: 'Plantilla',
            subtitle:
                '${team.totalPlayers} jugadores registrados',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'La plantilla será administrada por el encargado del equipo.',
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          _TeamOption(
            icon: Icons.image_outlined,
            title: 'Escudo y uniforme',
            subtitle:
                'Información visual que podrá configurar el encargado.',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Esta configuración estará disponible para el encargado.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CreateTeamScreen extends StatefulWidget {
  const _CreateTeamScreen({
    required this.league,
    required this.teamRepository,
    required this.leagueRepository,
  });

  final League league;
  final TeamRepository teamRepository;
  final LeagueRepository leagueRepository;

  @override
  State<_CreateTeamScreen> createState() =>
      _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<_CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  String? _selectedTournamentId;

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();

    super.dispose();
  }

  Future<void> _createTeam() async {
    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    if (_selectedTournamentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona un torneo.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.teamRepository.createTeam(
        name: _nameController.text,
        leagueId: widget.league.id,
        tournamentId: _selectedTournamentId!,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Equipo creado correctamente.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo crear el equipo: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nuevo equipo',
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Tournament>>(
          stream: widget.leagueRepository
              .watchTournamentsForLeague(
            widget.league.id,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudieron cargar los torneos.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final tournaments =
                snapshot.data ?? const <Tournament>[];

            if (tournaments.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 56,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Primero crea un torneo',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Los equipos deben quedar asociados a un torneo.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    widget.league.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Registra un equipo participante.',
                  ),

                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del equipo',
                      prefixIcon: Icon(
                        Icons.shield_outlined,
                      ),
                    ),
                    validator: (value) {
                      final cleanValue =
                          value?.trim() ?? '';

                      if (cleanValue.length < 2) {
                        return 'Escribe un nombre válido.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedTournamentId,
                    decoration: const InputDecoration(
                      labelText: 'Torneo',
                      prefixIcon: Icon(
                        Icons.emoji_events_outlined,
                      ),
                    ),
                    items: tournaments
                        .map(
                          (tournament) =>
                              DropdownMenuItem<String>(
                            value: tournament.id,
                            child: Text(
                              tournament.name,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedTournamentId = value;
                            });
                          },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecciona un torneo.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed:
                        _saving ? null : _createTeam,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.add_circle_outline,
                          ),
                    label: Text(
                      _saving
                          ? 'Creando...'
                          : 'Crear equipo',
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Después de crear el equipo podrás invitar a una persona para que sea su encargado durante este torneo.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: colors.primary,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TeamOption extends StatelessWidget {
  const _TeamOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: colors.primary,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
      ),
    );
  }
}

class _TeamsError extends StatelessWidget {
  const _TeamsError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 30),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}