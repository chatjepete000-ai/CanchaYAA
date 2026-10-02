import 'package:flutter_test/flutter_test.dart';

import 'package:cancha_ya/features/auth/domain/auth_validators.dart';

void main() {
  group('AuthValidators.email', () {
    test('rechaza correo vacío', () {
      expect(AuthValidators.email(''), isNotNull);
    });

    test('rechaza correo inválido', () {
      expect(AuthValidators.email('usuario@'), isNotNull);
    });

    test('acepta correo válido', () {
      expect(AuthValidators.email('jugador@cancha.mx'), isNull);
    });
  });

  group('AuthValidators.password', () {
    test('rechaza contraseña débil', () {
      expect(AuthValidators.password('12345678'), isNotNull);
    });

    test('acepta contraseña con requisitos mínimos', () {
      expect(AuthValidators.password('CanchaYA#2026'), isNull);
    });
  });

  test('confirmPassword exige coincidencia', () {
    expect(
      AuthValidators.confirmPassword('Otra#2026', 'CanchaYA#2026'),
      isNotNull,
    );
  });
}
