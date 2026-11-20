import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/match_alerts.dart';

// ================================================================
// F06 · AVISOS A LA BANDEJA (lo usa el administrador de la liga)
// ================================================================
//
// Al programar/reprogramar un partido o publicar/corregir su
// resultado, se crea un aviso en notifications/ para cada jugador y
// encargado de los dos equipos. firestore.rules valida que:
//
// - quien lo envía administre la liga del partido;
// - el destinatario pertenezca a uno de los dos equipos;
// - el ID sea {matchId}_{evento}_{uid} (sin duplicados).
//
// Si algo falla aquí, la acción principal (programar o publicar)
// ya quedó guardada; solo se informa cuántos avisos no se enviaron.
// ================================================================

class MatchNotificationPublisher {
  MatchNotificationPublisher({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Avisa que el partido se programó o cambió de horario/cancha.
  Future<int> notifyScheduled({
    required String matchId,
    required bool rescheduled,
  }) async {
    final match = await _readMatch(matchId);
    final startsAt = (match['startsAt'] as Timestamp?)?.toDate();

    if (startsAt == null) {
      return 0;
    }

    final names = await _teamNames(match);
    final courtName = (match['courtName'] as String?) ?? '';

    return _sendToMembers(
      matchId: matchId,
      match: match,
      eventKey: scheduleEventKey(startsAt),
      type: rescheduled ? 'match_updated' : 'match_created',
      title: matchupTitle(names.home, names.away),
      body: scheduledFullBody(
        rescheduled: rescheduled,
        home: names.home,
        away: names.away,
        startsAt: startsAt,
        courtName: courtName,
      ),
      extra: <String, dynamic>{
        'startsAtMillis': startsAt.toUtc().millisecondsSinceEpoch,
        'courtName': courtName,
        'courtId': (match['courtId'] as String?) ?? '',
      },
    );
  }

  /// Avisa que se publicó o corrigió el resultado.
  Future<int> notifyResult({
    required String matchId,
  }) async {
    final match = await _readMatch(matchId);
    final homeScore = (match['homeScore'] as num?)?.toInt();
    final awayScore = (match['awayScore'] as num?)?.toInt();
    final version = (match['resultVersion'] as num?)?.toInt() ?? 1;

    if (homeScore == null || awayScore == null) {
      return 0;
    }

    final names = await _teamNames(match);

    return _sendToMembers(
      matchId: matchId,
      match: match,
      eventKey: resultEventKey(version),
      type: 'result_published',
      title: '${names.home} $homeScore - $awayScore ${names.away}',
      body: resultFullBody(
        corrected: version > 1,
        home: names.home,
        away: names.away,
        homeScore: homeScore,
        awayScore: awayScore,
      ),
      extra: <String, dynamic>{
        'homeScore': homeScore,
        'awayScore': awayScore,
      },
      includeTournament: true,
    );
  }

  /// Avisa que el partido se suspendió o canceló, con el motivo.
  Future<int> notifyStatusChange({
    required String matchId,
    required bool cancelled,
    required String reasonLabel,
    String note = '',
    DateTime? previousStartsAt,
  }) async {
    final match = await _readMatch(matchId);
    final names = await _teamNames(match);

    return _sendToMembers(
      matchId: matchId,
      match: match,
      eventKey: statusChangeEventKey(
        cancelled: cancelled,
        changedAt: DateTime.now(),
      ),
      type: cancelled ? 'match_cancelled' : 'match_postponed',
      title: statusChangeTitle(
        cancelled: cancelled,
        home: names.home,
        away: names.away,
      ),
      body: statusChangeFullBody(
        cancelled: cancelled,
        home: names.home,
        away: names.away,
        reasonLabel: reasonLabel,
        note: note,
        previousStartsAt: previousStartsAt,
      ),
      extra: <String, dynamic>{
        'statusReason': (match['statusReason'] as String?) ?? '',
      },
    );
  }

  // ============================================================
  // INTERNOS
  // ============================================================

  Future<Map<String, dynamic>> _readMatch(String matchId) async {
    final snapshot =
        await _firestore.collection('tournamentMatches').doc(matchId).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw StateError('El partido ya no existe.');
    }

    return data;
  }

  /// Nombre corto público de cada equipo (o el del partido).
  Future<({String home, String away})> _teamNames(
    Map<String, dynamic> match,
  ) async {
    Future<String> nameFor(String teamId, String fallback) async {
      try {
        final snapshot =
            await _firestore.collection('publicTeams').doc(teamId).get();
        final data = snapshot.data();
        final shortName = (data?['shortName'] as String?)?.trim() ?? '';
        final name = (data?['name'] as String?)?.trim() ?? '';

        if (shortName.isNotEmpty) return shortName;
        if (name.isNotEmpty) return name;
      } catch (_) {
        // Se usa el nombre guardado en el partido.
      }

      return fallback.trim().isEmpty ? 'Equipo' : fallback.trim();
    }

    final home = await nameFor(
      (match['homeTeamId'] as String?) ?? '',
      (match['homeTeamName'] as String?) ?? '',
    );
    final away = await nameFor(
      (match['awayTeamId'] as String?) ?? '',
      (match['awayTeamName'] as String?) ?? '',
    );

    return (home: home, away: away);
  }

  /// Jugadores y encargados de ambos equipos (sin repetir).
  Future<Set<String>> _members(Map<String, dynamic> match) async {
    final members = <String>{};

    for (final key in ['homeTeamId', 'awayTeamId']) {
      final teamId = (match[key] as String?) ?? '';

      if (teamId.isEmpty) continue;

      final snapshot = await _firestore.collection('teams').doc(teamId).get();
      final data = snapshot.data() ?? const <String, dynamic>{};

      for (final field in ['playerUserIds', 'managerUserIds']) {
        final ids = data[field];

        if (ids is List) {
          members.addAll(
            ids.whereType<String>().where((id) => id.isNotEmpty),
          );
        }
      }
    }

    return members;
  }

  /// Jugadores y encargados de los OTROS equipos del torneo, con el
  /// equipo de cada uno (lo verifica firestore.rules).
  Future<Map<String, String>> _tournamentMembers(
    Map<String, dynamic> match,
  ) async {
    final tournamentId = (match['tournamentId'] as String?) ?? '';
    final playing = {
      (match['homeTeamId'] as String?) ?? '',
      (match['awayTeamId'] as String?) ?? '',
    };

    if (tournamentId.isEmpty) return const <String, String>{};

    final result = <String, String>{};

    try {
      final teams = await _firestore
          .collection('publicTeams')
          .where('tournamentId', isEqualTo: tournamentId)
          .get();

      for (final doc in teams.docs) {
        if (playing.contains(doc.id)) continue;

        try {
          final snapshot =
              await _firestore.collection('teams').doc(doc.id).get();
          final data = snapshot.data() ?? const <String, dynamic>{};

          if (data['tournamentId'] != tournamentId) continue;

          for (final field in ['playerUserIds', 'managerUserIds']) {
            final ids = data[field];

            if (ids is List) {
              for (final id in ids.whereType<String>()) {
                if (id.isNotEmpty) result.putIfAbsent(id, () => doc.id);
              }
            }
          }
        } catch (error) {
          if (kDebugMode) debugPrint('Equipo sin leer: $error');
        }
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Equipos del torneo sin leer: $error');
    }

    return result;
  }

  Future<int> _sendToMembers({
    required String matchId,
    required Map<String, dynamic> match,
    required String eventKey,
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> extra,
    bool includeTournament = false,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Debes iniciar sesión.');
    }

    // uid -> equipo (null = uno de los dos equipos del partido).
    final recipientTeams = <String, String?>{
      for (final id in await _members(match)) id: null,
    };

    if (includeTournament) {
      final others = await _tournamentMembers(match);

      others.forEach((uid, teamId) {
        recipientTeams.putIfAbsent(uid, () => teamId);
      });
    }

    final recipients = recipientTeams.keys.toList();
    var failed = 0;

    // Cada aviso se escribe por separado: si uno ya existía (por un
    // reintento) se rechaza solo ese y los demás se envían.
    await Future.wait(
      recipients.map((recipient) async {
        try {
          await _firestore
              .collection('notifications')
              .doc(
                matchNotificationDocId(
                  matchId: matchId,
                  eventKey: eventKey,
                  recipientUserId: recipient,
                ),
              )
              .set(<String, dynamic>{
            'recipientUserId': recipient,
            'title': title,
            'body': body,
            'type': type,
            'isRead': false,
            'readAt': null,
            'createdAt': FieldValue.serverTimestamp(),
            'senderUserId': user.uid,
            if (recipientTeams[recipient] != null)
              'teamId': recipientTeams[recipient],
            'matchId': matchId,
            'tournamentId': match['tournamentId'],
            'route': 'notifications',
            'data': <String, dynamic>{
              'eventKey': eventKey,
              'homeTeamId': match['homeTeamId'] ?? '',
              'awayTeamId': match['awayTeamId'] ?? '',
              ...extra,
            },
          });
        } catch (error) {
          failed++;

          if (kDebugMode) {
            debugPrint('Aviso no enviado a un destinatario: $error');
          }
        }
      }),
    );

    return recipients.length - failed;
  }
}
