import 'package:cancha_ya/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el acceso admite una contraseña creada por recuperación', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'jugador@gmail.com');
    await tester.enterText(fields.at(1), 'nueva123');
    // Firebase validates credentials; registration complexity rules must not
    // prevent submitting a password accepted by the hosted reset page.
    expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
    await tester.enterText(fields.at(1), '');
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.pump();
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });
}
