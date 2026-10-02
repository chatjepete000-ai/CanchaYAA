import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/team_models.dart';

class TeamRepository {
  TeamRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<TeamSummary>> watchAllTeams() {
    return _firestore.collection('teams').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => TeamSummary.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<TeamSummary>> watchMyTeams() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    return _firestore
        .collection('teams')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TeamSummary.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<TeamInvitation>> watchMyPendingInvitations() {
    final email = _auth.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return Stream.value(const []);

    return _firestore
        .collection('teamInvitations')
        .where('invitedEmail', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TeamInvitation.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> createTeam({
    required String name,
    required String category,
    required String city,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay una sesión activa.');

    final ref = _firestore.collection('teams').doc();
    await ref.set({
      'name': name.trim(),
      'category': category.trim(),
      'city': city.trim(),
      'captainUid': user.uid,
      'memberIds': [user.uid],
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> invitePlayer({
    required TeamSummary team,
    required String email,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay una sesión activa.');

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('Escribe un correo válido.');
    }

    if (normalizedEmail == user.email?.trim().toLowerCase()) {
      throw ArgumentError('No puedes invitarte a ti mismo.');
    }

    final existing = await _firestore
        .collection('teamInvitations')
        .where('teamId', isEqualTo: team.id)
        .where('invitedEmail', isEqualTo: normalizedEmail)
        .where('status', isEqualTo: 'pending')
        .where('createdBy', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw StateError('Ese jugador ya tiene una invitación pendiente.');
    }

    await _firestore.collection('teamInvitations').add({
      'teamId': team.id,
      'teamName': team.name,
      'invitedEmail': normalizedEmail,
      'createdBy': user.uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondToInvitation({
    required TeamInvitation invitation,
    required bool accept,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay una sesión activa.');

    final invitationRef =
        _firestore.collection('teamInvitations').doc(invitation.id);
    final teamRef = _firestore.collection('teams').doc(invitation.teamId);

    await _firestore.runTransaction((transaction) async {
      final invitationSnapshot = await transaction.get(invitationRef);
      final data = invitationSnapshot.data();

      if (!invitationSnapshot.exists ||
          data == null ||
          data['status'] != 'pending') {
        throw StateError('La invitación ya no está disponible.');
      }

      transaction.update(invitationRef, {
        'status': accept ? 'accepted' : 'rejected',
        'respondedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (accept) {
        transaction.update(teamRef, {
          'memberIds': FieldValue.arrayUnion([user.uid]),
          'lastAcceptedInvitationId': invitation.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<TeamJoinCode> createJoinCode(TeamSummary team) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay una sesión activa.');

    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    for (var attempt = 0; attempt < 6; attempt++) {
      final code = List.generate(
        10,
        (_) => alphabet[random.nextInt(alphabet.length)],
      ).join();

      final ref = _firestore.collection('teamJoinCodes').doc(code);
      final existing = await ref.get();
      if (existing.exists) continue;

      final expiresAt = DateTime.now().add(const Duration(days: 7));

      await ref.set({
        'teamId': team.id,
        'teamName': team.name,
        'createdBy': user.uid,
        'status': 'active',
        'expiresAt': Timestamp.fromDate(expiresAt.toUtc()),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return TeamJoinCode(
        code: code,
        teamId: team.id,
        teamName: team.name,
        status: 'active',
        expiresAt: expiresAt,
      );
    }

    throw StateError('No fue posible generar un código único.');
  }

  Future<TeamJoinCode> getJoinCode(String rawCode) async {
    final code = _normalizeJoinCode(rawCode);
    final snapshot =
        await _firestore.collection('teamJoinCodes').doc(code).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw StateError('La invitación no existe.');
    }

    final expires = data['expiresAt'];
    final result = TeamJoinCode(
      code: code,
      teamId: (data['teamId'] as String?) ?? '',
      teamName: (data['teamName'] as String?) ?? 'Equipo',
      status: (data['status'] as String?) ?? 'invalid',
      expiresAt: expires is Timestamp ? expires.toDate().toLocal() : null,
    );

    if (!result.isActive) {
      throw StateError('La invitación expiró o ya fue utilizada.');
    }

    return result;
  }

  Future<void> acceptJoinCode(String rawCode) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay una sesión activa.');

    final code = _normalizeJoinCode(rawCode);
    final codeRef = _firestore.collection('teamJoinCodes').doc(code);

    await _firestore.runTransaction((transaction) async {
      final codeSnapshot = await transaction.get(codeRef);
      final data = codeSnapshot.data();

      if (!codeSnapshot.exists ||
          data == null ||
          data['status'] != 'active') {
        throw StateError('La invitación ya no está disponible.');
      }

      final expiresAt = data['expiresAt'];
      if (expiresAt is Timestamp &&
          expiresAt.toDate().isBefore(DateTime.now().toUtc())) {
        throw StateError('La invitación ya expiró.');
      }

      final teamId = data['teamId'] as String?;
      if (teamId == null || teamId.isEmpty) {
        throw StateError('La invitación no tiene un equipo válido.');
      }

      final teamRef = _firestore.collection('teams').doc(teamId);

      transaction.update(codeRef, {
        'status': 'used',
        'usedBy': user.uid,
        'usedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(teamRef, {
        'memberIds': FieldValue.arrayUnion([user.uid]),
        'lastJoinCode': code,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelJoinCode(String rawCode) async {
    final code = _normalizeJoinCode(rawCode);
    await _firestore.collection('teamJoinCodes').doc(code).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _normalizeJoinCode(String value) {
    var code = value.trim();

    final uri = Uri.tryParse(code);
    if (uri != null && uri.scheme == 'canchaya') {
      code = uri.queryParameters['code'] ?? '';
    }

    return code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }
}
