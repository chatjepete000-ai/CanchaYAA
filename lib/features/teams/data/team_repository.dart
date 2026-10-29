import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/team_models.dart';

class TeamRepository {
  TeamRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore =
            firestore ??
                FirebaseFirestore.instance,
        _auth =
            auth ??
                FirebaseAuth.instance;

  final FirebaseFirestore
      _firestore;

  final FirebaseAuth
      _auth;

  CollectionReference<
          Map<String, dynamic>>
      get _teams =>
          _firestore.collection(
            'teams',
          );

  CollectionReference<
          Map<String, dynamic>>
      get _publicTeams =>
          _firestore.collection(
            'publicTeams',
          );

  CollectionReference<
          Map<String, dynamic>>
      get _assignments =>
          _firestore.collection(
            'teamAssignments',
          );

  CollectionReference<
          Map<String, dynamic>>
      get _managerInvitations =>
          _firestore.collection(
            'teamManagerInvitations',
          );

  // ============================================================
  // EQUIPOS DEL USUARIO ACTUAL
  // ============================================================

  Stream<List<Team>>
      watchTeamsForCurrentUser() {
    final user =
        _auth.currentUser;

    if (user == null) {
      return Stream<
          List<Team>>.value(
        const <Team>[],
      );
    }

    return _teams
        .where(
          'playerUserIds',
          arrayContains:
              user.uid,
        )
        .snapshots()
        .map(
      (
        snapshot,
      ) =>
          snapshot.docs
              .map(
                (
                  document,
                ) =>
                    Team.fromMap(
                  document.id,
                  document.data(),
                ),
              )
              .toList(),
    );
  }

  // ============================================================
  // ESCUCHAR EQUIPO POR ID
  // ============================================================

  Stream<Team?>
      watchTeamById(
    String teamId,
  ) {
    final cleanTeamId =
        teamId.trim();

    if (cleanTeamId.isEmpty) {
      return Stream<
          Team?>.value(
        null,
      );
    }

    return _teams
        .doc(
          cleanTeamId,
        )
        .snapshots()
        .map(
      (
        snapshot,
      ) {
        final data =
            snapshot.data();

        if (!snapshot.exists ||
            data == null) {
          return null;
        }

        return Team.fromMap(
          snapshot.id,
          data,
        );
      },
    );
  }

  // ============================================================
  // OBTENER EQUIPO UNA VEZ
  // ============================================================

  Future<Team?>
      getTeamById(
    String teamId,
  ) async {
    final cleanTeamId =
        teamId.trim();

    if (cleanTeamId.isEmpty) {
      return null;
    }

    final snapshot =
        await _teams
            .doc(
              cleanTeamId,
            )
            .get();

    final data =
        snapshot.data();

    if (!snapshot.exists ||
        data == null) {
      return null;
    }

    return Team.fromMap(
      snapshot.id,
      data,
    );
  }

  // ============================================================
  // INFORMACIÓN PÚBLICA DEL EQUIPO
  // ============================================================
  //
  // publicTeams contiene únicamente:
  //
  // - name
  // - shortName
  // - logoUrl
  // - leagueId
  // - tournamentId
  //
  // Nunca contiene:
  //
  // - playerUserIds
  // - managerUserIds
  // - correos
  // - invitaciones
  //
  // ============================================================

