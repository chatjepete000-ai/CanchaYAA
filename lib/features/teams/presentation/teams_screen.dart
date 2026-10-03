import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../data/team_repository.dart';
import '../domain/team_models.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const _TeamsEmptyState();
    }

    final repository = TeamRepository();

    return StreamBuilder<List<TeamAssignment>>(
      stream: repository.watchActiveAssignmentsForCurrentUser(),
      builder: (context, assignmentSnapshot) {
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
                'No se pudieron cargar tus asignaciones.\n${assignmentSnapshot.error}',
          );
        }

        final assignments =
            assignmentSnapshot.data ?? const <TeamAssignment>[];

        final managerAssignments = assignments
            .where(
              (assignment) =>
                  assignment.role ==
                  TeamAssignmentRole.teamManager,
            )
            .toList();

        return StreamBuilder<List<TeamManagerInvitation>>(
          stream:
              repository.watchPendingManagerInvitationsForCurrentUser(),
          builder: (context, invitationSnapshot) {
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
                    'No se pudieron cargar tus invitaciones.\n${invitationSnapshot.error}',
              );
            }

            final invitations =
                invitationSnapshot.data ??
                    const <TeamManagerInvitation>[];

            return _TeamsContent(
              managerAssignments: managerAssignments,
              invitations: invitations,
              repository: repository,
            );
          },
        );
      },
    );
  }
}

class _TeamsContent extends StatelessWidget {
  const _TeamsContent({
    required this.managerAssignments,
    required this.invitations,
    required this.repository,
  });

  final List<TeamAssignment> managerAssignments;
  final List<TeamManagerInvitation> invitations;
  final TeamRepository repository;

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
          'Equipos',
          style:
              Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
        ),
        const SizedBox(height: 6),
        Text(
          'Consulta tus equipos, invitaciones y permisos activos.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        const SizedBox(height: 24),

        if (managerAssignments.isNotEmpty) ...[
          Text(
            'Equipos que administras',
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
          ),
          const SizedBox(height: 12),

          ...managerAssignments.map(
            (assignment) => Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color:
                                  colors.primaryContainer,
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Equipo asignado',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight:
                                            FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'ID: ${assignment.teamId}',
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(
                              assignment.role.label,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'Como encargado activo podrás administrar la plantilla, invitaciones, escudo, uniforme y configuración de este equipo.',
                        style:
                            Theme.of(context).textTheme.bodyMedium,
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'La administración completa del equipo se conectará en el siguiente paso.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.manage_accounts_outlined,
                          ),
                          label: const Text(
                            'Administrar equipo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],

        Text(
          'Invitaciones',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
        ),

        const SizedBox(height: 12),

        if (invitations.isEmpty)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.mail_outline,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sin invitaciones pendientes',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 5),
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

        const SizedBox(height: 24),

        if (managerAssignments.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
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
                    'Tu cuenta mantiene permisos normales de jugador. Para administrar un equipo debes recibir y aceptar una invitación de un administrador de liga.',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ManagerInvitationCard extends StatefulWidget {
  const _ManagerInvitationCard({
    required this.invitation,
    required this.repository,
  });

  final TeamManagerInvitation invitation;
  final TeamRepository repository;

  @override
  State<_ManagerInvitationCard> createState() =>
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
      await widget.repository.acceptManagerInvitation(
        widget.invitation,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invitación aceptada. Ahora eres encargado de este equipo.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
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
      await widget.repository.rejectManagerInvitation(
        widget.invitation,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invitación rechazada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.invitation.teamName.isNotEmpty
                            ? widget.invitation.teamName
                            : 'Equipo',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Invitación para ser encargado',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text(
              'Un administrador de liga quiere asignarte como encargado de este equipo. Si aceptas, obtendrás permisos temporales para administrarlo.',
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _processing ? null : _reject,
                    child: const Text(
                      'Rechazar',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _processing ? null : _accept,
                    child: Text(
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

class _TeamsEmptyState extends StatelessWidget {
  const _TeamsEmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Equipos',
          style:
              Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
        ),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Firebase no está disponible en este entorno.',
            ),
          ),
        ),
      ],
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
        Text(
          'Equipos',
          style:
              Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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