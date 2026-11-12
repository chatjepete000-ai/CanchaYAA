import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/public_tournament.dart';

// ================================================================
// TORNEOS PÚBLICOS
// ================================================================
//
// Lectura: cualquier usuario autenticado (sección Torneos).
// Escritura: solo el administrador de la liga, copiando los datos
// exactos de tournaments/{id} (lo valida firestore.rules).
// ================================================================

class PublicTournamentRepository {
  PublicTournamentRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _publicTournaments =>
      _firestore.collection('publicTournaments');

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _firestore.collection('tournaments');

  /// Torneos visibles en la sección pública, ordenados por nombre.
  Stream<List<PublicTournament>> watchListedTournaments() {
    return _publicTournaments.snapshots().map(
      (snapshot) {
        final tournaments = snapshot.docs
            .map(
              (doc) => PublicTournament.fromMap(
                doc.id,
                doc.data(),
              ),
            )
            .where(
              (tournament) => tournament.isPubliclyListed,
            )
            .toList();

        tournaments.sort(
          (a, b) => a.name.toLowerCase().compareTo(
                b.name.toLowerCase(),
              ),
        );

        return tournaments;
      },
    );
  }

  /// Datos públicos a partir del documento privado del torneo.
  ///
  /// Se copian los valores tal cual están guardados para que
  /// coincidan con la validación de firestore.rules.
  static Map<String, dynamic> publicDataFrom(
    Map<String, dynamic> tournamentData,
  ) {
    return <String, dynamic>{
      'leagueId': tournamentData['leagueId'],
      'name': tournamentData['name'],
      'category': tournamentData['category'],
      'city': tournamentData['city'],
      'season': tournamentData['season'] ?? '',
      'format': tournamentData['format'],
      'status': tournamentData['status'],
    };
  }

  /// Publica o actualiza la ficha pública de un torneo existente.
  ///
  /// Solo escribe si falta o si sus datos cambiaron, para no generar
  /// escrituras innecesarias cada vez que el administrador lo abre.
  /// Debe llamarlo un administrador de la liga.
  Future<void> syncFromTournament(
    String tournamentId,
  ) async {
    final tournamentSnapshot = await _tournaments.doc(tournamentId).get();
    final tournamentData = tournamentSnapshot.data();

    if (!tournamentSnapshot.exists || tournamentData == null) {
      return;
    }

    final expected = publicDataFrom(tournamentData);

    final publicSnapshot =
        await _publicTournaments.doc(tournamentId).get();
    final current = publicSnapshot.data();

    if (current != null &&
        expected.entries.every(
          (entry) => current[entry.key] == entry.value,
        )) {
      return;
    }

    await _publicTournaments.doc(tournamentId).set(
      <String, dynamic>{
        ...expected,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }
}
