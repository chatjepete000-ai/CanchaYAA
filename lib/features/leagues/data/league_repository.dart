import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../tournaments/data/public_tournament_repository.dart';
import '../domain/league_models.dart';

class LeagueRepository {
  LeagueRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _leagues =>
      _firestore.collection('leagues');

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _firestore.collection('tournaments');

  CollectionReference<Map<String, dynamic>> get _publicTournaments =>
      _firestore.collection('publicTournaments');

  Stream<List<League>> watchManagedLeaguesForCurrentUser() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream<List<League>>.value(const []);
    }

    return _leagues
        .where(
          'adminUserIds',
          arrayContains: user.uid,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => League.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  Stream<List<Tournament>> watchTournamentsForLeague(
    String leagueId,
  ) {
    if (leagueId.trim().isEmpty) {
      return Stream<List<Tournament>>.value(const []);
    }

    return _tournaments
        .where(
          'leagueId',
          isEqualTo: leagueId,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Tournament.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<String> createTournament({
    required String leagueId,
    required String name,
    required String category,
    required String city,
    required String season,
    required TournamentFormat format,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión para crear un torneo.',
      );
    }

    final leagueSnapshot = await _leagues.doc(leagueId).get();

    if (!leagueSnapshot.exists) {
      throw StateError(
        'La liga indicada no existe.',
      );
    }

    final leagueData = leagueSnapshot.data();

    if (leagueData == null) {
      throw StateError(
        'No se pudo leer la información de la liga.',
      );
    }

    final league = League.fromMap(
      leagueSnapshot.id,
      leagueData,
    );

    if (!league.isAdmin(user.uid)) {
      throw StateError(
        'No tienes permisos para administrar esta liga.',
      );
    }

    final cleanName = name.trim();
    final cleanCategory = category.trim();
    final cleanCity = city.trim();
    final cleanSeason = season.trim();

    if (cleanName.length < 3) {
      throw ArgumentError(
        'El nombre del torneo es demasiado corto.',
      );
    }

    if (cleanCategory.isEmpty) {
      throw ArgumentError(
        'Escribe una categoría.',
      );
    }

    if (cleanCity.isEmpty) {
      throw ArgumentError(
        'Escribe una ciudad.',
      );
    }

    final document = _tournaments.doc();

    final tournament = Tournament(
      id: document.id,
      leagueId: leagueId,
      name: cleanName,
      category: cleanCategory,
      city: cleanCity,
      season: cleanSeason,
      format: format,
      status: TournamentStatus.draft,
    );

    final tournamentData = <String, dynamic>{
      ...tournament.toMap(),
      'createdByUserId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // F05: el torneo y su ficha pública se crean juntos para que
    // aparezca en la sección Torneos de todos los usuarios.
    final batch = _firestore.batch();

    batch.set(
      document,
      tournamentData,
    );

    batch.set(
      _publicTournaments.doc(document.id),
      <String, dynamic>{
        ...PublicTournamentRepository.publicDataFrom(
          tournament.toMap(),
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    return document.id;
  }

  Future<void> updateTournamentStatus({
    required String tournamentId,
    required TournamentStatus status,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión.',
      );
    }

    final tournamentRef = _tournaments.doc(
      tournamentId,
    );

    final tournamentSnapshot = await tournamentRef.get();

    if (!tournamentSnapshot.exists) {
      throw StateError(
        'El torneo indicado no existe.',
      );
    }

    final tournamentData = tournamentSnapshot.data();

    if (tournamentData == null) {
      throw StateError(
        'No se pudo leer el torneo.',
      );
    }

    final tournament = Tournament.fromMap(
      tournamentSnapshot.id,
      tournamentData,
    );

    final leagueSnapshot = await _leagues.doc(
      tournament.leagueId,
    ).get();

    if (!leagueSnapshot.exists) {
      throw StateError(
        'La liga del torneo no existe.',
      );
    }

    final leagueData = leagueSnapshot.data();

    if (leagueData == null) {
      throw StateError(
        'No se pudo leer la liga.',
      );
    }

    final league = League.fromMap(
      leagueSnapshot.id,
      leagueData,
    );

    if (!league.isAdmin(user.uid)) {
      throw StateError(
        'No tienes permisos para modificar este torneo.',
      );
    }

    // F05: el estado público se actualiza en el mismo batch.
    final batch = _firestore.batch();

    batch.update(
      tournamentRef,
      {
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      _publicTournaments.doc(tournamentId),
      <String, dynamic>{
        ...PublicTournamentRepository.publicDataFrom(
          <String, dynamic>{
            ...tournamentData,
            'status': status.value,
          },
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  Future<League?> getLeagueById(
    String leagueId,
  ) async {
    if (leagueId.trim().isEmpty) {
      return null;
    }

    final snapshot = await _leagues.doc(leagueId).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return League.fromMap(
      snapshot.id,
      data,
    );
  }

  Future<bool> currentUserCanManageLeague(
    String leagueId,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final league = await getLeagueById(
      leagueId,
    );

    if (league == null) {
      return false;
    }

    return league.isAdmin(
      user.uid,
    );
  }
}