import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamJoinCodeStatus {
  active,
  used,
  revoked,
  expired,
}

extension TeamJoinCodeStatusX on TeamJoinCodeStatus {
  String get value {
    switch (this) {
      case TeamJoinCodeStatus.active:
        return 'active';
      case TeamJoinCodeStatus.used:
        return 'used';
      case TeamJoinCodeStatus.revoked:
        return 'revoked';
      case TeamJoinCodeStatus.expired:
        return 'expired';
    }
  }

  String get label {
    switch (this) {
      case TeamJoinCodeStatus.active:
        return 'Activo';
      case TeamJoinCodeStatus.used:
        return 'Utilizado';
      case TeamJoinCodeStatus.revoked:
        return 'Revocado';
      case TeamJoinCodeStatus.expired:
        return 'Expirado';
    }
  }

  static TeamJoinCodeStatus fromValue(
    String? value,
  ) {
    switch (value) {
      case 'used':
        return TeamJoinCodeStatus.used;

      case 'revoked':
        return TeamJoinCodeStatus.revoked;

      case 'expired':
        return TeamJoinCodeStatus.expired;

      case 'active':
      default:
        return TeamJoinCodeStatus.active;
    }
  }
}

enum TeamJoinCodePurpose {
  managerInvitation,
  playerInvitation,
}

extension TeamJoinCodePurposeX on TeamJoinCodePurpose {
  String get value {
    switch (this) {
      case TeamJoinCodePurpose.managerInvitation:
        return 'managerInvitation';

      case TeamJoinCodePurpose.playerInvitation:
        return 'playerInvitation';
    }
  }

  String get label {
    switch (this) {
      case TeamJoinCodePurpose.managerInvitation:
        return 'Invitación a encargado';

      case TeamJoinCodePurpose.playerInvitation:
        return 'Invitación a jugador';
    }
  }

  static TeamJoinCodePurpose fromValue(
    String? value,
  ) {
    switch (value) {
      case 'managerInvitation':
        return TeamJoinCodePurpose.managerInvitation;

      case 'playerInvitation':
      default:
        return TeamJoinCodePurpose.playerInvitation;
    }
  }
}

enum TeamJoinCodeDelivery {
  qr,
  email,
}

extension TeamJoinCodeDeliveryX on TeamJoinCodeDelivery {
  String get value {
    switch (this) {
      case TeamJoinCodeDelivery.qr:
        return 'qr';

      case TeamJoinCodeDelivery.email:
        return 'email';
    }
  }

  String get label {
    switch (this) {
      case TeamJoinCodeDelivery.qr:
        return 'QR / código manual';

      case TeamJoinCodeDelivery.email:
        return 'Correo';
    }
  }

  static TeamJoinCodeDelivery fromValue(
    String? value,
  ) {
    switch (value) {
      case 'email':
        return TeamJoinCodeDelivery.email;

      case 'qr':
      default:
        return TeamJoinCodeDelivery.qr;
    }
  }
}

class TeamJoinCode {
  const TeamJoinCode({
    required this.id,
    required this.teamId,
    required this.leagueId,
    required this.code,
    required this.status,
    required this.purpose,
    required this.delivery,
    required this.createdByUserId,
    required this.createdAt,
    this.tournamentId,
    this.invitedUserId,
    this.invitedEmail,
    this.usedByUserId,
    this.usedAt,
    this.revokedAt,
    this.expiresAt,
  });

  /// ID único del documento.
  ///
  /// Nunca debe reutilizarse.
  final String id;

  /// Equipo al que pertenece la invitación.
  final String teamId;

  /// Liga correspondiente.
  final String leagueId;

  /// Torneo correspondiente.
  final String? tournamentId;

  /// Código que puede escribirse manualmente.
  ///
  /// Ejemplo:
  /// CYA-H7KT-P92M
  final String code;

  /// Estado del acceso.
  final TeamJoinCodeStatus status;

