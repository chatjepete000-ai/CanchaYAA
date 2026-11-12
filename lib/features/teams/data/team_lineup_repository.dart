import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/team_lineup.dart';
import '../domain/team_models.dart';

// ================================================================
// F04 · REPOSITORIO DE ALINEACIONES
// ================================================================
//
// Lectura: jugadores y encargados del equipo, y administradores de
// la liga. Escritura: solo el encargado del equipo. Lo valida
// firestore.rules.
// ================================================================

class LineupPlayer {
  const LineupPlayer({
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String displayName;
}

class TeamLineupRepository {
  TeamLineupRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _lineup(String teamId) {
    return _firestore.collection('teamLineups').doc(teamId);
  }

  Stream<TeamLineup?> watchLineup(String teamId) {
    return _lineup(teamId).snapshots().map(
      (snapshot) {
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          return null;
        }

        return TeamLineup.fromMap(snapshot.id, data);
      },
    );
  }

  /// Formato del torneo (football5, football7 o football11).
  ///
  /// Se lee de publicTournaments, que cualquier usuario autenticado
  /// puede consultar. Si no existe, se usa Fútbol 7.
  Future<String> getTournamentFormat(String tournamentId) async {
    if (tournamentId.trim().isEmpty) {
      return defaultLineupFormat;
    }

    try {
      final snapshot = await _firestore
          .collection('publicTournaments')
          .doc(tournamentId)
          .get();

      final format = snapshot.data()?['format'];

      if (format is String &&
          lineupFormationsByFormat.containsKey(format)) {
        return format;
      }
    } catch (_) {
      // Sin conexión o sin ficha pública: se usa el formato por defecto.
    }

    return defaultLineupFormat;
  }

  /// Jugadores activos del equipo (solo el encargado y la liga
  /// pueden consultar teamAssignments).
  Stream<List<LineupPlayer>> watchRosterPlayers(Team team) {
    return _firestore
        .collection('teamAssignments')
        .where('teamId', isEqualTo: team.id)
        .snapshots()
        .map(
      (snapshot) {
        final rosterIds = team.playerUserIds.toSet();

        final players = snapshot.docs
            .map((doc) => TeamAssignment.fromMap(doc.id, doc.data()))
            .where(
              (assignment) =>
                  assignment.role == TeamAssignmentRole.player &&
                  assignment.status == AssignmentStatus.active &&
                  (rosterIds.isEmpty ||
                      rosterIds.contains(assignment.userId)),
            )
            .map(
              (assignment) => LineupPlayer(
                userId: assignment.userId,
                displayName: lineupNameFor(assignment.userDisplayName),
              ),
            )
            .toList();

        // Un jugador con dos asignaciones aparece una sola vez.
        final unique = <String, LineupPlayer>{
          for (final player in players) player.userId: player,
        }.values.toList()
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                ),
          );

        return unique;
      },
    );
  }

  Future<void> saveLineup({
    required Team team,
    required String format,
    required String formation,
    required List<String> slots,
    required Map<String, String> namesById,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Debes iniciar sesión.');
    }

    final selected = formationFor(format, formation);

    if (slots.length != selected.slotCount) {
      throw ArgumentError('La alineación no coincide con la formación.');
    }

    if (!hasNoDuplicatePlayers(slots)) {
      throw ArgumentError(
        'Un jugador no puede ocupar dos posiciones.',
      );
    }

    await _lineup(team.id).set(
      <String, dynamic>{
        'teamId': team.id,
        'leagueId': team.leagueId,
        'tournamentId': team.tournamentId,
        'format': format,
        'formation': selected.id,
        'slots': slots,
        'playerNames': [
          for (final id in slots)
            id.isEmpty ? '' : lineupNameFor(namesById[id] ?? ''),
        ],
        'updatedByUserId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }
}
