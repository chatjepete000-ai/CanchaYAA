import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../data/league_repository.dart';
import '../domain/league_models.dart';
import 'league_teams_screen.dart';

class LeagueAdminScreen extends StatelessWidget {
  const LeagueAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const _LeagueAdminEmptyState();
    }

    final repository = LeagueRepository();

    return StreamBuilder<List<League>>(
      stream: repository.watchManagedLeaguesForCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _LeagueAdminError(
            message:
                'No se pudieron cargar tus ligas.\n${snapshot.error}',
          );
        }

        final leagues = snapshot.data ?? const <League>[];

        if (leagues.isEmpty) {
          return const _NoManagedLeagues();
        }

        return _LeagueAdminContent(
          leagues: leagues,
          repository: repository,
        );
      },
    );
  }
}

class _LeagueAdminContent extends StatefulWidget {
  const _LeagueAdminContent({
    required this.leagues,
    required this.repository,
  });

  final List<League> leagues;
  final LeagueRepository repository;

  @override
  State<_LeagueAdminContent> createState() =>
      _LeagueAdminContentState();
}

class _LeagueAdminContentState extends State<_LeagueAdminContent> {
  late League _selectedLeague;

  @override
  void initState() {
    super.initState();
    _selectedLeague = widget.leagues.first;
  }

