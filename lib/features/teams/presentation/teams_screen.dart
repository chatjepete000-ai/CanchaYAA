import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/team_repository.dart';
import '../domain/team_models.dart';
import 'player_join_screen.dart';
import 'team_lineup_screen.dart';
import 'team_manager_screen.dart';
import 'widgets/team_match_panel.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({
    super.key,
    this.onOpenTournaments,
  });

  /// Cambia a la pestaña Torneos de la barra inferior.
  final VoidCallback? onOpenTournaments;

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  late final TeamRepository _repository;

  Future<void>? _syncFuture;

  @override
  void initState() {
    super.initState();

    if (Firebase.apps.isNotEmpty) {
      _repository = TeamRepository();

      _syncFuture =
          _repository.syncCurrentManagerAssignments();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const _TeamsEmptyState();
    }

    return FutureBuilder<void>(
      future: _syncFuture,
      builder: (
        context,
        syncSnapshot,
      ) {
        if (syncSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (syncSnapshot.hasError) {
          return _SyncErrorState(
            error: syncSnapshot.error,
            onRetry: _retrySync,
          );
        }

        return _TeamsStreams(
          repository: _repository,
          onOpenTournaments:
              widget.onOpenTournaments,
        );
      },
    );
  }

  void _retrySync() {
    setState(() {
      _syncFuture =
          _repository.syncCurrentManagerAssignments();
    });
  }
}

// =============================================================
// STREAMS PRINCIPALES
// =============================================================

class _TeamsStreams extends StatelessWidget {
  const _TeamsStreams({
    required this.repository,
    this.onOpenTournaments,
  });

  final TeamRepository repository;

  final VoidCallback? onOpenTournaments;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TeamAssignment>>(
      stream:
          repository.watchActiveAssignmentsForCurrentUser(),
      builder: (
        context,
        assignmentSnapshot,
      ) {
        if (assignmentSnapshot.connectionState ==
                ConnectionState.waiting &&
            !assignmentSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (assignmentSnapshot.hasError) {
          return _TeamsError(
            message:
                'No se pudieron cargar tus asignaciones.\n'
                '${assignmentSnapshot.error}',
          );
        }

        final assignments =
            assignmentSnapshot.data ??
                const <TeamAssignment>[];

        final managerAssignments =
            assignments
                .where(
                  (assignment) =>
                      assignment.role ==
                      TeamAssignmentRole.teamManager,
                )
                .toList();

        final playerAssignments =
            assignments
                .where(
                  (assignment) =>
                      assignment.role ==
                      TeamAssignmentRole.player,
                )
                .toList();

        return StreamBuilder<
            List<TeamManagerInvitation>>(
          stream: repository
              .watchPendingManagerInvitationsForCurrentUser(),
          builder: (
            context,
            invitationSnapshot,
          ) {
            if (invitationSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !invitationSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (invitationSnapshot.hasError) {
              return _TeamsError(
                message:
                    'No se pudieron cargar tus invitaciones.\n'
                    '${invitationSnapshot.error}',
              );
            }

            final invitations =
                invitationSnapshot.data ??
                    const <TeamManagerInvitation>[];

            return _TeamsContent(
              managerAssignments:
                  managerAssignments,
              playerAssignments:
                  playerAssignments,
              invitations:
                  invitations,
              repository:
                  repository,
              onOpenTournaments:
                  onOpenTournaments,
            );
          },
        );
      },
    );
  }
}

// =============================================================
// CONTENIDO PRINCIPAL
// =============================================================
//
// Equipos es la experiencia personal del usuario:
// su equipo, su próximo partido, cómo llegar, su alineación
// y "Administrar equipo" si es encargado.
//
// El calendario general, los resultados y la tabla viven
// en la pestaña Torneos.
// =============================================================

class _TeamsContent extends StatelessWidget {
  const _TeamsContent({
    required this.managerAssignments,
    required this.playerAssignments,
    required this.invitations,
    required this.repository,
    this.onOpenTournaments,
  });

  final List<TeamAssignment> managerAssignments;

  final List<TeamAssignment> playerAssignments;

  final List<TeamManagerInvitation> invitations;

  final TeamRepository repository;

  final VoidCallback? onOpenTournaments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasTeam =
        playerAssignments.isNotEmpty ||
            managerAssignments.isNotEmpty;

