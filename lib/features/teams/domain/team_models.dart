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

  static TeamStatus fromValue(
    String? value,
  ) {
    return TeamStatus.values.firstWhere(
      (status) =>
          status.name == value,
      orElse: () =>
          TeamStatus.active,
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

extension AssignmentStatusX
    on AssignmentStatus {
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

  static AssignmentStatus fromValue(
    String? value,
  ) {
    return AssignmentStatus.values.firstWhere(
      (status) =>
          status.name == value,
      orElse: () =>
          AssignmentStatus.pending,
    );
  }
}

enum TeamAssignmentRole {
  player,
  teamManager,
}

extension TeamAssignmentRoleX
    on TeamAssignmentRole {
  String get value => name;

  String get label {
    switch (this) {
      case TeamAssignmentRole.player:
        return 'Jugador';

      case TeamAssignmentRole.teamManager:
        return 'Encargado de equipo';
    }
  }

  static TeamAssignmentRole fromValue(
    String? value,
  ) {
    return TeamAssignmentRole.values.firstWhere(
      (role) =>
          role.name == value,
      orElse: () =>
          TeamAssignmentRole.player,
    );
  }
}

// ================================================================
// EQUIPO
// ================================================================

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.leagueId,
    required this.tournamentId,
    required this.status,
    this.shortName = '',
    this.logoUrl = '',
    this.uniformDescription = '',
    this.managerUserIds = const [],
    this.playerUserIds = const [],
  });

  final String id;

  // ============================================================
  // INFORMACIÓN PRINCIPAL
  // ============================================================

  /// Nombre oficial completo.
  ///
  /// Ejemplo:
  /// Los Diablos De La Emiliano
  final String name;

  /// Nombre corto que puede elegir el encargado.
  ///
  /// Ejemplo:
  /// Diablos Emiliano
  ///
  /// Si este campo está vacío, la interfaz puede crear
  /// automáticamente una versión compacta del nombre oficial.
  final String shortName;

  final String leagueId;

  final String tournamentId;

  /// URL del escudo oficial del equipo.
  final String logoUrl;

  /// Descripción del uniforme.
  final String uniformDescription;

  final TeamStatus status;

  // ============================================================
  // RELACIONES INTERNAS
  // ============================================================

  final List<String> managerUserIds;

  final List<String> playerUserIds;

  // ============================================================
  // HELPERS
  // ============================================================

  bool get hasManager =>
      managerUserIds.isNotEmpty;

  int get totalPlayers =>
      playerUserIds.length;

  bool get hasLogo =>
      logoUrl.trim().isNotEmpty;

  bool get hasShortName =>
      shortName.trim().isNotEmpty;

  /// Nombre recomendado para espacios pequeños.
  ///
  /// Ejemplo:
  ///
  /// Nombre oficial:
  /// Los Diablos De La Emiliano
  ///
  /// Nombre corto:
  /// Diablos Emiliano
  ///
  /// Si `shortName` está vacío, se genera uno automáticamente.
  String get displayName {
    final cleanShortName =
        shortName.trim();

    if (cleanShortName.isNotEmpty) {
      return cleanShortName;
    }

    return compactName(
      name,
    );
  }

  // ============================================================
  // FIRESTORE
  // ============================================================

  factory Team.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return Team(
      id: id,

      name:
          _readString(
        data['name'],
      ),

      // IMPORTANTE:
      //
      // Los equipos creados antes de esta mejora todavía no
      // tienen shortName.
      //
      // Por eso un campo inexistente simplemente produce ''.
      shortName:
          _readString(
        data['shortName'],
      ),

      leagueId:
          _readString(
        data['leagueId'],
      ),

      tournamentId:
          _readString(
        data['tournamentId'],
      ),

      logoUrl:
          _readString(
        data['logoUrl'],
      ),

      uniformDescription:
          _readString(
        data['uniformDescription'],
      ),

      status:
          TeamStatusX.fromValue(
        data['status'] as String?,
      ),

      managerUserIds:
          _readStringList(
        data['managerUserIds'],
      ),

      playerUserIds:
          _readStringList(
        data['playerUserIds'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name':
          name.trim(),

      'shortName':
          shortName.trim(),

      'leagueId':
          leagueId.trim(),

      'tournamentId':
          tournamentId.trim(),

      'logoUrl':
          logoUrl.trim(),

      'uniformDescription':
          uniformDescription.trim(),

      'status':
          status.value,

      'managerUserIds':
          managerUserIds,

      'playerUserIds':
          playerUserIds,
    };
  }

  // ============================================================
  // COPIA DEL MODELO
  // ============================================================
  //
  // Esto nos servirá cuando el encargado cambie:
  //
  // - nombre corto
  // - escudo
  // - uniforme
  //
  // sin tener que reconstruir manualmente todo el Team.
  // ============================================================

  Team copyWith({
    String? name,
    String? shortName,
    String? leagueId,
    String? tournamentId,
    String? logoUrl,
    String? uniformDescription,
    TeamStatus? status,
    List<String>? managerUserIds,
    List<String>? playerUserIds,
  }) {
    return Team(
      id: id,
      name:
          name ?? this.name,
      shortName:
          shortName ??
              this.shortName,
      leagueId:
          leagueId ??
              this.leagueId,
      tournamentId:
          tournamentId ??
              this.tournamentId,
      logoUrl:
          logoUrl ??
              this.logoUrl,
      uniformDescription:
          uniformDescription ??
              this.uniformDescription,
      status:
          status ??
              this.status,
      managerUserIds:
          managerUserIds ??
              this.managerUserIds,
      playerUserIds:
          playerUserIds ??
              this.playerUserIds,
    );
  }

  // ============================================================
  // NOMBRE COMPACTO AUTOMÁTICO
  // ============================================================

  static String compactName(
    String value,
  ) {
    final clean =
        value.trim();

    if (clean.isEmpty) {
      return 'Equipo';
    }

    if (clean.length <= 18) {
      return clean;
    }

    const removableWords =
        <String>{
      'el',
      'la',
      'los',
      'las',
      'de',
      'del',
    };

    final words =
        clean
            .split(
              RegExp(
                r'\s+',
              ),
            )
            .where(
              (
                word,
              ) =>
                  !removableWords
                      .contains(
                word.toLowerCase(),
              ),
            )
            .toList();

    final compact =
        words.join(
      ' ',
    );

    if (compact.length <= 20) {
      return compact;
    }

    if (words.length >= 2) {
      final firstAndLast =
          '${words.first} ${words.last}';

      if (firstAndLast.length <= 20) {
        return firstAndLast;
      }
    }

    if (clean.length <= 20) {
      return clean;
    }

    return '${clean.substring(0, 17)}...';
  }

  // ============================================================
  // LECTORES SEGUROS
  // ============================================================

  static String _readString(
    dynamic value,
  ) {
    if (value is! String) {
      return '';
    }

    return value.trim();
  }

  static List<String>
      _readStringList(
    dynamic value,
  ) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .whereType<String>()
        .map(
          (
            item,
          ) =>
              item.trim(),
        )
        .where(
          (
            item,
          ) =>
              item.isNotEmpty,
        )
        .toList();
  }
}

