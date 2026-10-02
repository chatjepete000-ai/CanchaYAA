enum UserRole {
  player,
  captain,
  admin,
}

extension UserRoleX on UserRole {
  String get value => name;

  String get label {
    switch (this) {
      case UserRole.player:
        return 'Jugador';
      case UserRole.captain:
        return 'Capitán / Encargado';
      case UserRole.admin:
        return 'Administrador';
    }
  }

  static UserRole fromValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.player,
    );
  }
}

enum AdminScope {
  none,
  league,
  platform,
}

extension AdminScopeX on AdminScope {
  String get value => name;

  String get label {
    switch (this) {
      case AdminScope.none:
        return 'Sin administración';
      case AdminScope.league:
        return 'Administrador de liga';
      case AdminScope.platform:
        return 'Administrador de plataforma';
    }
  }

  static AdminScope fromValue(String? value) {
    return AdminScope.values.firstWhere(
      (scope) => scope.name == value,
      orElse: () => AdminScope.none,
    );
  }
}

enum AccountStatus {
  active,
  suspended,
}

extension AccountStatusX on AccountStatus {
  String get value => name;

  static AccountStatus fromValue(String? value) {
    return AccountStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AccountStatus.active,
    );
  }
}

enum FootballPosition {
  unspecified,
  goalkeeper,
  defender,
  fullback,
  midfielder,
  winger,
  forward,
}

extension FootballPositionX on FootballPosition {
  String get value => name;

  String get label {
    switch (this) {
      case FootballPosition.unspecified:
        return 'Sin definir';
      case FootballPosition.goalkeeper:
        return 'Portero';
      case FootballPosition.defender:
        return 'Defensa';
      case FootballPosition.fullback:
        return 'Lateral';
      case FootballPosition.midfielder:
        return 'Mediocampista';
      case FootballPosition.winger:
        return 'Extremo';
      case FootballPosition.forward:
        return 'Delantero';
    }
  }

  static FootballPosition fromValue(String? value) {
    return FootballPosition.values.firstWhere(
      (position) => position.name == value,
      orElse: () => FootballPosition.unspecified,
    );
  }
}
