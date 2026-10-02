import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> createLeague({
    required String name,
    required String city,
    required String adminEmail,
  }) async {
    final normalized = adminEmail.trim().toLowerCase();
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw StateError(
        'El administrador debe tener una cuenta CanchaYA registrada.',
      );
    }

    final adminDoc = query.docs.first;
    final uid = adminDoc.id;
    final leagueRef = _firestore.collection('leagues').doc();

    await _firestore.runTransaction((transaction) async {
      transaction.set(leagueRef, {
        'name': name.trim(),
        'city': city.trim(),
        'ownerUid': uid,
        'adminUids': [uid],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(adminDoc.reference, {
        'role': 'admin',
        'adminScope': 'league',
        'managedLeagueIds': FieldValue.arrayUnion([leagueRef.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return leagueRef.id;
  }

  Future<void> promoteCaptainByEmail(String email) async {
    final user = await _findUserByEmail(email);

    await user.reference.update({
      'role': 'captain',
      'adminScope': 'none',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignLeagueAdminByEmail({
    required String email,
    required String leagueId,
  }) async {
    final user = await _findUserByEmail(email);
    final uid = user.id;
    final leagueRef = _firestore.collection('leagues').doc(leagueId);
    final league = await leagueRef.get();

    if (!league.exists) {
      throw StateError('La liga indicada no existe.');
    }

    await _firestore.runTransaction((transaction) async {
      transaction.update(leagueRef, {
        'adminUids': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(user.reference, {
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
    final user = await _findUserByEmail(email);

    await user.reference.update({
      'status': suspended ? 'suspended' : 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>> _findUserByEmail(
    String email,
  ) async {
    final normalized = email.trim().toLowerCase();
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw StateError('No se encontró ese usuario.');
    }

    return query.docs.first;
  }
}
