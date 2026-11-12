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
}
