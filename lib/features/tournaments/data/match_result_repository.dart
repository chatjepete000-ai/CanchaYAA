import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/match_result.dart';
import 'tournament_schedule_repository.dart';

// ================================================================
// F08 · CAPTURA Y CORRECCIÓN DE RESULTADOS
// ================================================================
//
// Publicar y corregir se hacen en una transacción que:
//
// 1. Lee el partido actual.
// 2. Actualiza homeScore, awayScore, status y resultVersion.
// 3. Crea resultHistory/v{resultVersion} con quién, cuándo y por qué.
//
// firestore.rules exige que ambos cambios ocurran juntos y que solo
// el administrador de la liga pueda hacerlos. Si la transacción se
// reintenta, la versión ya usada no se puede volver a crear, por lo
// que una corrección nunca se aplica dos veces.
// ================================================================

class MatchResultRepository {
  MatchResultRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _match(
    String matchId,
  ) {
    return _firestore
        .collection('tournamentMatches')
        .doc(matchId);
  }

  CollectionReference<Map<String, dynamic>> _history(
    String matchId,
  ) {
    return _match(matchId).collection(
      'resultHistory',
    );
  }

  // ============================================================
  // PARTIDO EN TIEMPO REAL
  // ============================================================

  Stream<TournamentMatchRecord?> watchMatch(
    String matchId,
  ) {
    return _match(matchId).snapshots().map(
      (snapshot) {
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          return null;
        }

        return TournamentMatchRecord.fromMap(
          snapshot.id,
          data,
        );
      },
    );
  }

  // ============================================================
  // HISTORIAL (solo administradores de la liga)
  // ============================================================

  Stream<List<MatchResultHistoryEntry>> watchHistory(
    String matchId,
  ) {
    if (matchId.trim().isEmpty) {
      return Stream<List<MatchResultHistoryEntry>>.value(
        const <MatchResultHistoryEntry>[],
      );
    }

    return _history(matchId).snapshots().map(
      (snapshot) {
        final entries = snapshot.docs
            .map(
              (doc) => MatchResultHistoryEntry.fromMap(
                doc.id,
                doc.data(),
              ),
            )
            .toList();

        entries.sort(
          (a, b) => b.version.compareTo(
            a.version,
          ),
        );

        return entries;
      },
    );
  }

  // ============================================================
  // PUBLICAR RESULTADO
  // ============================================================

  Future<void> publishResult({
    required String matchId,
    required int homeScore,
    required int awayScore,
  }) async {
    final user = _requireUser();

    _requireValidScores(
      homeScore,
      awayScore,
    );

    await _firestore.runTransaction(
      (transaction) async {
        final matchRef = _match(matchId);
        final snapshot = await transaction.get(matchRef);
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          throw StateError(
            'El partido ya no existe.',
          );
        }

        final status = data['status'] as String?;

        if (status == 'completed') {
          throw StateError(
            'Este partido ya tiene resultado. Usa "Corregir resultado".',
          );
        }

        if (status != 'scheduled') {
          throw StateError(
            'Solo se puede capturar el resultado de un partido programado.',
          );
        }

        if (data['startsAt'] == null) {
          throw StateError(
            'Primero asigna cancha y horario al partido.',
          );
        }

        const version = 1;

        transaction.update(
          matchRef,
          <String, dynamic>{
            'status': 'completed',
            'homeScore': homeScore,
            'awayScore': awayScore,
            'resultVersion': version,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        transaction.set(
          _history(matchId).doc(
            MatchResultHistoryEntry.entryIdForVersion(version),
          ),
          <String, dynamic>{
            'action': MatchResultAction.published.value,
            'homeScore': homeScore,
            'awayScore': awayScore,
            'previousHomeScore': null,
            'previousAwayScore': null,
            'reason': '',
            'changedByUserId': user.uid,
            'changedAt': FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  // ============================================================
  // CORREGIR RESULTADO
  // ============================================================

  Future<void> correctResult({
    required String matchId,
    required int homeScore,
    required int awayScore,
    required String reason,
  }) async {
    final user = _requireUser();

    _requireValidScores(
      homeScore,
      awayScore,
    );

    final reasonError = validateCorrectionReason(reason);

    if (reasonError != null) {
      throw ArgumentError(reasonError);
    }

    final cleanReason = reason.trim();

    await _firestore.runTransaction(
      (transaction) async {
        final matchRef = _match(matchId);
        final snapshot = await transaction.get(matchRef);
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          throw StateError(
            'El partido ya no existe.',
          );
        }

        if (data['status'] != 'completed') {
          throw StateError(
            'Solo se puede corregir un partido finalizado.',
          );
        }

        final previousHome =
            (data['homeScore'] as num?)?.toInt();
        final previousAway =
            (data['awayScore'] as num?)?.toInt();

        if (previousHome == homeScore &&
            previousAway == awayScore) {
          throw StateError(
            'El marcador corregido es igual al actual.',
          );
        }

        final currentVersion =
            (data['resultVersion'] as num?)?.toInt() ?? 0;

        final version = currentVersion + 1;

        transaction.update(
          matchRef,
          <String, dynamic>{
            'homeScore': homeScore,
            'awayScore': awayScore,
            'resultVersion': version,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        transaction.set(
          _history(matchId).doc(
            MatchResultHistoryEntry.entryIdForVersion(version),
          ),
          <String, dynamic>{
            'action': MatchResultAction.corrected.value,
            'homeScore': homeScore,
            'awayScore': awayScore,
            'previousHomeScore': previousHome,
            'previousAwayScore': previousAway,
            'reason': cleanReason,
            'changedByUserId': user.uid,
            'changedAt': FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  // ============================================================
  // VALIDACIONES
  // ============================================================

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión.',
      );
    }

    return user;
  }

  void _requireValidScores(
    int homeScore,
    int awayScore,
  ) {
    final error = validateMatchScore(homeScore) ??
        validateMatchScore(awayScore);

    if (error != null) {
      throw ArgumentError(error);
    }
  }
}