  Future<void> syncPublicTeam(
    Team team,
  ) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión.',
      );
    }

    final cleanTeamId =
        team.id.trim();

    if (cleanTeamId.isEmpty) {
      throw ArgumentError(
        'El equipo no es válido.',
      );
    }

    await _publicTeams
        .doc(
          cleanTeamId,
        )
        .set(
      <String, dynamic>{
        'name':
            team.name.trim(),
        'shortName':
            team.shortName.trim(),
        'logoUrl':
            team.logoUrl.trim(),
        'leagueId':
            team.leagueId.trim(),
        'tournamentId':
            team.tournamentId.trim(),
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ============================================================
  // ACTUALIZAR NOMBRE CORTO
  // ============================================================

  Future<Team>
      updateTeamShortName({
    required Team team,
    required String shortName,
  }) async {
    final cleanShortName =
        shortName.trim();

    if (cleanShortName.isNotEmpty &&
        cleanShortName.length < 2) {
      throw ArgumentError(
        'El nombre corto es demasiado pequeño.',
      );
    }

    if (cleanShortName.length > 20) {
      throw ArgumentError(
        'El nombre corto puede tener máximo 20 caracteres.',
      );
    }

    return updateTeamPresentation(
      team: team,
      shortName:
          cleanShortName,
    );
  }

  // ============================================================
  // ACTUALIZAR ESCUDO
  // ============================================================

  Future<Team>
      updateTeamLogoUrl({
    required Team team,
    required String logoUrl,
  }) async {
    final cleanLogoUrl =
        logoUrl.trim();

    if (cleanLogoUrl.isEmpty) {
      throw ArgumentError(
        'La URL del escudo está vacía.',
      );
    }

    final uri =
        Uri.tryParse(
      cleanLogoUrl,
    );

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw ArgumentError(
        'La URL del escudo no es válida.',
      );
    }

    return updateTeamPresentation(
      team: team,
      logoUrl:
          cleanLogoUrl,
    );
  }

  // ============================================================
  // ACTUALIZAR PRESENTACIÓN DEL EQUIPO
  // ============================================================
  //
  // Esta función actualiza DOS documentos de forma conjunta:
  //
  // teams/{teamId}
  //     ↓
  // información interna
  //
  // publicTeams/{teamId}
  //     ↓
  // información visual pública
  //
  // Así mantenemos ambas colecciones sincronizadas.
  // ============================================================

  Future<Team>
      updateTeamPresentation({
    required Team team,
    String? shortName,
    String? logoUrl,
  }) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión.',
      );
    }

    final teamId =
        team.id.trim();

    if (teamId.isEmpty) {
      throw ArgumentError(
        'El equipo no es válido.',
      );
    }

    final newShortName =
        shortName ??
            team.shortName;

    final newLogoUrl =
        logoUrl ??
            team.logoUrl;

    final updatedTeam =
        team.copyWith(
      shortName:
          newShortName.trim(),
      logoUrl:
          newLogoUrl.trim(),
    );

    final teamRef =
        _teams.doc(
      teamId,
    );

    final publicTeamRef =
        _publicTeams.doc(
      teamId,
    );

    final batch =
        _firestore.batch();

    final teamUpdates =
        <String, dynamic>{
      'updatedAt':
          FieldValue
              .serverTimestamp(),
    };

    if (shortName != null) {
      teamUpdates['shortName'] =
          updatedTeam.shortName;
    }

    if (logoUrl != null) {
      teamUpdates['logoUrl'] =
          updatedTeam.logoUrl;
    }

    batch.update(
      teamRef,
      teamUpdates,
    );

    batch.set(
      publicTeamRef,
      <String, dynamic>{
        'name':
            updatedTeam.name
                .trim(),
        'shortName':
            updatedTeam.shortName
                .trim(),
        'logoUrl':
            updatedTeam.logoUrl
                .trim(),
        'leagueId':
            updatedTeam.leagueId
                .trim(),
        'tournamentId':
            updatedTeam
                .tournamentId
                .trim(),
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );

    await batch.commit();

    return updatedTeam;
  }

  // ============================================================
  // ASIGNACIONES ACTIVAS DEL USUARIO
  // ============================================================

  Stream<List<TeamAssignment>>
      watchActiveAssignmentsForCurrentUser() {
    final user =
        _auth.currentUser;

    if (user == null) {
      return Stream<
          List<TeamAssignment>>.value(
        const <
            TeamAssignment>[],
      );
    }

    return _assignments
        .where(
          'userId',
          isEqualTo:
              user.uid,
        )
        .snapshots()
        .map(
      (
        snapshot,
      ) =>
          snapshot.docs
              .map(
                (
                  document,
                ) =>
                    TeamAssignment
                        .fromMap(
                  document.id,
                  document.data(),
                ),
              )
              .where(
                (
                  assignment,
                ) =>
                    assignment.status ==
                    AssignmentStatus
                        .active,
              )
              .toList(),
    );
  }

  // ============================================================
  // INVITACIONES PENDIENTES A ENCARGADO
  // ============================================================

  Stream<
          List<
              TeamManagerInvitation>>
      watchPendingManagerInvitationsForCurrentUser() {
    final user =
        _auth.currentUser;

    if (user == null) {
      return Stream<
          List<
              TeamManagerInvitation>>.value(
        const <
            TeamManagerInvitation>[],
      );
    }

    final email =
        user.email
                ?.trim()
                .toLowerCase() ??
            '';

    if (email.isEmpty) {
      return Stream<
          List<
              TeamManagerInvitation>>.value(
        const <
            TeamManagerInvitation>[],
      );
    }

    return _managerInvitations
        .where(
          'invitedEmail',
          isEqualTo:
              email,
        )
        .snapshots()
        .map(
      (
        snapshot,
      ) =>
          snapshot.docs
              .map(
                (
                  document,
                ) =>
                    TeamManagerInvitation
                        .fromMap(
                  document.id,
                  document.data(),
                ),
              )
              .where(
                (
                  invitation,
                ) =>
                    invitation.status ==
                    AssignmentStatus
                        .pending,
              )
              .toList(),
    );
  }

  // ============================================================
  // CREAR EQUIPO
  // ============================================================
  //
  // Por ahora mantenemos este flujo igual.
  //
  // Después de desplegar las reglas de publicTeams podremos
  // hacer que los equipos nuevos creen automáticamente también
  // su documento público.
  // ============================================================

  Future<String> createTeam({
    required String name,
    required String leagueId,
    required String tournamentId,
  }) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión para crear un equipo.',
      );
    }

    final cleanName =
        name.trim();

    if (cleanName.length < 2) {
      throw ArgumentError(
        'El nombre del equipo es demasiado corto.',
      );
    }

    final document =
        _teams.doc();

    final team =
        Team(
      id: document.id,
      name:
          cleanName,
      leagueId:
          leagueId,
      tournamentId:
          tournamentId,
      status:
          TeamStatus.active,
    );

    await document.set(
      <String, dynamic>{
        ...team.toMap(),
        'createdByUserId':
            user.uid,
        'createdAt':
            FieldValue
                .serverTimestamp(),
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      },
    );

    return document.id;
  }

  // ============================================================
  // INVITAR ENCARGADO
  // ============================================================

  Future<void>
      sendManagerInvitation({
    required String teamId,
    required String teamName,
    required String leagueId,
    required String tournamentId,
    required String invitedEmail,
  }) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión para enviar invitaciones.',
      );
    }

    final cleanEmail =
        invitedEmail
            .trim()
            .toLowerCase();

    if (cleanEmail.isEmpty ||
        !cleanEmail.contains(
          '@',
        )) {
      throw ArgumentError(
        'Escribe un correo válido.',
      );
    }

    final duplicate =
        await _managerInvitations
            .where(
              'leagueId',
              isEqualTo:
                  leagueId,
            )
            .where(
              'teamId',
              isEqualTo:
                  teamId,
            )
            .where(
              'invitedEmail',
              isEqualTo:
                  cleanEmail,
            )
            .get();

    final alreadyPending =
        duplicate.docs.any(
      (
        document,
      ) {
        final data =
            document.data();

        return AssignmentStatusX
                .fromValue(
              data['status']
                  as String?,
            ) ==
            AssignmentStatus
                .pending;
      },
    );

    if (alreadyPending) {
      throw StateError(
        'Ya existe una invitación pendiente para ese usuario.',
      );
    }

    final document =
        _managerInvitations
            .doc();

    final invitation =
        TeamManagerInvitation(
      id:
          document.id,
      teamId:
          teamId,
      teamName:
          teamName,
      leagueId:
          leagueId,
      tournamentId:
          tournamentId,
      invitedEmail:
          cleanEmail,
      invitedByUserId:
          user.uid,
      status:
          AssignmentStatus.pending,
    );

    await document.set(
      <String, dynamic>{
        ...invitation.toMap(),
        'createdAt':
            FieldValue
                .serverTimestamp(),
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      },
    );
  }

  // ============================================================
  // ACEPTAR INVITACIÓN DE ENCARGADO
  // ============================================================

  Future<void>
      acceptManagerInvitation(
    TeamManagerInvitation
        invitation,
  ) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión para aceptar la invitación.',
      );
    }

    final currentEmail =
        user.email
                ?.trim()
                .toLowerCase() ??
            '';

    final invitedEmail =
        invitation.invitedEmail
            .trim()
            .toLowerCase();

    if (currentEmail !=
        invitedEmail) {
      throw StateError(
        'Esta invitación no pertenece a tu cuenta.',
      );
    }

    final invitationRef =
        _managerInvitations
            .doc(
      invitation.id,
    );

    final assignmentRef =
        _assignments.doc(
      invitation.id,
    );

    await _firestore
        .runTransaction(
      (
        transaction,
      ) async {
        final invitationSnapshot =
            await transaction
                .get(
          invitationRef,
        );

        if (!invitationSnapshot
            .exists) {
          throw StateError(
            'La invitación ya no existe.',
          );
        }

        final data =
            invitationSnapshot
                .data();

        if (data == null) {
          throw StateError(
            'La invitación no contiene información válida.',
          );
        }

        final storedEmail =
            (data['invitedEmail']
                        as String?)
                    ?.trim()
                    .toLowerCase() ??
                '';

        if (storedEmail !=
            currentEmail) {
          throw StateError(
            'Esta invitación pertenece a otra cuenta.',
          );
        }

        final currentStatus =
            AssignmentStatusX
                .fromValue(
          data['status']
              as String?,
        );

        if (currentStatus !=
            AssignmentStatus
                .pending) {
          throw StateError(
            'Esta invitación ya fue procesada.',
          );
        }

        final assignment =
            TeamAssignment(
          id:
              invitation.id,
          userId:
              user.uid,
          userEmail:
              currentEmail,
          userDisplayName:
              user.displayName
                      ?.trim() ??
                  '',
          teamId:
              invitation.teamId,
          leagueId:
              invitation.leagueId,
          tournamentId:
              invitation
                  .tournamentId,
          role:
              TeamAssignmentRole
                  .teamManager,
          status:
              AssignmentStatus
                  .active,
          assignedByUserId:
              invitation
                  .invitedByUserId,
        );

        transaction.set(
          assignmentRef,
          <String, dynamic>{
            ...assignment.toMap(),
            'createdAt':
                FieldValue
                    .serverTimestamp(),
            'acceptedAt':
                FieldValue
                    .serverTimestamp(),
            'updatedAt':
                FieldValue
                    .serverTimestamp(),
          },
        );

        transaction.update(
          invitationRef,
          <String, dynamic>{
            'status':
                AssignmentStatus
                    .active.value,
            'invitedUserId':
                user.uid,
            'acceptedAt':
                FieldValue
                    .serverTimestamp(),
            'updatedAt':
                FieldValue
                    .serverTimestamp(),
          },
        );
      },
    );

    await ensureManagerLinkedToTeam(
      assignmentId:
          invitation.id,
      teamId:
          invitation.teamId,
    );
  }

  // ============================================================
  // VINCULAR ENCARGADO AL EQUIPO
  // ============================================================

  Future<void>
      ensureManagerLinkedToTeam({
    required String assignmentId,
    required String teamId,
  }) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión.',
      );
    }

    final cleanAssignmentId =
        assignmentId.trim();

    final cleanTeamId =
        teamId.trim();

    if (cleanAssignmentId.isEmpty ||
        cleanTeamId.isEmpty) {
      throw ArgumentError(
        'La asignación o el equipo no son válidos.',
      );
    }

    final teamRef =
        _teams.doc(
      cleanTeamId,
    );

    try {
      /*
       * No leemos primero el equipo.
       *
       * Antes de estar dentro de managerUserIds el
       * encargado todavía no tiene permiso para leerlo.
       *
       * Las reglas validan que la asignación exista,
       * esté activa y pertenezca al usuario actual.
       */
      await teamRef.update(
        <String, dynamic>{
          'managerUserIds':
              FieldValue.arrayUnion(
            <String>[
              user.uid,
            ],
          ),
          'lastManagerAssignmentId':
              cleanAssignmentId,
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );
    } on FirebaseException {
      /*
       * Si ya estaba vinculado, la regla especial puede
       * rechazar una segunda actualización.
       *
       * Intentamos leer el equipo y comprobar si el UID
       * ya está dentro de managerUserIds.
       */
      try {
        final snapshot =
            await teamRef.get();

        final data =
            snapshot.data();

        if (snapshot.exists &&
            data != null) {
          final managerUserIds =
              List<String>.from(
            data['managerUserIds']
                    as List<dynamic>? ??
                const <dynamic>[],
          );

          if (managerUserIds
              .contains(
            user.uid,
          )) {
            return;
          }
        }
      } catch (_) {
        // Conservamos el error original.
      }

      rethrow;
    }
  }

  // ============================================================
  // SINCRONIZAR ASIGNACIONES DE ENCARGADO
  // ============================================================

  Future<void>
      syncCurrentManagerAssignments() async {
    final user =
        _auth.currentUser;

    if (user == null) {
      return;
    }

    final snapshot =
        await _assignments
            .where(
              'userId',
              isEqualTo:
                  user.uid,
            )
            .get();

    final assignments =
        snapshot.docs
            .map(
              (
                document,
              ) =>
                  TeamAssignment
                      .fromMap(
                document.id,
                document.data(),
              ),
            )
            .where(
              (
                assignment,
              ) =>
                  assignment.status ==
                      AssignmentStatus
                          .active &&
                  assignment.role ==
                      TeamAssignmentRole
                          .teamManager,
            )
            .toList();

    for (final assignment
        in assignments) {
      await ensureManagerLinkedToTeam(
        assignmentId:
            assignment.id,
        teamId:
            assignment.teamId,
      );
    }
  }

  // ============================================================
  // RECHAZAR INVITACIÓN
  // ============================================================

  Future<void>
      rejectManagerInvitation(
    TeamManagerInvitation
        invitation,
  ) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión para rechazar la invitación.',
      );
    }

    final currentEmail =
        user.email
                ?.trim()
                .toLowerCase() ??
            '';

    final invitedEmail =
        invitation.invitedEmail
            .trim()
            .toLowerCase();

    if (currentEmail !=
        invitedEmail) {
      throw StateError(
        'Esta invitación no pertenece a tu cuenta.',
      );
    }

    final invitationRef =
        _managerInvitations.doc(
      invitation.id,
    );

    await _firestore
        .runTransaction(
      (
        transaction,
      ) async {
        final snapshot =
            await transaction
                .get(
          invitationRef,
        );

        if (!snapshot.exists) {
          throw StateError(
            'La invitación ya no existe.',
          );
        }

        final data =
            snapshot.data();

        if (data == null) {
          throw StateError(
            'La invitación no contiene información válida.',
          );
        }

        final storedEmail =
            (data['invitedEmail']
                        as String?)
                    ?.trim()
                    .toLowerCase() ??
                '';

        if (storedEmail !=
            currentEmail) {
          throw StateError(
            'Esta invitación pertenece a otra cuenta.',
          );
        }

        final status =
            AssignmentStatusX
                .fromValue(
          data['status']
              as String?,
        );

        if (status !=
            AssignmentStatus
                .pending) {
          throw StateError(
            'Esta invitación ya fue procesada.',
          );
        }

        transaction.update(
          invitationRef,
          <String, dynamic>{
            'status':
                AssignmentStatus
                    .rejected.value,
            'invitedUserId':
                user.uid,
            'rejectedAt':
                FieldValue
                    .serverTimestamp(),
            'updatedAt':
                FieldValue
                    .serverTimestamp(),
          },
        );
      },
    );
  }

  // ============================================================
  // REVOCAR ENCARGADO
  // ============================================================

  Future<void>
      revokeManagerAssignment({
    required TeamAssignment
        assignment,
  }) async {
    final currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      throw StateError(
        'Debes iniciar sesión.',
      );
    }

    if (!assignment.isManager) {
      throw StateError(
        'La asignación indicada no corresponde a un encargado.',
      );
    }

    await _assignments
        .doc(
          assignment.id,
        )
        .update(
      <String, dynamic>{
        'status':
            AssignmentStatus
                .revoked.value,
        'revokedByUserId':
            currentUser.uid,
        'revokedAt':
            FieldValue
                .serverTimestamp(),
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      },
    );
  }

  // ============================================================
  // FINALIZAR ASIGNACIÓN DE ENCARGADO
  // ============================================================

  Future<void>
      finishManagerAssignment({
    required TeamAssignment
        assignment,
  }) async {
    final currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      throw StateError(
        'Debes iniciar sesión.',
      );
    }

    if (!assignment.isManager) {
      throw StateError(
        'La asignación indicada no corresponde a un encargado.',
      );
    }

    await _assignments
        .doc(
          assignment.id,
        )
        .update(
      <String, dynamic>{
        'status':
            AssignmentStatus
                .finished.value,
        'finishedByUserId':
            currentUser.uid,
        'finishedAt':
            FieldValue
                .serverTimestamp(),
        'updatedAt':
            FieldValue
                .serverTimestamp(),
      },
    );
  }
}