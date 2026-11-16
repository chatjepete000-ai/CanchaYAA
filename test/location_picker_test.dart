import 'package:cancha_ya/features/location/presentation/location_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Elige tu ciudad muestra la ciudad actual y Montemorelos',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: LocationPickerScreen()),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Elige tu ciudad'), findsOneWidget);
    expect(find.text('Ciudad actual'), findsOneWidget);
    expect(find.text('Montemorelos, N.L.'), findsOneWidget);
    expect(find.text('Ciudades con canchas en CanchaYA'), findsOneWidget);
    expect(find.text('Busca tu ciudad o municipio'), findsOneWidget);
  });

  testWidgets('con menos de 3 letras no busca', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LocationPickerScreen()),
    );

    await tester.enterText(find.byType(TextField), 'Li');
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Resultados en México'), findsNothing);
  });
}
