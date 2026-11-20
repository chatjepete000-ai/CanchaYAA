import 'package:cancha_ya/features/teams/domain/team_lineup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada formación tiene el número de jugadores de su formato', () {
    const expected = {'football5': 5, 'football7': 7, 'football11': 11};

    expected.forEach((format, count) {
      for (final formation in formationsForFormat(format)) {
        expect(formation.slotCount, count, reason: '$format ${formation.id}');
        expect(formation.positions.length, count);
      }
    });
  });

  test('las posiciones quedan dentro de la cancha y el portero abajo', () {
    for (final formations in lineupFormationsByFormat.values) {
      for (final formation in formations) {
        final positions = formation.positions;

        expect(positions.first.isGoalkeeper, isTrue);

        for (final position in positions) {
          expect(position.x, inInclusiveRange(0, 1));
          expect(position.y, inInclusiveRange(0, 1));
        }

        for (final position in positions.skip(1)) {
          expect(position.y, lessThan(positions.first.y));
        }
      }
    }
  });

  test('colocar un jugador en una posición vacía', () {
    final slots = assignPlayerToSlot(['', '', ''], 1, 'p1');

    expect(slots, ['', 'p1', '']);
  });

  test('mover un jugador no lo duplica: intercambia posiciones', () {
    final slots = assignPlayerToSlot(['p1', 'p2', ''], 1, 'p1');

    expect(slots, ['p2', 'p1', '']);
    expect(hasNoDuplicatePlayers(slots), isTrue);
  });

  test('mover a una posición vacía deja libre la anterior', () {
    final slots = assignPlayerToSlot(['p1', '', ''], 2, 'p1');

    expect(slots, ['', '', 'p1']);
  });

  test('nunca hay duplicados tras muchas asignaciones', () {
    var slots = List<String>.filled(7, '');
    const players = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

    for (var i = 0; i < 60; i++) {
      slots = assignPlayerToSlot(slots, (i * 3) % 7, players[i % players.length]);
      expect(hasNoDuplicatePlayers(slots), isTrue);
    }
  });

  test('índices inválidos no cambian nada', () {
    expect(assignPlayerToSlot(['a'], 5, 'b'), ['a']);
    expect(assignPlayerToSlot(['a'], 0, ''), ['a']);
    expect(clearSlot(['a'], -1), ['a']);
  });

  test('vaciar una posición', () {
    expect(clearSlot(['a', 'b'], 0), ['', 'b']);
  });

  test('cambiar de formación conserva el orden', () {
    expect(resizeSlots(['a', 'b', 'c'], 5), ['a', 'b', 'c', '', '']);
    expect(resizeSlots(['a', 'b', 'c'], 2), ['a', 'b']);
  });

  test('se retiran jugadores que ya no pertenecen al equipo', () {
    expect(
      keepOnlyRosterPlayers(['a', 'x', ''], {'a', 'b'}),
      ['a', '', ''],
    );
  });

  test('detecta duplicados', () {
    expect(hasNoDuplicatePlayers(['a', '', 'a']), isFalse);
    expect(hasNoDuplicatePlayers(['a', '', '', 'b']), isTrue);
  });

  test('alineación guardada con datos incompletos se lee de forma segura', () {
    final lineup = TeamLineup.fromMap('t', {
      'format': 'football5',
      'formation': 'no-existe',
      'slots': ['a', 7, 'b'],
    });

    expect(lineup.formation, '2-2');
    expect(lineup.slots, ['a', '', 'b', '', '']);
    expect(lineup.playerNames, ['', '', '', '', '']);
  });

  test('nombre visible por defecto y recortado', () {
    expect(lineupNameFor('  '), 'Jugador');
    expect(lineupNameFor('x' * 80).length, maxLineupNameLength);
  });

  group('posiciones libres con el dedo', () {
    final formation = formationFor('football5', '2-2');

    test('sin posiciones guardadas se usa la formación', () {
      final lineup = TeamLineup.fromMap('t', {
        'format': 'football5',
        'formation': '2-2',
        'slots': ['a', '', '', '', ''],
      });

      expect(lineup.hasCustomPositions, isFalse);
      expect(lineup.positions.length, formation.slotCount);
      expect(lineup.positions.first.isGoalkeeper, isTrue);
      expect(lineup.positions.first.y, formation.positions.first.y);
    });

    test('lee las posiciones guardadas y conserva al portero', () {
      final lineup = TeamLineup.fromMap('t', {
        'format': 'football5',
        'formation': '2-2',
        'slots': ['a', 'b', '', '', ''],
        'slotX': [0.5, 0.1, 0.9, 0.3, 0.7],
        'slotY': [0.8, 0.6, 0.6, 0.3, 0.2],
      });

      expect(lineup.hasCustomPositions, isTrue);
      expect(lineup.positions[0].isGoalkeeper, isTrue);
      expect(lineup.positions[0].y, 0.8);
      expect(lineup.positions[2].x, 0.9);
    });

    test('posiciones incompletas o inválidas usan la formación', () {
      final short = TeamLineup.fromMap('t', {
        'format': 'football5',
        'formation': '2-2',
        'slots': ['', '', '', '', ''],
        'slotX': [0.5],
        'slotY': [0.5],
      });
      final text = TeamLineup.fromMap('t', {
        'format': 'football5',
        'formation': '2-2',
        'slots': ['', '', '', '', ''],
        'slotX': ['a', 'b', 'c', 'd', 'e'],
        'slotY': [0.1, 0.2, 0.3, 0.4, 0.5],
      });

      expect(short.hasCustomPositions, isFalse);
      expect(text.positions.first.y, formation.positions.first.y);
    });

    test('mover una casilla no se sale de la cancha', () {
      final moved = moveLineupPosition(formation.positions, 1, -3, 9);

      expect(moved[1].x, lineupMinX);
      expect(moved[1].y, lineupMaxY);
      expect(moved[0], same(formation.positions[0]));
      expect(moveLineupPosition(formation.positions, 99, 0.5, 0.5).length,
          formation.slotCount);
    });

    test('se redondea a 3 decimales para guardar', () {
      expect(roundLineupCoordinate(0.123456), 0.123);
    });
  });
}
