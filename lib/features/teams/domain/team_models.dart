import 'package:cloud_firestore/cloud_firestore.dart';

class TeamSummary {
  const TeamSummary({
    required this.id,
    required this.name,
    required this.captainUid,
    required this.memberIds,
    this.category = '',
    this.city = '',
  });

  final String id;
  final String name;
  final String captainUid;
  final List<String> memberIds;
  final String category;
  final String city;

  factory TeamSummary.fromMap(String id, Map<String, dynamic> data) {
    return TeamSummary(
      id: id,
      name: (data['name'] as String?) ?? 'Equipo',
      captainUid: (data['captainUid'] as String?) ?? '',
      memberIds: List<String>.from(
        (data['memberIds'] as List<dynamic>?) ?? const [],
      ),
      category: (data['category'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
    );
  }
}

class TeamInvitation {
  const TeamInvitation({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.invitedEmail,
    required this.status,
  });

  final String id;
  final String teamId;
  final String teamName;
  final String invitedEmail;
  final String status;

  factory TeamInvitation.fromMap(String id, Map<String, dynamic> data) {
    return TeamInvitation(
      id: id,
      teamId: (data['teamId'] as String?) ?? '',
      teamName: (data['teamName'] as String?) ?? 'Equipo',
      invitedEmail: (data['invitedEmail'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
    );
  }
}


class TeamJoinCode {
  const TeamJoinCode({
    required this.code,
    required this.teamId,
    required this.teamName,
    required this.status,
    required this.expiresAt,
  });

  final String code;
  final String teamId;
  final String teamName;
  final String status;
  final DateTime? expiresAt;

  bool get isActive =>
      status == 'active' &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory TeamJoinCode.fromMap(
    String code,
    Map<String, dynamic> data,
  ) {
    final expires = data['expiresAt'];
    return TeamJoinCode(
      code: code,
      teamId: (data['teamId'] as String?) ?? '',
      teamName: (data['teamName'] as String?) ?? 'Equipo',
      status: (data['status'] as String?) ?? 'invalid',
      expiresAt: expires is Timestamp ? expires.toDate().toLocal() : null,
    );
  }
}
