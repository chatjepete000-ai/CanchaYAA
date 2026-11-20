import 'package:cancha_ya/features/teams/presentation/teams_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {double width = 320}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'sin equipo solo muestra el mensaje y el botón para unirse',
    (tester) async {
      var joinTaps = 0;

      await tester.pumpWidget(
        _wrap(NoTeamCard(onJoin: () => joinTaps++)),
      );

      expect(
        find.text('Aún no perteneces a ningún equipo'),
        findsOneWidget,
      );
      expect(find.text('Unirme a un equipo'), findsOneWidget);
      expect(find.text('Ver calendario'), findsNothing);
      expect(find.text('Calendario de partidos'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Unirme a un equipo'));
      expect(joinTaps, 1);
    },
  );

  testWidgets(
    'el acceso a Torneos cabe en 320 px y responde al toque',
    (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        _wrap(TournamentsShortcutCard(onTap: () => taps++)),
      );

      expect(find.text('Ir a Torneos'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(TournamentsShortcutCard));
      expect(taps, 1);
    },
  );
}
