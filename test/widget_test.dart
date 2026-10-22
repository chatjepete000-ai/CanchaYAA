import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cancha_ya/core/theme/app_theme.dart';
import 'package:cancha_ya/core/theme/theme_controller.dart';
import 'package:cancha_ya/features/home/presentation/home_shell.dart';

void main() {
  testWidgets('CanchaYA muestra navegación principal', (tester) async {
    final theme = ThemeController(initialMode: ThemeMode.light);
    addTearDown(theme.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeShell(themeController: theme),
      ),
    );
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Equipos'), findsWidgets);
    expect(find.text('Torneos'), findsWidgets);
    final explore = find.text('Explorar canchas en Montemorelos');
    await tester.scrollUntilVisible(
      explore,
      250,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(tester.element(explore), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(explore);
    await tester.pumpAndSettle();
    expect(find.text('Explorar canchas'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
  });
}
