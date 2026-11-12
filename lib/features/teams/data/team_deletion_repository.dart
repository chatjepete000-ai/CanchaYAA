import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/team_models.dart';

// ================================================================
// ELIMINAR EQUIPO (solo administrador de la liga)
// ================================================================
//
// En un solo batch (todo o nada):
//
// 1. Borra teams/{teamId}.
// 2. Borra su ficha pública publicTeams/{teamId}.
// 3. Borra su alineación teamLineups/{teamId}.
// 4. Revoca las asignaciones activas o pendientes (encargado y
//    jugadores): pierden el acceso al equipo y deja de aparecer en
//    su sección Equipos. La asignación queda como historial.
// 5. Cancela las invitaciones de encargado pendientes.
//
// No se permite si el equipo ya tiene partidos en un calendario,
// porque se romperían el calendario y la tabla de posiciones.
//
// Los códigos QR de jugadores que siguieran activos dejan de
// funcionar solos: unirse exige que el equipo exista.
//
// firestore.rules valida cada paso.
// ================================================================

class TeamDeletionResult {
  const TeamDeletionResult({
    required this.revokedAssignments,
    required this.cancelledInvitations,
  });

  final int revokedAssignments;
  final int cancelledInvitations;
}

class TeamDeletionRepository {
  TeamDeletionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// true si el equipo aparece como local o visitante en algún partido.
  Future<bool> hasMatches(String teamId) async {
    final matches = _firestore.collection('tournamentMatches');

    final asHome =
        await matches.where('homeTeamId', isEqualTo: teamId).limit(1).get();

    if (asHome.docs.isNotEmpty) {
      return true;
    }

    final asAway =
        await matches.where('awayTeamId', isEqualTo: teamId).limit(1).get();

    return asAway.docs.isNotEmpty;
  }

  Future<TeamDeletionResult> deleteTeam(Team team) async {
    if (_auth.currentUser == null) {
      throw StateError('Debes iniciar sesión.');
    }

    if (await hasMatches(team.id)) {
      throw StateError(
        'No se puede eliminar "${team.name}" porque ya tiene partidos en '
        'el calendario del torneo. Eliminarlo rompería el calendario y la '
        'tabla de posiciones.',
      );
    }

    // Las consultas incluyen leagueId para que firestore.rules pueda
    // comprobar que quien consulta administra esa liga.
    final assignments = await _firestore
        .collection('teamAssignments')
        .where('teamId', isEqualTo: team.id)
        .where('leagueId', isEqualTo: team.leagueId)
        .get();

    final invitations = await _firestore
        .collection('teamManagerInvitations')
        .where('teamId', isEqualTo: team.id)
        .where('leagueId', isEqualTo: team.leagueId)
        .get();

    final batch = _firestore.batch();

    batch.delete(_firestore.collection('teams').doc(team.id));
    batch.delete(_firestore.collection('publicTeams').doc(team.id));
    batch.delete(_firestore.collection('teamLineups').doc(team.id));

    var revoked = 0;

    for (final doc in assignments.docs) {
      final status = doc.data()['status'];

      if (status != 'active' && status != 'pending') {
        continue;
      }

      batch.update(doc.reference, <String, dynamic>{
        'status': AssignmentStatus.revoked.value,
        'revokedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      revoked++;
    }

    var cancelled = 0;

    for (final doc in invitations.docs) {
      if (doc.data()['status'] != 'pending') {
        continue;
      }

      batch.update(doc.reference, <String, dynamic>{
        'status': AssignmentStatus.revoked.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      cancelled++;
    }

    await batch.commit();

    return TeamDeletionResult(
      revokedAssignments: revoked,
      cancelledInvitations: cancelled,
    );
  }
}
