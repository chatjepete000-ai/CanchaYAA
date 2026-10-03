import '../../auth/domain/user_role.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.adminScope,
    required this.status,
    this.phone = '',
    this.position = FootballPosition.unspecified,
    this.managedLeagueIds = const [],
  });

  final String uid;
  final String displayName;
  final String email;
  final String phone;
  final FootballPosition position;

  final UserRole role;
  final AdminScope adminScope;
  final AccountStatus status;

  final List<String> managedLeagueIds;

  bool get isPlayer => role == UserRole.player;

  bool get isCaptain => role == UserRole.captain;

  bool get isAdmin => role == UserRole.admin;

  bool get isLeagueAdmin => adminScope == AdminScope.league;

  bool get isPlatformAdmin => adminScope == AdminScope.platform;

  factory UserProfile.fromMap(
    String uid,
    Map<String, dynamic> data,
  ) {
    return UserProfile(
      uid: uid,
      displayName: (data['displayName'] as String?)?.trim() ?? '',
      email: (data['email'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim() ?? '',
      position: FootballPositionX.fromValue(
        data['position'] as String?,
      ),
      role: UserRoleX.fromValue(
        data['role'] as String?,
      ),
      adminScope: AdminScopeX.fromValue(
        data['adminScope'] as String?,
      ),
      status: AccountStatusX.fromValue(
        data['status'] as String?,
      ),
      managedLeagueIds: List<String>.from(
        (data['managedLeagueIds'] as List<dynamic>?) ?? const [],
      ),
    );
  }

  Map<String, dynamic> editableFields() {
    return {
      'displayName': displayName.trim(),
      'phone': phone.trim(),
      'position': position.value,
    };
  }
}