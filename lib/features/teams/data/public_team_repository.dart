import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/public_team.dart';

class PublicTeamRepository {
  PublicTeamRepository({
    FirebaseFirestore? firestore,
  }) : _firestore =
            firestore ??
                FirebaseFirestore.instance;

  final FirebaseFirestore
      _firestore;

  CollectionReference<
          Map<String, dynamic>>
      get _publicTeams =>
          _firestore.collection(
            'publicTeams',
          );

  // ============================================================
  // ESCUCHAR UN EQUIPO PÚBLICO
  // ============================================================

  Stream<PublicTeam?>
      watchTeam(
    String teamId,
  ) {
    final cleanTeamId =
        teamId.trim();

    if (cleanTeamId.isEmpty) {
      return Stream<
          PublicTeam?>.value(
        null,
      );
    }

    return _publicTeams
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

        return PublicTeam.fromMap(
          snapshot.id,
          data,
        );
      },
    );
  }

  // ============================================================
  // OBTENER UN EQUIPO PÚBLICO
  // ============================================================

  Future<PublicTeam?>
      getTeam(
    String teamId,
  ) async {
    final cleanTeamId =
        teamId.trim();

    if (cleanTeamId.isEmpty) {
      return null;
    }

    final snapshot =
        await _publicTeams
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

    return PublicTeam.fromMap(
      snapshot.id,
      data,
    );
  }

  // ============================================================
  // ESCUCHAR VARIOS EQUIPOS
  // ============================================================
  //
  // Esto será útil en el Calendario.
  //
  // Recibe los IDs de los equipos que aparecen en los partidos
  // y devuelve un Map:
  //
  // {
  //   "teamA": PublicTeam(...),
  //   "teamB": PublicTeam(...),
  // }
  //
  // Firestore permite un máximo limitado de elementos en whereIn,
  // por eso aquí no hacemos una consulta masiva con whereIn.
  //
  // El calendario podrá pedir cada equipo individualmente o usar
  // watchAllTeams() cuando sea conveniente.
  // ============================================================

  Stream<List<PublicTeam>>
      watchAllTeams() {
    return _publicTeams
        .snapshots()
        .map(
      (
        snapshot,
      ) {
        final teams =
            snapshot.docs
                .map(
                  (
                    document,
                  ) =>
                      PublicTeam.fromMap(
                    document.id,
                    document.data(),
                  ),
                )
                .toList();

        teams.sort(
          (
            first,
            second,
          ) =>
              first.displayName
                  .toLowerCase()
                  .compareTo(
                    second.displayName
                        .toLowerCase(),
                  ),
        );

        return teams;
      },
    );
  }

  // ============================================================
  // MAPA POR ID
  // ============================================================
  //
  // Este método nos servirá directamente para el calendario.
  //
  // Ejemplo:
  //
  // final teams = repository.mapById(lista);
  //
  // teams[match.homeTeamId]
  // teams[match.awayTeamId]
  //
  // ============================================================

  Map<String, PublicTeam>
      mapById(
    Iterable<PublicTeam> teams,
  ) {
    return <String, PublicTeam>{
      for (final team in teams)
        team.id:
            team,
    };
  }

  // ============================================================
  // GUARDAR / SINCRONIZAR INFORMACIÓN PÚBLICA
  // ============================================================
  //
  // Este método será llamado únicamente desde flujos permitidos
  // para encargado/admin una vez que ajustemos las reglas.
  //
  // No guarda:
  //
  // - playerUserIds
  // - managerUserIds
  // - correos
  // - invitaciones
  // - asignaciones
  //
  // Solo información visual pública.
  // ============================================================

  Future<void>
      savePublicTeam({
    required String teamId,
    required String name,
    required String shortName,
    required String logoUrl,
    required String leagueId,
    required String tournamentId,
  }) async {
    final cleanTeamId =
        teamId.trim();

    final cleanName =
        name.trim();

    final cleanShortName =
        shortName.trim();

    final cleanLogoUrl =
        logoUrl.trim();

    final cleanLeagueId =
        leagueId.trim();

    final cleanTournamentId =
        tournamentId.trim();

    if (cleanTeamId.isEmpty) {
      throw ArgumentError(
        'El equipo no es válido.',
      );
    }

    if (cleanName.isEmpty) {
      throw ArgumentError(
        'El nombre del equipo está vacío.',
      );
    }

    if (cleanLeagueId.isEmpty ||
        cleanTournamentId.isEmpty) {
      throw ArgumentError(
        'La liga o el torneo no son válidos.',
      );
    }

    await _publicTeams
        .doc(
          cleanTeamId,
        )
        .set(
      <String, dynamic>{
        'name':
            cleanName,
        'shortName':
            cleanShortName,
        'logoUrl':
            cleanLogoUrl,
        'leagueId':
            cleanLeagueId,
        'tournamentId':
            cleanTournamentId,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }
}