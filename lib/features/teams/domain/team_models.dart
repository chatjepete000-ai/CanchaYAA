enum TeamStatus {
  active,
  inactive,
  archived,
}

extension TeamStatusX on TeamStatus {
  String get value => name;

  String get label {
    switch (this) {
      case TeamStatus.active:
        return 'Activo';
      case TeamStatus.inactive:
        return 'Inactivo';
      case TeamStatus.archived:
        return 'Archivado';
    }
  }

  static TeamStatus fromValue(String? value) {
    return TeamStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TeamStatus.active,
    );
  }
}

enum AssignmentStatus {
  pending,
  active,
  rejected,
  revoked,
  finished,
}

extension AssignmentStatusX on AssignmentStatus {
  String get value => name;

  String get label {
    switch (this) {
      case AssignmentStatus.pending:
        return 'Pendiente';
      case AssignmentStatus.active:
        return 'Activo';
      case AssignmentStatus.rejected:
        return 'Rechazado';
      case AssignmentStatus.revoked:
        return 'Revocado';
      case AssignmentStatus.finished:
        return 'Finalizado';
    }
  }

  static AssignmentStatus fromValue(String? value) {
    return AssignmentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AssignmentStatus.pending,
    );
  }
}

enum TeamAssignmentRole {
  player,
  teamManager,
}

extension TeamAssignmentRoleX on TeamAssignmentRole {
  String get value => name;

  String get label {
    switch (this) {
      case TeamAssignmentRole.player:
        return 'Jugador';
      case TeamAssignmentRole.teamManager:
        return 'Encargado de equipo';
    }
  }

  static TeamAssignmentRole fromValue(String? value) {
    return TeamAssignmentRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => TeamAssignmentRole.player,
    );
  }
}

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.leagueId,
    required this.tournamentId,
    required this.status,
    this.logoUrl = '',
    this.uniformDescription = '',
    this.managerUserIds = const [],
    this.playerUserIds = const [],
  });

  final String id;
  final String name;
  final String leagueId;
  final String tournamentId;

  final String logoUrl;
  final String uniformDescription;

  final TeamStatus status;

  final List<String> managerUserIds;
  final List<String> playerUserIds;

  bool get hasManager => managerUserIds.isNotEmpty;

  int get totalPlayers => playerUserIds.length;

  factory Team.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return Team(
      id: id,
      name: (data['name'] as String?)?.trim() ?? '',
      leagueId: (data['leagueId'] as String?)?.trim() ?? '',
      tournamentId: (data['tournamentId'] as String?)?.trim() ?? '',
      logoUrl: (data['logoUrl'] as String?)?.trim() ?? '',
      uniformDescription:
          (data['uniformDescription'] as String?)?.trim() ?? '',
      status: TeamStatusX.fromValue(
        data['status'] as String?,
      ),
      managerUserIds: List<String>.from(
        (data['managerUserIds'] as List<dynamic>?) ?? const [],
      ),
      playerUserIds: List<String>.from(
        (data['playerUserIds'] as List<dynamic>?) ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'leagueId': leagueId,
      'tournamentId': tournamentId,
      'logoUrl': logoUrl.trim(),
      'uniformDescription': uniformDescription.trim(),
      'status': status.value,
      'managerUserIds': managerUserIds,
      'playerUserIds': playerUserIds,
    };
  }
}

class TeamAssignment {
  const TeamAssignment({
    required this.id,
    required this.userId,
    required this.teamId,
    required this.leagueId,
    required this.tournamentId,
    required this.role,
    required this.status,
    required this.assignedByUserId,
    this.userEmail = '',
    this.userDisplayName = '',
  });

  final String id;

  final String userId;
  final String userEmail;
  final String userDisplayName;

  final String teamId;
  final String leagueId;
  final String tournamentId;

  final TeamAssignmentRole role;
  final AssignmentStatus status;

  final String assignedByUserId;

  bool get isPending => status == AssignmentStatus.pending;

  bool get isActive => status == AssignmentStatus.active;

  bool get isManager =>
      role == TeamAssignmentRole.teamManager;

  bool get isPlayer =>
      role == TeamAssignmentRole.player;

  factory TeamAssignment.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return TeamAssignment(
      id: id,
      userId: (data['userId'] as String?)?.trim() ?? '',
      userEmail: (data['userEmail'] as String?)?.trim() ?? '',
      userDisplayName:
          (data['userDisplayName'] as String?)?.trim() ?? '',
      teamId: (data['teamId'] as String?)?.trim() ?? '',
      leagueId: (data['leagueId'] as String?)?.trim() ?? '',
      tournamentId:
          (data['tournamentId'] as String?)?.trim() ?? '',
      role: TeamAssignmentRoleX.fromValue(
        data['role'] as String?,
      ),
      status: AssignmentStatusX.fromValue(
        data['status'] as String?,
      ),
      assignedByUserId:
          (data['assignedByUserId'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail.trim().toLowerCase(),
      'userDisplayName': userDisplayName.trim(),
      'teamId': teamId,
      'leagueId': leagueId,
      'tournamentId': tournamentId,
      'role': role.value,
      'status': status.value,
      'assignedByUserId': assignedByUserId,
    };
  }
}

class TeamManagerInvitation {
  const TeamManagerInvitation({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.leagueId,
    required this.tournamentId,
    required this.invitedEmail,
    required this.invitedByUserId,
    required this.status,
    this.invitedUserId = '',
  });

  final String id;

  final String teamId;
  final String teamName;

  final String leagueId;
  final String tournamentId;

  final String invitedEmail;
  final String invitedUserId;

  final String invitedByUserId;

  final AssignmentStatus status;

  bool get isPending => status == AssignmentStatus.pending;

  bool get isAccepted => status == AssignmentStatus.active;

  bool get isRejected => status == AssignmentStatus.rejected;

  factory TeamManagerInvitation.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return TeamManagerInvitation(
      id: id,
      teamId: (data['teamId'] as String?)?.trim() ?? '',
      teamName: (data['teamName'] as String?)?.trim() ?? '',
      leagueId: (data['leagueId'] as String?)?.trim() ?? '',
      tournamentId:
          (data['tournamentId'] as String?)?.trim() ?? '',
      invitedEmail:
          (data['invitedEmail'] as String?)?.trim() ?? '',
      invitedUserId:
          (data['invitedUserId'] as String?)?.trim() ?? '',
      invitedByUserId:
          (data['invitedByUserId'] as String?)?.trim() ?? '',
      status: AssignmentStatusX.fromValue(
        data['status'] as String?,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'teamName': teamName.trim(),
      'leagueId': leagueId,
      'tournamentId': tournamentId,
      'invitedEmail': invitedEmail.trim().toLowerCase(),
      'invitedUserId': invitedUserId,
      'invitedByUserId': invitedByUserId,
      'status': status.value,
    };
  }
}