    final sectionTitleStyle =
        theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w900,
    );

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32,
      ),
      children: [
        // =======================================================
        // ENCABEZADO
        // =======================================================

        Text(
          'Equipos',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          hasTeam
              ? 'Tu equipo, tu próximo partido y tu alineación.'
              : 'Únete a tu equipo con el código o QR del encargado.',
          style: theme.textTheme.bodyMedium,
        ),

        const SizedBox(height: 22),

        // =======================================================
        // INVITACIONES (solo si existen)
        // =======================================================

        if (invitations.isNotEmpty) ...[
          Text(
            'Invitaciones',
            style: sectionTitleStyle,
          ),

          const SizedBox(height: 12),

          ...invitations.map(
            (invitation) => Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: _ManagerInvitationCard(
                invitation: invitation,
                repository: repository,
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],

        // =======================================================
        // USUARIO SIN EQUIPO
        // =======================================================

        if (!hasTeam)
          NoTeamCard(
            onJoin: () => _openJoinScreen(context),
          ),

        // =======================================================
        // EQUIPOS COMO JUGADOR
        // =======================================================

        if (playerAssignments.isNotEmpty) ...[
          Text(
            'Mis equipos',
            style: sectionTitleStyle,
          ),

          const SizedBox(height: 12),

          ...playerAssignments.map(
            (assignment) => Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: _PlayerTeamCard(
                assignment: assignment,
                repository: repository,
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],

        // =======================================================
        // EQUIPOS COMO ENCARGADO
        // =======================================================

        if (managerAssignments.isNotEmpty) ...[
          Text(
            'Equipos que administras',
            style: sectionTitleStyle,
          ),

          const SizedBox(height: 12),

          ...managerAssignments.map(
            (assignment) => Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: _ManagedTeamCard(
                assignment: assignment,
                repository: repository,
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],

        // =======================================================
        // ACCESO A TORNEOS + UNIRME A OTRO EQUIPO
        // =======================================================

        if (hasTeam) ...[
          if (onOpenTournaments != null) ...[
            TournamentsShortcutCard(
              onTap: onOpenTournaments!,
            ),

            const SizedBox(height: 14),
          ],

          Center(
            child: TextButton.icon(
              onPressed: () => _openJoinScreen(context),
              icon: const Icon(
                CupertinoIcons.person_add,
                size: 18,
              ),
              label: const Text(
                'Unirme a otro equipo',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================
// ABRIR "UNIRME A UN EQUIPO"
// =============================================================

Future<void> _openJoinScreen(
  BuildContext context,
) async {
  final joined = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => const PlayerJoinScreen(),
    ),
  );

  if (joined == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Te uniste al equipo correctamente.',
        ),
      ),
    );
  }
}

// =============================================================
// ESTADO SIN EQUIPO
// =============================================================

/// Lo único que ve un usuario que todavía no pertenece
/// a ningún equipo: el mensaje y el botón para unirse.
class NoTeamCard extends StatelessWidget {
  const NoTeamCard({
    super.key,
    required this.onJoin,
  });

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        28,
        20,
        22,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.7,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              CupertinoIcons.shield_fill,
              color: colors.primary,
              size: 34,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Aún no perteneces a ningún equipo',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Pídele al encargado de tu equipo el código '
            'o el QR de invitación.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onJoin,
              icon: const Icon(
                CupertinoIcons.person_add_solid,
              ),
              label: const Text(
                'Unirme a un equipo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// ACCESO A TORNEOS
// =============================================================

/// Lleva a la pestaña Torneos, donde están el calendario
/// general, los resultados y la tabla.
class TournamentsShortcutCard extends StatelessWidget {
  const TournamentsShortcutCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Material(
      color: colors.primaryContainer.withValues(
        alpha: 0.55,
      ),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.calendar,
                color: colors.primary,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendario, resultados y tabla',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      'Ir a Torneos',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// =============================================================
// TARJETA DE EQUIPO COMO JUGADOR
// =============================================================

class _PlayerTeamCard
    extends StatelessWidget {
  const _PlayerTeamCard({
    required this.assignment,
    required this.repository,
  });

  final TeamAssignment assignment;

  final TeamRepository repository;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return StreamBuilder<Team?>(
      stream:
          repository.watchTeamById(
        assignment.teamId,
      ),
      builder: (
        context,
        teamSnapshot,
      ) {
        final team =
            teamSnapshot.data;

        final loading =
            teamSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !teamSnapshot.hasData;

        final hasError =
            teamSnapshot.hasError;

        String title =
            'Equipo';

        String subtitle =
            'ID: ${assignment.teamId}';

        if (team != null) {
          title =
              team.name;

          subtitle =
              '${team.totalPlayers} jugadores';
        }

        return Card(
          elevation: 0,
          clipBehavior:
              Clip.antiAlias,
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              18,
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration:
                          BoxDecoration(
                        color: colors
                            .primaryContainer,
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),
                      child: team !=
                                  null &&
                              team.logoUrl
                                  .trim()
                                  .isNotEmpty
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                15,
                              ),
                              child:
                                  Image.network(
                                team.logoUrl,
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
                      width: 14,
                    ),

                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Text(
                            loading
                                ? 'Cargando información...'
                                : subtitle,
                          ),
                        ],
                      ),
                    ),

                    const Chip(
                      avatar:
                          Icon(
                        CupertinoIcons
                            .sportscourt_fill,
                        size: 16,
                      ),
                      label:
                          Text(
                        'Jugador',
                      ),
                    ),
                  ],
                ),

                if (hasError) ...[
                  const SizedBox(
                    height: 14,
                  ),

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors
                          .errorContainer,
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child:
                        Text(
                      'Perteneces al equipo, pero no se pudo cargar su información.',
                      style:
                          TextStyle(
                        color: colors
                            .onErrorContainer,
                      ),
                    ),
                  ),
                ],

                // =================================================
                // PRÓXIMO PARTIDO, CÓMO LLEGAR Y ALINEACIÓN
                // =================================================

                if (team != null) ...[
                  TeamMatchPanel(
                    teamId:
                        team.id,
                    tournamentId:
                        team.tournamentId,
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // F04: los jugadores consultan la alineación;
                  // solo el encargado la modifica.
                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          () {
                        Navigator.of(
                          context,
                        ).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) =>
                                    TeamLineupScreen(
                              team: team,
                              canEdit: false,
                            ),
                          ),
                        );
                      },
                      icon:
                          const Icon(
                        CupertinoIcons
                            .sportscourt,
                      ),
                      label:
                          const Text(
                        'Ver alineación',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================
// TARJETA DE EQUIPO COMO ENCARGADO
// =============================================================

class _ManagedTeamCard
    extends StatelessWidget {
  const _ManagedTeamCard({
    required this.assignment,
    required this.repository,
  });

  final TeamAssignment assignment;

  final TeamRepository repository;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return StreamBuilder<Team?>(
      stream:
          repository.watchTeamById(
        assignment.teamId,
      ),
      builder: (
        context,
        teamSnapshot,
      ) {
        final team =
            teamSnapshot.data;

        final loading =
            teamSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !teamSnapshot.hasData;

        final hasError =
            teamSnapshot.hasError;

        String title =
            'Equipo asignado';

        String subtitle =
            'ID: ${assignment.teamId}';

        if (team != null) {
          title =
              team.name;

          subtitle =
              '${team.totalPlayers} jugadores';
        }

        return Card(
          elevation: 0,
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              18,
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration:
                          BoxDecoration(
                        color: colors
                            .primaryContainer,
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: team !=
                                  null &&
                              team.logoUrl
                                  .trim()
                                  .isNotEmpty
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                              child:
                                  Image.network(
                                team.logoUrl,
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
                      width: 14,
                    ),

                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
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
                            height: 3,
                          ),

                          Text(
                            loading
                                ? 'Cargando información...'
                                : subtitle,
                          ),
                        ],
                      ),
                    ),

                    Chip(
                      label:
                          Text(
                        assignment
                            .role
                            .label,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                if (hasError) ...[
                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors
                          .errorContainer,
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child:
                        Text(
                      'Tu asignación está activa, pero todavía no se pudo cargar la información del equipo.',
                      style:
                          TextStyle(
                        color: colors
                            .onErrorContainer,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),
                ],

                // =================================================
                // PRÓXIMO PARTIDO Y CÓMO LLEGAR
                // =================================================

                if (team != null) ...[
                  TeamMatchPanel(
                    teamId:
                        team.id,
                    tournamentId:
                        team.tournamentId,
                  ),

                  const SizedBox(
                    height: 16,
                  ),
                ],

                const Text(
                  'Como encargado activo puedes administrar la plantilla, '
                  'invitaciones, escudo y uniforme de este equipo.',
                ),

                const SizedBox(
                  height: 16,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton.icon(
                    onPressed:
                        team == null
                            ? null
                            : () {
                                Navigator.of(
                                  context,
                                ).push(
                                  MaterialPageRoute<void>(
                                    builder:
                                        (
                                      context,
                                    ) =>
                                            TeamManagerScreen(
                                      team:
                                          team,
                                    ),
                                  ),
                                );
                              },
                    icon:
                        const Icon(
                      CupertinoIcons
                          .gear_alt_fill,
                    ),
                    label:
                        const Text(
                      'Administrar equipo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================
// INVITACIÓN A ENCARGADO
// =============================================================

class _ManagerInvitationCard
    extends StatefulWidget {
  const _ManagerInvitationCard({
    required this.invitation,
    required this.repository,
  });

  final TeamManagerInvitation invitation;

  final TeamRepository repository;

  @override
  State<_ManagerInvitationCard>
      createState() =>
          _ManagerInvitationCardState();
}

class _ManagerInvitationCardState
    extends State<_ManagerInvitationCard> {
  bool _processing = false;

  Future<void> _accept() async {
    setState(() {
      _processing = true;
    });

    try {
      await widget.repository
          .acceptManagerInvitation(
        widget.invitation,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Invitación aceptada. Ahora eres encargado de este equipo.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            'No se pudo aceptar la invitación: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<void> _reject() async {
    setState(() {
      _processing = true;
    });

    try {
      await widget.repository
          .rejectManagerInvitation(
        widget.invitation,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Invitación rechazada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            'No se pudo rechazar la invitación: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Card(
      elevation: 0,
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
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
                  child:
                      Icon(
                    CupertinoIcons
                        .shield_fill,
                    color:
                        colors.primary,
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget
                                .invitation
                                .teamName
                                .isNotEmpty
                            ? widget
                                .invitation
                                .teamName
                            : 'Equipo',
                        style:
                            Theme.of(
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
                        height: 3,
                      ),

                      const Text(
                        'Invitación para ser encargado',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Un administrador de liga quiere asignarte como encargado '
              'de este equipo. Si aceptas, obtendrás permisos temporales '
              'para administrarlo.',
            ),

            const SizedBox(
              height: 18,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton(
                    onPressed:
                        _processing
                            ? null
                            : _reject,
                    child:
                        const Text(
                      'Rechazar',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      FilledButton(
                    onPressed:
                        _processing
                            ? null
                            : _accept,
                    child:
                        Text(
                      _processing
                          ? 'Procesando...'
                          : 'Aceptar',
                    ),
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

// =============================================================
// ERROR DE SINCRONIZACIÓN
// =============================================================

class _SyncErrorState
    extends StatelessWidget {
  const _SyncErrorState({
    required this.error,
    required this.onRetry,
  });

  final Object? error;

  final VoidCallback onRetry;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return ListView(
      padding:
          const EdgeInsets.all(
        20,
      ),
      children: [
        Text(
          'Equipos',
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

        const SizedBox(
          height: 20,
        ),

        Card(
          elevation: 0,
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              20,
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons
                      .exclamationmark_triangle,
                  color:
                      colors.error,
                  size: 34,
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  'No se pudo sincronizar tu equipo',
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
                  height: 8,
                ),

                const Text(
                  'Tu asignación sigue guardada. Intenta sincronizar nuevamente.',
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  '$error',
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .bodySmall,
                ),

                const SizedBox(
                  height: 16,
                ),

                FilledButton.icon(
                  onPressed:
                      onRetry,
                  icon:
                      const Icon(
                    CupertinoIcons
                        .refresh,
                  ),
                  label:
                      const Text(
                    'Reintentar',
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

// =============================================================
// FIREBASE NO DISPONIBLE
// =============================================================

class _TeamsEmptyState
    extends StatelessWidget {
  const _TeamsEmptyState();

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      padding:
          const EdgeInsets.all(
        20,
      ),
      children: [
        Text(
          'Equipos',
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

        const SizedBox(
          height: 20,
        ),

        const Card(
          child:
              Padding(
            padding:
                EdgeInsets.all(
              20,
            ),
            child:
                Text(
              'Firebase no está disponible en este entorno.',
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// ERROR GENERAL
// =============================================================

class _TeamsError
    extends StatelessWidget {
  const _TeamsError({
    required this.message,
  });

  final String message;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      padding:
          const EdgeInsets.all(
        20,
      ),
      children: [
        Text(
          'Equipos',
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

        const SizedBox(
          height: 20,
        ),

        Card(
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              20,
            ),
            child:
                Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons
                      .exclamationmark_triangle,
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
      ],
    );
  }
}