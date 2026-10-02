import 'package:flutter_test/flutter_test.dart';

import 'package:cancha_ya/features/auth/domain/access_policy.dart';
import 'package:cancha_ya/features/auth/domain/user_role.dart';

void main() {
  group('AccessPolicy', () {
    test('jugador no puede crear equipo', () {
      expect(
        AccessPolicy.canCreateTeam(
          role: UserRole.player,
          adminScope: AdminScope.none,
        ),
        isFalse,
      );
    });

    test('capitan puede crear equipo', () {
      expect(
        AccessPolicy.canCreateTeam(
          role: UserRole.captain,
          adminScope: AdminScope.none,
        ),
        isTrue,
      );
    });

    test('admin de liga no puede suspender cuenta global', () {
      expect(
        AccessPolicy.canSuspendGlobalAccount(AdminScope.league),
        isFalse,
      );
    });

    test('admin de plataforma puede suspender cuenta global', () {
      expect(
        AccessPolicy.canSuspendGlobalAccount(AdminScope.platform),
        isTrue,
      );
    });
  });
}
