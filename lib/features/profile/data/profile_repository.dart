import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/domain/user_role.dart';
import '../domain/user_profile.dart';

class ProfileRepository {
  ProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  Stream<UserProfile?> watchCurrentProfile() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream<UserProfile?>.value(null);
    }

    return _userRef(user.uid).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return UserProfile(
          uid: user.uid,
          displayName: user.displayName ?? '',
          email: user.email ?? '',
          role: UserRole.player,
          adminScope: AdminScope.none,
          status: AccountStatus.active,
        );
      }

      return UserProfile.fromMap(
        snapshot.id,
        data,
      );
    });
  }

  Future<void> createInitialProfile(User user) async {
    await _userRef(user.uid).set(
      {
        'displayName': user.displayName?.trim() ?? '',
        'email': user.email?.trim().toLowerCase() ?? '',
        'phone': '',
        'position': FootballPosition.unspecified.value,
        'role': UserRole.player.value,
        'adminScope': AdminScope.none.value,
        'managedLeagueIds': <String>[],
        'status': AccountStatus.active.value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  Future<void> ensureCurrentProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final ref = _userRef(user.uid);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      await createInitialProfile(user);
    }
  }

  Future<void> updateCurrentProfile({
    required String displayName,
    required String phone,
    required FootballPosition position,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'No hay una sesión activa.',
      );
    }

    final cleanName = displayName.trim();

    await user.updateDisplayName(
      cleanName,
    );

    await _userRef(user.uid).set(
      {
        'displayName': cleanName,
        'phone': phone.trim(),
        'position': position.value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }
}