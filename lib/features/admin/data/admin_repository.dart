import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> createLeague({
    required String name,
    required String city,
    required String ownerUid,
  }) async {
    final ref = _firestore.collection('leagues').doc();
    await ref.set({
      'name': name.trim(),
      'city': city.trim(),
      'ownerUid': ownerUid,
      'adminUids': [ownerUid],
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> promoteCaptainByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw StateError('No se encontró ese usuario.');
    }

    await query.docs.first.reference.update({
      'role': 'captain',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignLeagueAdminByEmail({
    required String email,
    required String leagueId,
  }) async {
    final normalized = email.trim().toLowerCase();
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw StateError('No se encontró ese usuario.');
    }

    final userRef = query.docs.first.reference;
    final uid = query.docs.first.id;
    final leagueRef = _firestore.collection('leagues').doc(leagueId);

    await _firestore.runTransaction((transaction) async {
      transaction.update(leagueRef, {
        'adminUids': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        'role': 'admin',
        'adminScope': 'league',
        'managedLeagueIds': FieldValue.arrayUnion([leagueId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setGlobalAccountStatus({
    required String email,
    required bool suspended,
  }) async {
    final normalized = email.trim().toLowerCase();
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw StateError('No se encontró ese usuario.');
    }

    await query.docs.first.reference.update({
      'status': suspended ? 'suspended' : 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
