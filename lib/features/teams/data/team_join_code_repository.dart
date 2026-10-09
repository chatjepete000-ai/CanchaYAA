import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/team_join_code.dart';

class TeamJoinCodeRepository {
  TeamJoinCodeRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore =
            firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _collectionName =
      'teamJoinCodes';

  static const int _maxGenerationAttempts = 25;

  static const String _alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>>
      get _codes =>
          _firestore.collection(_collectionName);

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Debes iniciar sesión para generar invitaciones.',
      );
    }

    return user;
  }

  /// Invitación presencial para un encargado.
  ///
  /// Genera un acceso nuevo que puede mostrarse
  /// como QR o escribirse manualmente.
  Future<TeamJoinCode> createManagerQrAccess({
    required String teamId,
    required String leagueId,
    required String tournamentId,
  }) {
    return _createUniqueAccess(
      teamId: teamId,
      leagueId: leagueId,
      tournamentId: tournamentId,
      purpose:
          TeamJoinCodePurpose.managerInvitation,
      delivery:
          TeamJoinCodeDelivery.qr,
    );
  }

  /// Invitación por correo para un encargado.
  ///
  /// Cada llamada genera un acceso nuevo.
  Future<TeamJoinCode> createManagerEmailAccess({
    required String teamId,
    required String leagueId,
    required String tournamentId,
    required String invitedEmail,
    String? invitedUserId,
  }) {
    final cleanEmail =
        invitedEmail.trim().toLowerCase();

    if (cleanEmail.isEmpty ||
        !cleanEmail.contains('@')) {
      throw ArgumentError(
        'Escribe un correo válido.',
      );
    }

    return _createUniqueAccess(
      teamId: teamId,
      leagueId: leagueId,
      tournamentId: tournamentId,
      purpose:
          TeamJoinCodePurpose.managerInvitation,
      delivery:
          TeamJoinCodeDelivery.email,
      invitedEmail: cleanEmail,
      invitedUserId: invitedUserId,
    );
  }

  /// Invitación presencial para un jugador.
  ///
  /// El mismo acceso puede verse como QR
  /// o escribirse manualmente.
  Future<TeamJoinCode> createPlayerQrAccess({
    required String teamId,
    required String leagueId,
    required String tournamentId,
  }) {
    return _createUniqueAccess(
      teamId: teamId,
      leagueId: leagueId,
      tournamentId: tournamentId,
      purpose:
          TeamJoinCodePurpose.playerInvitation,
      delivery:
          TeamJoinCodeDelivery.qr,
    );
  }

  /// Invitación por correo para un jugador.
  ///
  /// Cada llamada genera un acceso distinto,
  /// incluso si se invita dos veces al mismo correo.
  Future<TeamJoinCode> createPlayerEmailAccess({
    required String teamId,
    required String leagueId,
    required String tournamentId,
    required String invitedEmail,
    String? invitedUserId,
  }) {
    final cleanEmail =
        invitedEmail.trim().toLowerCase();

    if (cleanEmail.isEmpty ||
        !cleanEmail.contains('@')) {
      throw ArgumentError(
        'Escribe un correo válido.',
      );
    }

    return _createUniqueAccess(
      teamId: teamId,
      leagueId: leagueId,
      tournamentId: tournamentId,
      purpose:
          TeamJoinCodePurpose.playerInvitation,
      delivery:
          TeamJoinCodeDelivery.email,
      invitedEmail: cleanEmail,
      invitedUserId: invitedUserId,
    );
  }

  /// Busca un código exacto.
  Future<TeamJoinCode?> getByCode(
    String code,
  ) async {
    final cleanCode =
        normalizeCode(code);

    if (cleanCode.isEmpty) {
      return null;
    }

    final snapshot =
        await _codes.doc(cleanCode).get();

    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return TeamJoinCode.fromMap(
      id: snapshot.id,
      data: data,
    );
  }

  /// Busca un acceso mediante el contenido de QR.
  Future<TeamJoinCode?> getByQrPayload(
    String payload,
  ) async {
    final code =
        extractCodeFromQrPayload(payload);

    if (code == null) {
      return null;
    }

    return getByCode(code);
  }

  /// Revoca un acceso.
  ///
  /// El documento nunca se elimina.
  Future<void> revokeAccess(
    String codeId,
  ) async {
    final user = _requireUser();

    final cleanCode =
        normalizeCode(codeId);

    if (cleanCode.isEmpty) {
      throw ArgumentError(
        'El código no es válido.',
      );
    }

    final codeRef =
        _codes.doc(cleanCode);

    await _firestore.runTransaction(
      (transaction) async {
        final snapshot =
            await transaction.get(codeRef);

        final data = snapshot.data();

        if (!snapshot.exists ||
            data == null) {
          throw StateError(
            'El acceso indicado no existe.',
          );
        }

        final access =
            TeamJoinCode.fromMap(
          id: snapshot.id,
          data: data,
        );

        if (access.status ==
                TeamJoinCodeStatus.revoked ||
            access.status ==
                TeamJoinCodeStatus.used ||
            access.status ==
                TeamJoinCodeStatus.expired) {
          return;
        }

        transaction.update(
          codeRef,
          <String, dynamic>{
            'status':
                TeamJoinCodeStatus
                    .revoked
                    .value,
            'revokedAt':
                FieldValue.serverTimestamp(),
            'revokedByUserId':
                user.uid,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  /// Marca un acceso como utilizado.
  ///
  /// Solo debe llamarse después de validar
  /// qué tipo de invitación representa.
  Future<void> markAsUsed({
    required String codeId,
    required String usedByUserId,
  }) async {
    final cleanCode =
        normalizeCode(codeId);

    final cleanUserId =
        usedByUserId.trim();

    if (cleanCode.isEmpty ||
        cleanUserId.isEmpty) {
      throw ArgumentError(
        'El código y el usuario son obligatorios.',
      );
    }

    final codeRef =
        _codes.doc(cleanCode);

    await _firestore.runTransaction(
      (transaction) async {
        final snapshot =
            await transaction.get(codeRef);

        final data = snapshot.data();

        if (!snapshot.exists ||
            data == null) {
          throw StateError(
            'El acceso no existe.',
          );
        }

        final access =
            TeamJoinCode.fromMap(
          id: snapshot.id,
          data: data,
        );

        if (!access.isActive) {
          throw StateError(
            'Este acceso ya no está disponible.',
          );
        }

        transaction.update(
          codeRef,
          <String, dynamic>{
            'status':
                TeamJoinCodeStatus
                    .used
                    .value,
            'usedByUserId':
                cleanUserId,
            'usedAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  Future<TeamJoinCode> _createUniqueAccess({
    required String teamId,
    required String leagueId,
    required String tournamentId,
    required TeamJoinCodePurpose purpose,
    required TeamJoinCodeDelivery delivery,
    String? invitedUserId,
    String? invitedEmail,
  }) async {
    final user = _requireUser();

    final cleanTeamId =
        teamId.trim();

    final cleanLeagueId =
        leagueId.trim();

    final cleanTournamentId =
        tournamentId.trim();

    final cleanInvitedUserId =
        _cleanNullable(invitedUserId);

    final cleanInvitedEmail =
        _cleanNullable(invitedEmail)
            ?.toLowerCase();

    if (cleanTeamId.isEmpty) {
      throw ArgumentError(
        'El ID del equipo es obligatorio.',
      );
    }

    if (cleanLeagueId.isEmpty) {
      throw ArgumentError(
        'El ID de la liga es obligatorio.',
      );
    }

    if (cleanTournamentId.isEmpty) {
      throw ArgumentError(
        'El ID del torneo es obligatorio.',
      );
    }

    for (var attempt = 0;
        attempt < _maxGenerationAttempts;
        attempt++) {
      final newCode =
          _generateCode();

      final codeRef =
          _codes.doc(newCode);

      try {
        final result =
            await _firestore.runTransaction<
                TeamJoinCode>(
          (transaction) async {
            final existingCode =
                await transaction.get(
              codeRef,
            );

            if (existingCode.exists) {
              throw const _CodeCollisionException();
            }

            final access =
                TeamJoinCode(
              id: newCode,
              teamId: cleanTeamId,
              leagueId:
                  cleanLeagueId,
              tournamentId:
                  cleanTournamentId,
              code: newCode,
              status:
                  TeamJoinCodeStatus.active,
              purpose: purpose,
              delivery: delivery,
              createdByUserId:
                  user.uid,
              invitedUserId:
                  cleanInvitedUserId,
              invitedEmail:
                  cleanInvitedEmail,
              usedByUserId: null,
              createdAt: null,
              usedAt: null,
              revokedAt: null,
              expiresAt: null,
            );

            final data =
                access.toMap();

            data['createdAt'] =
                FieldValue.serverTimestamp();

            data['updatedAt'] =
                FieldValue.serverTimestamp();

            data['revokedByUserId'] =
                null;

            transaction.set(
              codeRef,
              data,
            );

            return access;
          },
        );

        return result;
      } on _CodeCollisionException {
        continue;
      }
    }

    throw StateError(
      'No fue posible generar un código único después de varios intentos.',
    );
  }

  String _generateCode() {
    final random = Random.secure();

    String block(int length) {
      return List<String>.generate(
        length,
        (_) {
          final index =
              random.nextInt(
            _alphabet.length,
          );

          return _alphabet[index];
        },
      ).join();
    }

    return 'CYA-${block(4)}-${block(4)}';
  }

  static String normalizeCode(
    String value,
  ) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(' ', '');
  }

  static String? extractCodeFromQrPayload(
    String payload,
  ) {
    final cleanPayload =
        payload.trim();

    if (cleanPayload.isEmpty) {
      return null;
    }

    if (!cleanPayload.startsWith(
      'canchaya://join-team?access=',
    )) {
      return null;
    }

    final rawCode =
        cleanPayload.substring(
      'canchaya://join-team?access='
          .length,
    );

    final code =
        normalizeCode(rawCode);

    if (code.isEmpty) {
      return null;
    }

    return code;
  }

  static String? _cleanNullable(
    dynamic value,
  ) {
    if (value is! String) {
      return null;
    }

    final clean =
        value.trim();

    if (clean.isEmpty) {
      return null;
    }

    return clean;
  }
}

class _CodeCollisionException
    implements Exception {
  const _CodeCollisionException();
}