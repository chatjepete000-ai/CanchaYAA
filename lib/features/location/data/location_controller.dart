import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../courts/domain/court.dart';
import '../domain/user_location.dart';

// ================================================================
// CIUDAD ELEGIDA (compartida por Inicio, Canchas y Torneos)
// ================================================================
//
// - Al iniciar sesión lee users/{uid}.preferredLocation.
// - Al elegir otra ciudad la muestra de inmediato y la guarda en el
//   perfil (se conserva al reiniciar y en otros dispositivos).
// - Sin sesión o sin ciudad guardada se usa Montemorelos, N.L.
// ================================================================

class LocationController extends ChangeNotifier {
  LocationController._();

  static final LocationController instance = LocationController._();

  UserLocation _current = UserLocation.montemorelos;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _profileSubscription;

  UserLocation get current => _current;

  void start() {
    if (_authSubscription != null || Firebase.apps.isEmpty) {
      return;
    }

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        _profileSubscription?.cancel();
        _profileSubscription = null;

        if (user == null) {
          _set(UserLocation.montemorelos);
          return;
        }

        _profileSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen(
          (snapshot) {
            final data = snapshot.data()?['preferredLocation'];

            _set(
              UserLocation.fromMap(
                data is Map<String, dynamic> ? data : null,
              ),
            );
          },
          onError: (Object error) {
            if (kDebugMode) {
              debugPrint('LocationController: $error');
            }
          },
        );
      },
    );
  }

  /// Cambia la ciudad y la guarda en el perfil.
  Future<void> select(UserLocation location) async {
    _set(location);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || Firebase.apps.isEmpty) {
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      <String, dynamic>{
        'preferredLocation': location.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  void _set(UserLocation location) {
    final changed = location != _current ||
        location.latitude != _current.latitude ||
        location.longitude != _current.longitude;

    _current = location;

    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}

/// Ciudades que ya tienen canchas registradas en CanchaYA.
///
/// Las coordenadas son el promedio de las canchas con ubicación en
/// esa ciudad (no se inventan); si ninguna tiene, quedan vacías.
List<UserLocation> citiesFromCourts(
  Iterable<Court> courts, {
  String defaultState = '',
}) {
  final groups = <String, List<Court>>{};
  final names = <String, String>{};

  for (final court in courts) {
    if (!court.active || court.city.trim().isEmpty) continue;

    final key = normalizePlaceName(court.city);
    groups.putIfAbsent(key, () => []).add(court);
    names.putIfAbsent(key, () => court.city.trim());
  }

  final result = <UserLocation>[];

  for (final entry in groups.entries) {
    final located = entry.value.where((court) => court.hasCoordinates).toList();

    double? average(double Function(Court court) value) => located.isEmpty
        ? null
        : located.map(value).reduce((a, b) => a + b) / located.length;

    result.add(
      UserLocation(
        city: names[entry.key]!,
        state: defaultState,
        latitude: average((court) => court.latitude!),
        longitude: average((court) => court.longitude!),
      ),
    );
  }

  result.sort(
    (a, b) => normalizePlaceName(a.city).compareTo(normalizePlaceName(b.city)),
  );

  return result;
}
