import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../domain/team_models.dart';

class TeamRosterScreen extends StatelessWidget {
  const TeamRosterScreen({
    super.key,
    required this.team,
  });

  final Team team;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Plantilla',
        ),
      ),
      body: SafeArea(
        child: _RosterContent(
          team: team,
        ),
      ),
    );
  }
}

class _RosterContent extends StatelessWidget {
  const _RosterContent({
    required this.team,
  });

  final Team team;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teamAssignments')
          .where(
            'teamId',
            isEqualTo: team.id,
          )
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _RosterError(
            error: snapshot.error,
          );
        }

        final documents =
            snapshot.data?.docs ??
                const <
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>[];

        final assignments = documents
            .map(
              (document) =>
                  TeamAssignment.fromMap(
                document.id,
                document.data(),
              ),
            )
            .where(
              (assignment) =>
                  assignment.role ==
                      TeamAssignmentRole.player &&
                  assignment.status ==
                      AssignmentStatus.active,
            )
            .toList()
          ..sort(
            (a, b) {
              final aName =
                  a.userDisplayName
                      .trim()
                      .toLowerCase();

              final bName =
                  b.userDisplayName
                      .trim()
                      .toLowerCase();

              return aName.compareTo(
                bName,
              );
            },
          );

        return _RosterList(
          team: team,
          assignments: assignments,
        );
      },
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({
    required this.team,
    required this.assignments,
  });

  final Team team;
  final List<TeamAssignment> assignments;

  @override
  Widget build(BuildContext context) {
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
        18,
        20,
        32,
      ),
      children: [
        _TeamRosterHeader(
          team: team,
          playerCount:
              assignments.length,
        ),

        const SizedBox(
          height: 24,
        ),

        Row(
          children: [
            Expanded(
              child: Text(
                'Jugadores',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w900,
                    ),
              ),
            ),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 6,
              ),
              decoration:
                  BoxDecoration(
                color: colors
                    .primaryContainer,
                borderRadius:
                    BorderRadius.circular(
                  100,
                ),
              ),
              child: Text(
                '${assignments.length}',
                style: TextStyle(
                  color:
                      colors.primary,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          assignments.isEmpty
              ? 'Aún no hay jugadores registrados.'
              : 'Jugadores activos dentro de ${team.name}.',
          style:
              theme.textTheme.bodyMedium,
        ),

        const SizedBox(
          height: 16,
        ),

        if (assignments.isEmpty)
          const _EmptyRoster()
        else
          ...assignments.asMap().entries.map(
                (entry) => Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: _PlayerCard(
                    assignment:
                        entry.value,
                    number:
                        entry.key + 1,
                  ),
                ),
              ),

        const SizedBox(
          height: 14,
        ),

        Container(
          padding:
              const EdgeInsets.all(
            16,
          ),
          decoration:
              BoxDecoration(
            color: colors
                .surfaceContainerHighest,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons
                    .shield_fill,
                color:
                    colors.primary,
              ),

              const SizedBox(
                width: 12,
              ),

              const Expanded(
                child: Text(
                  'La plantilla muestra únicamente jugadores '
                  'con una asignación activa dentro del equipo.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamRosterHeader
    extends StatelessWidget {
  const _TeamRosterHeader({
    required this.team,
    required this.playerCount,
  });

  final Team team;
  final int playerCount;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        20,
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
              alpha: 0.76,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(
          24,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: 0.17,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                18,
              ),
            ),
            child: team.logoUrl
                    .trim()
                    .isNotEmpty
                ? ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                    child:
                        Image.network(
                      team.logoUrl,
                      fit:
                          BoxFit.cover,
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return const Icon(
                          CupertinoIcons
                              .shield_fill,
                          color:
                              Colors.white,
                          size: 34,
                        );
                      },
                    ),
                  )
                : const Icon(
                    CupertinoIcons
                        .shield_fill,
                    color:
                        Colors.white,
                    size: 34,
                  ),
          ),

          const SizedBox(
            width: 16,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  team.name,
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                ),

                const SizedBox(
                  height: 7,
                ),

                Row(
                  children: [
                    const Icon(
                      CupertinoIcons
                          .person_2_fill,
                      color:
                          Colors.white,
                      size: 17,
                    ),

                    const SizedBox(
                      width: 6,
                    ),

                    Text(
                      '$playerCount ${playerCount == 1 ? 'jugador' : 'jugadores'}',
                      style: TextStyle(
                        color: Colors
                            .white
                            .withValues(
                          alpha:
                              0.90,
                        ),
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard
    extends StatelessWidget {
  const _PlayerCard({
    required this.assignment,
    required this.number,
  });

  final TeamAssignment assignment;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final cleanName =
        assignment.userDisplayName
            .trim();

    final cleanEmail =
        assignment.userEmail
            .trim();

    final displayName =
        cleanName.isNotEmpty
            ? cleanName
            : 'Jugador $number';

    final initial =
        displayName
            .substring(
              0,
              1,
            )
            .toUpperCase();

    return Card(
      elevation: 0,
      clipBehavior:
          Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor:
                  colors
                      .primaryContainer,
              child: Text(
                initial,
                style: TextStyle(
                  color:
                      colors.primary,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),

            const SizedBox(
              width: 14,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
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
                    height: 4,
                  ),

                  if (cleanEmail
                      .isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons
                              .mail,
                          size: 14,
                          color: colors
                              .onSurfaceVariant,
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        Expanded(
                          child: Text(
                            cleanEmail,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Jugador registrado',
                      style: theme
                          .textTheme
                          .bodySmall,
                    ),
                ],
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration:
                  BoxDecoration(
                color: colors
                    .primaryContainer,
                borderRadius:
                    BorderRadius
                        .circular(
                  100,
                ),
              ),
              child: Text(
                'Jugador',
                style: TextStyle(
                  color:
                      colors.primary,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRoster
    extends StatelessWidget {
  const _EmptyRoster();

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(
          22,
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration:
                  BoxDecoration(
                color: colors
                    .primaryContainer,
                shape:
                    BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons
                    .person_2,
                color:
                    colors.primary,
                size: 30,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              'Plantilla vacía',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
            ),

            const SizedBox(
              height: 6,
            ),

            const Text(
              'Cuando los jugadores acepten sus invitaciones aparecerán aquí.',
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterError
    extends StatelessWidget {
  const _RosterError({
    required this.error,
  });

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return ListView(
      padding:
          const EdgeInsets.all(
        20,
      ),
      children: [
        Container(
          padding:
              const EdgeInsets.all(
            18,
          ),
          decoration:
              BoxDecoration(
            color:
                colors.errorContainer,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons
                    .exclamationmark_triangle_fill,
                color: colors
                    .onErrorContainer,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'No se pudo cargar la plantilla',
                      style:
                          TextStyle(
                        color: colors
                            .onErrorContainer,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      '$error',
                      style:
                          TextStyle(
                        color: colors
                            .onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}