// ================================================================
// ASIGNACIÓN DE EQUIPO
// ================================================================

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

  bool get isPending =>
      status ==
      AssignmentStatus.pending;

  bool get isActive =>
      status ==
      AssignmentStatus.active;

  bool get isManager =>
      role ==
      TeamAssignmentRole.teamManager;

  bool get isPlayer =>
      role ==
      TeamAssignmentRole.player;

  factory TeamAssignment.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return TeamAssignment(
      id: id,

      userId:
          _readString(
        data['userId'],
      ),

      userEmail:
          _readString(
        data['userEmail'],
      ),

      userDisplayName:
          _readString(
        data['userDisplayName'],
      ),

      teamId:
          _readString(
        data['teamId'],
      ),

      leagueId:
          _readString(
        data['leagueId'],
      ),

      tournamentId:
          _readString(
        data['tournamentId'],
      ),

      role:
          TeamAssignmentRoleX.fromValue(
        data['role'] as String?,
      ),

      status:
          AssignmentStatusX.fromValue(
        data['status'] as String?,
      ),

      assignedByUserId:
          _readString(
        data['assignedByUserId'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId':
          userId,

      'userEmail':
          userEmail
              .trim()
              .toLowerCase(),

      'userDisplayName':
          userDisplayName.trim(),

      'teamId':
          teamId,

      'leagueId':
          leagueId,

      'tournamentId':
          tournamentId,

      'role':
          role.value,

      'status':
          status.value,

      'assignedByUserId':
          assignedByUserId,
    };
  }

  static String _readString(
    dynamic value,
  ) {
    if (value is! String) {
      return '';
    }

    return value.trim();
  }
}

// ================================================================
// INVITACIÓN A ENCARGADO
// ================================================================

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

  bool get isPending =>
      status ==
      AssignmentStatus.pending;

  bool get isAccepted =>
      status ==
      AssignmentStatus.active;

  bool get isRejected =>
      status ==
      AssignmentStatus.rejected;

  factory TeamManagerInvitation.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return TeamManagerInvitation(
      id: id,

      teamId:
          _readString(
        data['teamId'],
      ),

      teamName:
          _readString(
        data['teamName'],
      ),

      leagueId:
          _readString(
        data['leagueId'],
      ),

      tournamentId:
          _readString(
        data['tournamentId'],
      ),

      invitedEmail:
          _readString(
        data['invitedEmail'],
      ),

      invitedUserId:
          _readString(
        data['invitedUserId'],
      ),

      invitedByUserId:
          _readString(
        data['invitedByUserId'],
      ),

      status:
          AssignmentStatusX.fromValue(
        data['status'] as String?,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'teamId':
          teamId,

      'teamName':
          teamName.trim(),

      'leagueId':
          leagueId,

      'tournamentId':
          tournamentId,

      'invitedEmail':
          invitedEmail
              .trim()
              .toLowerCase(),

      'invitedUserId':
          invitedUserId,

      'invitedByUserId':
          invitedByUserId,

      'status':
          status.value,
    };
  }

  static String _readString(
    dynamic value,
  ) {
    if (value is! String) {
      return '';
    }

    return value.trim();
  }
}