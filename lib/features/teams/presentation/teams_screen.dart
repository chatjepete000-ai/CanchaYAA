import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/team_repository.dart';
import '../domain/team_models.dart';
import 'player_join_screen.dart';
import 'team_manager_screen.dart';
import 'widgets/team_match_panel.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({
    super.key,
  });

  @override
  State<TeamsScreen> createState() =>
      _TeamsScreenState();
}

class _TeamsScreenState
    extends State<TeamsScreen> {
  late final TeamRepository
      _repository;

  Future<void>? _syncFuture;

  @override
  void initState() {
    super.initState();

    if (Firebase.apps.isNotEmpty) {
      _repository =
          TeamRepository();

      _syncFuture =
          _repository
              .syncCurrentManagerAssignments();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (Firebase.apps.isEmpty) {
      return const _TeamsEmptyState();
    }

    return FutureBuilder<void>(
      future: _syncFuture,
      builder: (
        context,
        syncSnapshot,
      ) {
        if (syncSnapshot
                .connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (syncSnapshot.hasError) {
          return _SyncErrorState(
            error:
                syncSnapshot.error,
            onRetry:
                _retrySync,
          );
        }

        return _TeamsStreams(
          repository:
              _repository,
        );
      },
    );
  }

  void _retrySync() {
    setState(() {
      _syncFuture =
          _repository
              .syncCurrentManagerAssignments();
    });
  }
}

// =============================================================
// STREAMS PRINCIPALES
// =============================================================

class _TeamsStreams
    extends StatelessWidget {
  const _TeamsStreams({
    required this.repository,
  });

  final TeamRepository repository;

  @override
  Widget build(
    BuildContext context,
  ) {
    return StreamBuilder<
        List<TeamAssignment>>(
      stream: repository
          .watchActiveAssignmentsForCurrentUser(),
      builder: (
        context,
        assignmentSnapshot,
      ) {
        if (assignmentSnapshot
                    .connectionState ==
                ConnectionState.waiting &&
            !assignmentSnapshot
                .hasData) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (assignmentSnapshot
            .hasError) {
          return _TeamsError(
            message:
                'No se pudieron cargar tus asignaciones.\n'
                '${assignmentSnapshot.error}',
          );
        }

        final assignments =
            assignmentSnapshot.data ??
                const <
                    TeamAssignment>[];

        final managerAssignments =
            assignments
                .where(
                  (
                    assignment,
                  ) =>
                      assignment.role ==
                      TeamAssignmentRole
                          .teamManager,
                )
                .toList();

        final playerAssignments =
            assignments
                .where(
                  (
                    assignment,
                  ) =>
                      assignment.role ==
                      TeamAssignmentRole
                          .player,
                )
                .toList();

        return StreamBuilder<
            List<
                TeamManagerInvitation>>(
          stream: repository
              .watchPendingManagerInvitationsForCurrentUser(),
          builder: (
            context,
            invitationSnapshot,
          ) {
            if (invitationSnapshot
                        .connectionState ==
                    ConnectionState
                        .waiting &&
                !invitationSnapshot
                    .hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            if (invitationSnapshot
                .hasError) {
              return _TeamsError(
                message:
                    'No se pudieron cargar tus invitaciones.\n'
                    '${invitationSnapshot.error}',
              );
            }

            final invitations =
                invitationSnapshot
                        .data ??
                    const <
                        TeamManagerInvitation>[];

            return _TeamsContent(
              managerAssignments:
                  managerAssignments,
              playerAssignments:
                  playerAssignments,
              invitations:
                  invitations,
              repository:
                  repository,
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

class _TeamsContent
    extends StatelessWidget {
  const _TeamsContent({
    required this.managerAssignments,
    required this.playerAssignments,
    required this.invitations,
    required this.repository,
  });

  final List<TeamAssignment>
      managerAssignments;

  final List<TeamAssignment>
      playerAssignments;

  final List<TeamManagerInvitation>
      invitations;

  final TeamRepository repository;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return ListView(
      physics:
          const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32,
      ),
      children: [
        Text(
          'Equipos',
          style: theme
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight:
                    FontWeight.w900,
              ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          'Consulta tus equipos, próximos partidos, invitaciones y accesos.',
          style:
              theme.textTheme.bodyMedium,
        ),

        const SizedBox(
          height: 22,
        ),

        // =====================================================
        // UNIRSE A UN EQUIPO
        // =====================================================

        Container(
          padding:
              const EdgeInsets.all(
            18,
          ),
          decoration:
              BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                colors.primary,
                colors.primary
                    .withValues(
                  alpha:
                      0.78,
                ),
              ],
            ),
            borderRadius:
                BorderRadius.circular(
              22,
            ),
          ),
          child: Row(
            children: [
              Container(
                width:
                    54,
                height:
                    54,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha:
                        0.16,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    16,
                  ),
                ),
                child:
                    const Icon(
                  CupertinoIcons
                      .person_add_solid,
                  color:
                      Colors.white,
                  size:
                      26,
                ),
              ),

              const SizedBox(
                width:
                    14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Unirme a un equipo',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      'Usa un código de invitación del encargado.',
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: Colors
                                .white
                                .withValues(
                              alpha:
                                  0.88,
                            ),
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width:
                    8,
              ),

              Material(
                color:
                    Colors.transparent,
                child:
                    InkWell(
                  customBorder:
                      const CircleBorder(),
                  onTap:
                      () async {
                    final joined =
                        await Navigator
                            .of(
                      context,
                    ).push<bool>(
                      MaterialPageRoute<
                          bool>(
                        builder:
                            (_) =>
                                const PlayerJoinScreen(),
                      ),
                    );

                    if (joined ==
                            true &&
                        context
                            .mounted) {
                      ScaffoldMessenger
                              .of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content:
                              Text(
                            'Te uniste al equipo correctamente.',
                          ),
                        ),
                      );
                    }
                  },
                  child:
                      Container(
                    width:
                        42,
                    height:
                        42,
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .white
                          .withValues(
                        alpha:
                            0.16,
                      ),
                      shape:
                          BoxShape
                              .circle,
                    ),
                    child:
                        const Icon(
                      CupertinoIcons
                          .chevron_right,
                      color:
                          Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height:
              26,
        ),

        // =====================================================
        // EQUIPOS COMO JUGADOR
        // =====================================================

        if (playerAssignments
            .isNotEmpty) ...[
          Text(
            'Mis equipos',
            style: theme
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight:
                      FontWeight
                          .w900,
                ),
          ),

          const SizedBox(
            height:
                12,
          ),

          ...playerAssignments.map(
            (
              assignment,
            ) =>
                Padding(
              padding:
                  const EdgeInsets.only(
                bottom:
                    12,
              ),
              child:
                  _PlayerTeamCard(
                assignment:
                    assignment,
                repository:
                    repository,
              ),
            ),
          ),

          const SizedBox(
            height:
                16,
          ),
        ],

        // =====================================================
        // EQUIPOS COMO ENCARGADO
        // =====================================================

        if (managerAssignments
            .isNotEmpty) ...[
          Text(
            'Equipos que administras',
            style: theme
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight:
                      FontWeight
                          .w900,
                ),
          ),

          const SizedBox(
            height:
                12,
          ),

          ...managerAssignments.map(
            (
              assignment,
            ) =>
                Padding(
              padding:
                  const EdgeInsets.only(
                bottom:
                    12,
              ),
              child:
                  _ManagedTeamCard(
                assignment:
                    assignment,
                repository:
                    repository,
              ),
            ),
          ),

          const SizedBox(
            height:
                20,
          ),
        ],

        // =====================================================
        // INVITACIONES
        // =====================================================

        Text(
          'Invitaciones',
          style: theme
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w900,
              ),
        ),

        const SizedBox(
          height:
              12,
        ),

        if (invitations.isEmpty)
          Card(
            elevation:
                0,
            child:
                Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child:
                  Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Container(
                    width:
                        48,
                    height:
                        48,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primaryContainer,
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child:
                        Icon(
                      CupertinoIcons
                          .envelope,
                      color:
                          colors.primary,
                    ),
                  ),

                  const SizedBox(
                    width:
                        14,
                  ),

                  const Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Sin invitaciones pendientes',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),

                        SizedBox(
                          height:
                              5,
                        ),

                        Text(
                          'Cuando un administrador de liga te invite a ser encargado de un equipo, aparecerá aquí.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...invitations.map(
            (
              invitation,
            ) =>
                Padding(
              padding:
                  const EdgeInsets.only(
                bottom:
                    12,
              ),
              child:
                  _ManagerInvitationCard(
                invitation:
                    invitation,
                repository:
                    repository,
              ),
            ),
          ),

        const SizedBox(
          height:
              24,
        ),

        if (managerAssignments
                .isEmpty &&
            playerAssignments
                .isEmpty)
          Container(
            padding:
                const EdgeInsets.all(
              18,
            ),
            decoration:
                BoxDecoration(
              color: colors
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius
                      .circular(
                18,
              ),
            ),
            child:
                Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Icon(
                  CupertinoIcons
                      .info_circle,
                  color:
                      colors.primary,
                ),

                const SizedBox(
                  width:
                      12,
                ),

                const Expanded(
                  child:
                      Text(
                    'Todavía no perteneces a ningún equipo. '
                    'Puedes ingresar mediante un código de invitación.',
                  ),
                ),
              ],
            ),
          ),
      ],
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

  final TeamAssignment
      assignment;

  final TeamRepository
      repository;

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
            teamSnapshot
                        .connectionState ==
                    ConnectionState
                        .waiting &&
                !teamSnapshot
                    .hasData;

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
          elevation:
              0,
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
                  CrossAxisAlignment
                      .start,
              children: [
                Row(
                  children: [
                    Container(
                      width:
                          54,
                      height:
                          54,
                      decoration:
                          BoxDecoration(
                        color: colors
                            .primaryContainer,
                        borderRadius:
                            BorderRadius
                                .circular(
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
                                  BorderRadius
                                      .circular(
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
                      width:
                          14,
                    ),

                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            title,
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                          ),

                          const SizedBox(
                            height:
                                3,
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
                        size:
                            16,
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
                    height:
                        14,
                  ),

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets
                            .all(
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors
                          .errorContainer,
                      borderRadius:
                          BorderRadius
                              .circular(
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
                // PARTIDO DEL EQUIPO DEL JUGADOR
                // =================================================

                if (team != null)
                  TeamMatchPanel(
                    teamId:
                        team.id,
                    tournamentId:
                        team.tournamentId,
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
// TARJETA DE EQUIPO COMO ENCARGADO
// =============================================================

class _ManagedTeamCard
    extends StatelessWidget {
  const _ManagedTeamCard({
    required this.assignment,
    required this.repository,
  });

  final TeamAssignment
      assignment;

  final TeamRepository
      repository;

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
            teamSnapshot
                        .connectionState ==
                    ConnectionState
                        .waiting &&
                !teamSnapshot
                    .hasData;

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
          elevation:
              0,
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              18,
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Row(
                  children: [
                    Container(
                      width:
                          50,
                      height:
                          50,
                      decoration:
                          BoxDecoration(
                        color: colors
                            .primaryContainer,
                        borderRadius:
                            BorderRadius
                                .circular(
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
                                  BorderRadius
                                      .circular(
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
                      width:
                          14,
                    ),

                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
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
                                      FontWeight
                                          .w900,
                                ),
                          ),

                          const SizedBox(
                            height:
                                3,
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
                  height:
                      18,
                ),

                if (hasError) ...[
                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets
                            .all(
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors
                          .errorContainer,
                      borderRadius:
                          BorderRadius
                              .circular(
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
                    height:
                        16,
                  ),
                ],

                // =================================================
                // PARTIDO DEL EQUIPO QUE ADMINISTRA
                // =================================================

                if (team != null) ...[
                  TeamMatchPanel(
                    teamId:
                        team.id,
                    tournamentId:
                        team.tournamentId,
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),
                ],

                const Text(
                  'Como encargado activo puedes administrar la plantilla, '
                  'invitaciones, escudo y uniforme de este equipo.',
                ),

                const SizedBox(
                  height:
                      16,
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
                                Navigator
                                    .of(
                                  context,
                                ).push(
                                  MaterialPageRoute<
                                      void>(
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

  final TeamManagerInvitation
      invitation;

  final TeamRepository
      repository;

  @override
  State<_ManagerInvitationCard>
      createState() =>
          _ManagerInvitationCardState();
}

class _ManagerInvitationCardState
    extends State<
        _ManagerInvitationCard> {
  bool _processing =
      false;

  Future<void> _accept() async {
    setState(() {
      _processing =
          true;
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
          _processing =
              false;
        });
      }
    }
  }

  Future<void> _reject() async {
    setState(() {
      _processing =
          true;
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
          _processing =
              false;
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
      elevation:
          0,
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Row(
              children: [
                Container(
                  width:
                      48,
                  height:
                      48,
                  decoration:
                      BoxDecoration(
                    color: colors
                        .primaryContainer,
                    borderRadius:
                        BorderRadius
                            .circular(
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
                  width:
                      14,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
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
                                      FontWeight
                                          .w900,
                                ),
                      ),

                      const SizedBox(
                        height:
                            3,
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
              height:
                  16,
            ),

            const Text(
              'Un administrador de liga quiere asignarte como encargado '
              'de este equipo. Si aceptas, obtendrás permisos temporales '
              'para administrarlo.',
            ),

            const SizedBox(
              height:
                  18,
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
                  width:
                      10,
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

  final VoidCallback
      onRetry;

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
          height:
              20,
        ),

        Card(
          elevation:
              0,
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              20,
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Icon(
                  CupertinoIcons
                      .exclamationmark_triangle,
                  color:
                      colors.error,
                  size:
                      34,
                ),

                const SizedBox(
                  height:
                      12,
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
                            FontWeight
                                .w900,
                      ),
                ),

                const SizedBox(
                  height:
                      8,
                ),

                const Text(
                  'Tu asignación sigue guardada. Intenta sincronizar nuevamente.',
                ),

                const SizedBox(
                  height:
                      8,
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
                  height:
                      16,
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
          height:
              20,
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
          height:
              20,
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
                  CrossAxisAlignment
                      .start,
              children: [
                const Icon(
                  CupertinoIcons
                      .exclamationmark_triangle,
                ),

                const SizedBox(
                  width:
                      12,
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