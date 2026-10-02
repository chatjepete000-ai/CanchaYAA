import 'package:flutter_test/flutter_test.dart';

import 'package:cancha_ya/app/app.dart';

void main() {
  testWidgets('CanchaYA muestra navegación principal', (tester) async {
    await tester.pumpWidget(const CanchaYaApp());

    expect(find.textContaining('CanchaYA'), findsWidgets);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Equipos'), findsOneWidget);
    expect(find.text('Torneos'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });
}
