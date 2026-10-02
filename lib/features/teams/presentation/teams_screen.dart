import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/access_policy.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../data/team_repository.dart';
import '../domain/team_models.dart';
import 'team_invite_qr_screen.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const _TeamsMessage(
        title: 'Equipos',
        message: 'Inicia la app con Firebase para consultar tus equipos.',
      );
    }

    final profileRepository = ProfileRepository();
    final teamRepository = TeamRepository();

    return StreamBuilder<UserProfile?>(
      stream: profileRepository.watchCurrentProfile(),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        if (profile == null) {
          return const _TeamsMessage(
            title: 'Equipos',
            message:
                'Inicia sesión para consultar los equipos a los que perteneces.',
          );
        }

        final canCreate = AccessPolicy.canCreateTeam(
          role: profile.role,
          adminScope: profile.adminScope,
        );

        return StreamBuilder<List<TeamSummary>>(
          stream: teamRepository.watchMyTeams(),
          builder: (context, teamSnapshot) {
            final teams = teamSnapshot.data ?? const [];

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
                            'Equipos',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Tus equipos y plantillas en un solo lugar.',
                          ),
                        ],
                      ),
                    ),
                    if (canCreate)
                      IconButton.filled(
                        tooltip: 'Crear equipo',
                        onPressed: () => _createTeam(context, teamRepository),
                        icon: const Icon(Icons.add),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (teams.isEmpty)
                  _EmptyTeams(canCreate: canCreate)
                else
                  ...teams.map(
                    (team) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TeamCard(
                        team: team,
                        canManage: team.captainUid == profile.uid ||
                            profile.adminScope.name == 'platform',
                        onInvite: () =>
                            _invitePlayer(context, teamRepository, team),
                        onQrInvite: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TeamInviteQrScreen(team: team),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<void> _createTeam(
    BuildContext context,
    TeamRepository repository,
  ) async {
    final name = TextEditingController();
    final category = TextEditingController();
    final city = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear equipo'),
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
              if (name.text.trim().length < 2) return;
              try {
                await repository.createTeam(
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
  }

  static Future<void> _invitePlayer(
    BuildContext context,
    TeamRepository repository,
    TeamSummary team,
  ) async {
    final email = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Invitar a ${team.name}'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo del jugador',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                await repository.invitePlayer(team: team, email: email.text);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invitación enviada al perfil del jugador.'),
                  ),
                );
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se pudo invitar: $error')),
                );
              }
            },
            icon: const Icon(Icons.send_outlined),
            label: const Text('Enviar invitación'),
          ),
        ],
      ),
    );

    email.dispose();
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.canManage,
    required this.onInvite,
    required this.onQrInvite,
  });

  final TeamSummary team;
  final bool canManage;
  final VoidCallback onInvite;
  final VoidCallback onQrInvite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(Icons.shield_outlined, color: colors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (team.category.isNotEmpty) team.category,
                          if (team.city.isNotEmpty) team.city,
                        ].join(' · '),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.group_outlined, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Text('${team.memberIds.length} jugadores'),
                const Spacer(),
                if (canManage)
                  PopupMenuButton<String>(
                    tooltip: 'Invitar jugadores',
                    onSelected: (value) {
                      if (value == 'email') onInvite();
                      if (value == 'qr') onQrInvite();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'email',
                        child: ListTile(
                          leading: Icon(Icons.email_outlined),
                          title: Text('Invitar por correo'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'qr',
                        child: ListTile(
                          leading: Icon(Icons.qr_code_2),
                          title: Text('Generar QR / código'),
                        ),
                      ),
                    ],
                    child: const Chip(
                      avatar: Icon(Icons.person_add_alt_1, size: 18),
                      label: Text('Invitar'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTeams extends StatelessWidget {
  const _EmptyTeams({required this.canCreate});

  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.groups_outlined, size: 56),
            const SizedBox(height: 14),
            Text(
              canCreate ? 'Todavía no has creado un equipo' : 'Sin equipo todavía',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              canCreate
                  ? 'Como encargado puedes crear un equipo y después invitar jugadores por correo.'
                  : 'No necesitas buscar ni solicitar un equipo. Cuando un encargado te invite, la invitación aparecerá en tu Perfil.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamsMessage extends StatelessWidget {
  const _TeamsMessage({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          title,
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
