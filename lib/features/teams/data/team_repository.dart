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
    if (normalizedEmail == user.email?.trim().toLowerCase()) {
      throw ArgumentError('No puedes invitarte a ti mismo.');
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
}
