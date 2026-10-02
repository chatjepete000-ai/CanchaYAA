enum UserRole {
  player,
  captain,
  admin,
}

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.player:
        return 'Jugador';
      case UserRole.captain:
        return 'Capitán';
      case UserRole.admin:
        return 'Administrador';
    }
  }
}