  @override
  void didUpdateWidget(
    covariant _LeagueAdminContent oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final stillExists = widget.leagues.any(
      (league) => league.id == _selectedLeague.id,
    );

    if (!stillExists && widget.leagues.isNotEmpty) {
      _selectedLeague = widget.leagues.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32,
      ),
      children: [
        Text(
          'Administración de liga',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Gestiona tus ligas, torneos y equipos asignados.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 22),

        if (widget.leagues.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedLeague.id,
            decoration: const InputDecoration(
              labelText: 'Liga activa',
              prefixIcon: Icon(
                Icons.emoji_events_outlined,
              ),
            ),
            items: widget.leagues
                .map(
                  (league) => DropdownMenuItem<String>(
                    value: league.id,
                    child: Text(
                      league.name,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }

              final league = widget.leagues.firstWhere(
                (item) => item.id == value,
              );

              setState(() {
                _selectedLeague = league;
              });
            },
          ),
          const SizedBox(height: 18),
        ],

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.workspace_premium_outlined,
                      color: colors.onPrimary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedLeague.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedLeague.organizationName.isNotEmpty
                              ? _selectedLeague.organizationName
                              : 'Organización sin definir',
                          style: TextStyle(
                            color: colors.onPrimary.withValues(
                              alpha: 0.88,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LeagueBadge(
                    icon: Icons.location_on_outlined,
                    label: _selectedLeague.city.isNotEmpty
                        ? _selectedLeague.city
                        : 'Ciudad sin definir',
                  ),
                  _LeagueBadge(
                    icon: Icons.circle_outlined,
                    label: _selectedLeague.status.label,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        Text(
          'Herramientas de administración',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),

        const SizedBox(height: 14),

        _AdminActionCard(
          icon: Icons.emoji_events_outlined,
          title: 'Torneos',
          subtitle:
              'Crea y administra los torneos de esta liga.',
          onTap: () {
            _showTournaments(
              context,
              _selectedLeague,
            );
          },
        ),

        const SizedBox(height: 10),

        _AdminActionCard(
          icon: Icons.groups_2_outlined,
          title: 'Equipos',
          subtitle:
              'Registra equipos, asígnalos a torneos y consulta su estado.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LeagueTeamsScreen(
                  league: _selectedLeague,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 10),

        _AdminActionCard(
          icon: Icons.manage_accounts_outlined,
          title: 'Encargados de equipo',
          subtitle:
              'Invita usuarios para administrar equipos durante esta liga.',
          onTap: () {
            _showComingSoon(
              context,
              'La gestión central de encargados se conectará después de crear equipos.',
            );
          },
        ),

        const SizedBox(height: 10),

        _AdminActionCard(
          icon: Icons.calendar_month_outlined,
          title: 'Calendario',
          subtitle:
              'Organiza jornadas, partidos, horarios y canchas.',
          onTap: () {
            _showComingSoon(
              context,
              'El calendario se conectará más adelante.',
            );
          },
        ),

        const SizedBox(height: 10),

        _AdminActionCard(
          icon: Icons.sports_outlined,
          title: 'Árbitros',
          subtitle:
              'Gestiona árbitros y asignaciones de partidos.',
          onTap: () {
            _showComingSoon(
              context,
              'La gestión de árbitros se agregará más adelante.',
            );
          },
        ),

        const SizedBox(height: 10),

        _AdminActionCard(
          icon: Icons.scoreboard_outlined,
          title: 'Resultados',
          subtitle:
              'Captura resultados y controla correcciones.',
          onTap: () {
            _showComingSoon(
              context,
              'Los resultados se conectarán después del calendario.',
            );
          },
        ),

        const SizedBox(height: 24),

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
                Icons.security_outlined,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tus permisos administrativos se limitan a las ligas que CanchaYA te haya asignado. No puedes convertir usuarios en administradores de plataforma ni suspender cuentas globales.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showTournaments(
    BuildContext context,
    League league,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LeagueTournamentsScreen(
          league: league,
          repository: widget.repository,
        ),
      ),
    );
  }

  static void _showComingSoon(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }
}

class _LeagueTournamentsScreen extends StatelessWidget {
  const _LeagueTournamentsScreen({
    required this.league,
    required this.repository,
  });

  final League league;
  final LeagueRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          league.name,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _CreateTournamentScreen(
                league: league,
                repository: repository,
              ),
            ),
          );
        },
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Crear torneo',
        ),
      ),
      body: StreamBuilder<List<Tournament>>(
        stream: repository.watchTournamentsForLeague(
          league.id,
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
                      size: 58,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Todavía no hay torneos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Usa el botón Crear torneo para registrar la primera competencia de esta liga.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount: tournaments.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final tournament = tournaments[index];

              return Card(
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons.emoji_events_outlined,
                    ),
                  ),
                  title: Text(
                    tournament.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    '${tournament.category} · ${tournament.format.label}\n${tournament.status.label}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CreateTournamentScreen extends StatefulWidget {
  const _CreateTournamentScreen({
    required this.league,
    required this.repository,
  });

  final League league;
  final LeagueRepository repository;

  @override
  State<_CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState
    extends State<_CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _cityController = TextEditingController();
  final _seasonController = TextEditingController();

  TournamentFormat _format =
      TournamentFormat.football7;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _cityController.text = widget.league.city;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _cityController.dispose();
    _seasonController.dispose();

    super.dispose();
  }

  Future<void> _createTournament() async {
    final valid =
        _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.createTournament(
        leagueId: widget.league.id,
        name: _nameController.text,
        category: _categoryController.text,
        city: _cityController.text,
        season: _seasonController.text,
        format: _format,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Torneo creado correctamente.',
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
            'No se pudo crear el torneo: $error',
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
          'Nuevo torneo',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.league.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Registra una nueva competencia para esta liga.',
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre del torneo',
                  prefixIcon: Icon(
                    Icons.emoji_events_outlined,
                  ),
                ),
                validator: (value) {
                  final clean = value?.trim() ?? '';

                  if (clean.length < 3) {
                    return 'Escribe un nombre válido.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _categoryController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Ej. Varonil, Femenil, Libre',
                  prefixIcon: Icon(
                    Icons.category_outlined,
                  ),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'Escribe una categoría.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _seasonController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Temporada / edición',
                  hintText: 'Ej. Apertura 2027',
                  prefixIcon: Icon(
                    Icons.calendar_today_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _cityController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Ciudad',
                  prefixIcon: Icon(
                    Icons.location_city_outlined,
                  ),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return 'Escribe una ciudad.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              DropdownButtonFormField<TournamentFormat>(
                initialValue: _format,
                decoration: const InputDecoration(
                  labelText: 'Modalidad',
                  prefixIcon: Icon(
                    Icons.sports_soccer_outlined,
                  ),
                ),
                items: TournamentFormat.values.map(
                  (format) {
                    return DropdownMenuItem<TournamentFormat>(
                      value: format,
                      child: Text(
                        format.label,
                      ),
                    );
                  },
                ).toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _format = value;
                        });
                      },
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed:
                    _saving ? null : _createTournament,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.add_circle_outline,
                      ),
                label: Text(
                  _saving
                      ? 'Creando...'
                      : 'Crear torneo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeagueBadge extends StatelessWidget {
  const _LeagueBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: colors.onPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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

class _NoManagedLeagues extends StatelessWidget {
  const _NoManagedLeagues();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Administración',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 54,
                ),
                SizedBox(height: 14),
                Text(
                  'Sin ligas asignadas',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tu cuenta no administra ninguna liga actualmente.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LeagueAdminEmptyState extends StatelessWidget {
  const _LeagueAdminEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Firebase no está disponible en este entorno.',
      ),
    );
  }
}

class _LeagueAdminError extends StatelessWidget {
  const _LeagueAdminError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Administración',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              message,
            ),
          ),
        ),
      ],
    );
  }
}