import 'user_role.dart';

abstract final class AccessPolicy {
  static bool canCreateTeam({
    required UserRole role,
    required AdminScope adminScope,
  }) {
    return role == UserRole.captain ||
        adminScope == AdminScope.league ||
        adminScope == AdminScope.platform;
  }

  static bool canManageLeague(AdminScope adminScope) {
    return adminScope == AdminScope.league ||
        adminScope == AdminScope.platform;
  }

  static bool canManagePlatform(AdminScope adminScope) {
    return adminScope == AdminScope.platform;
  }

  static bool canSuspendGlobalAccount(AdminScope adminScope) {
    return adminScope == AdminScope.platform;
  }
}