  /// Indica qué permiso otorgará:
  /// encargado o jugador.
  final TeamJoinCodePurpose purpose;

  /// Forma en la que fue generado:
  /// QR/manual o correo.
  final TeamJoinCodeDelivery delivery;

  /// Usuario que generó la invitación.
  final String createdByUserId;

  /// UID específico si la invitación ya está
  /// asociada a una cuenta.
  final String? invitedUserId;

  /// Correo específico si fue una invitación remota.
  final String? invitedEmail;

  /// Usuario que finalmente utilizó el código.
  final String? usedByUserId;

  final DateTime? createdAt;

  final DateTime? usedAt;

  final DateTime? revokedAt;

  final DateTime? expiresAt;

  bool get isActive {
    if (status != TeamJoinCodeStatus.active) {
      return false;
    }

    if (expiresAt != null &&
        DateTime.now().isAfter(expiresAt!)) {
      return false;
    }

    return true;
  }

  bool get isManagerInvitation {
    return purpose ==
        TeamJoinCodePurpose.managerInvitation;
  }

  bool get isPlayerInvitation {
    return purpose ==
        TeamJoinCodePurpose.playerInvitation;
  }

  bool get isQrAccess {
    return delivery == TeamJoinCodeDelivery.qr;
  }

  bool get isEmailAccess {
    return delivery == TeamJoinCodeDelivery.email;
  }

  bool get isPersonalInvitation {
    return invitedUserId != null ||
        (invitedEmail != null &&
            invitedEmail!.trim().isNotEmpty);
  }

  /// El QR y el código manual contienen
  /// exactamente el mismo acceso.
  String get qrPayload {
    return 'canchaya://join-team?access=$code';
  }

  factory TeamJoinCode.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return TeamJoinCode(
      id: id,
      teamId:
          (data['teamId'] as String? ?? '').trim(),
      leagueId:
          (data['leagueId'] as String? ?? '').trim(),
      tournamentId: _cleanNullableString(
        data['tournamentId'],
      ),
      code:
          (data['code'] as String? ?? '').trim(),
      status:
          TeamJoinCodeStatusX.fromValue(
        data['status'] as String?,
      ),
      purpose:
          TeamJoinCodePurposeX.fromValue(
        data['purpose'] as String?,
      ),
      delivery:
          TeamJoinCodeDeliveryX.fromValue(
        data['delivery'] as String?,
      ),
      createdByUserId:
          (data['createdByUserId'] as String? ?? '')
              .trim(),
      invitedUserId: _cleanNullableString(
        data['invitedUserId'],
      ),
      invitedEmail: _cleanNullableString(
        data['invitedEmail'],
      ),
      usedByUserId: _cleanNullableString(
        data['usedByUserId'],
      ),
      createdAt: _dateFromFirestore(
        data['createdAt'],
      ),
      usedAt: _dateFromFirestore(
        data['usedAt'],
      ),
      revokedAt: _dateFromFirestore(
        data['revokedAt'],
      ),
      expiresAt: _dateFromFirestore(
        data['expiresAt'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'teamId': teamId,
      'leagueId': leagueId,
      'tournamentId': tournamentId,
      'code': code,
      'status': status.value,
      'purpose': purpose.value,
      'delivery': delivery.value,
      'createdByUserId': createdByUserId,
      'invitedUserId': invitedUserId,
      'invitedEmail': invitedEmail,
      'usedByUserId': usedByUserId,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'usedAt': usedAt == null
          ? null
          : Timestamp.fromDate(usedAt!),
      'revokedAt': revokedAt == null
          ? null
          : Timestamp.fromDate(revokedAt!),
      'expiresAt': expiresAt == null
          ? null
          : Timestamp.fromDate(expiresAt!),
    };
  }

  static DateTime? _dateFromFirestore(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static String? _cleanNullableString(
    dynamic value,
  ) {
    if (value is! String) {
      return null;
    }

    final clean = value.trim();

    if (clean.isEmpty) {
      return null;
    }

    return clean;
  }
}