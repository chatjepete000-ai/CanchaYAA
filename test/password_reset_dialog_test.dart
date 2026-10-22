import 'package:cancha_ya/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    ValueChanged<String?> onResult, {
    String email = '',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  onResult(
                    await showDialog<String>(
                      context: context,
                      builder: (_) => PasswordResetDialog(initialEmail: email),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('rechaza correo vacío o inválido sin cerrar', (tester) async {
    var submitted = false;
    await openDialog(tester, (_) => submitted = true);
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    expect(find.byType(PasswordResetDialog), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'usuario@');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    expect(submitted, isFalse);
    expect(find.byType(PasswordResetDialog), findsOneWidget);
  });

  testWidgets('precarga el correo y devuelve el valor sin espacios', (
    tester,
  ) async {
    String? result;
    await openDialog(
      tester,
      (value) => result = value,
      email: 'jugador@gmail.com',
    );
    expect(find.text('jugador@gmail.com'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '  jugador@gmail.com  ');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    expect(result, 'jugador@gmail.com');
    expect(find.byType(PasswordResetDialog), findsNothing);
  });

  testWidgets('cancelar no solicita enviar un correo', (tester) async {
    String? result = 'sin respuesta';
    await openDialog(tester, (value) => result = value);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
