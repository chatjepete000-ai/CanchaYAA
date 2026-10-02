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
