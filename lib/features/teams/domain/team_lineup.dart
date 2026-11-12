import 'package:cloud_firestore/cloud_firestore.dart';

// ================================================================
// F04 · ALINEACIÓN VISUAL
// ================================================================
//
// teamLineups/{teamId}
//
//   teamId, leagueId, tournamentId
//   format        football5 | football7 | football11
//   formation     '2-3-1', '4-4-2', ...
//   slots         lista de userId por posición ('' = vacía).
//                 Índice 0 = portero; después cada línea de
//                 defensa a ataque, de izquierda a derecha.
//   playerNames   nombre visible de cada posición (para que los
//                 jugadores vean y exporten la alineación sin
//                 consultar datos privados).
//   updatedByUserId, updatedAt
//
// Solo el encargado del equipo la modifica (firestore.rules).
// Un mismo jugador no puede ocupar dos posiciones.
// ================================================================

/// Longitud máxima del nombre visible guardado por posición.
const int maxLineupNameLength = 60;

class LineupFormation {
  const LineupFormation({
    required this.id,
    required this.lines,
  });

  /// Identificador legible, por ejemplo '2-3-1'.
  final String id;

  /// Jugadores por línea (sin portero), de defensa a ataque.
  final List<int> lines;

  /// Total de posiciones, incluido el portero.
  int get slotCount =>
      1 + lines.fold<int>(0, (total, players) => total + players);

  /// Posición relativa (0..1) de cada casilla en la cancha.
  ///
  /// x: 0 izquierda, 1 derecha. y: 0 arriba (ataque), 1 abajo
  /// (portería propia).
  List<LineupSlotPosition> get positions {
    final result = <LineupSlotPosition>[
      const LineupSlotPosition(x: 0.5, y: 0.9, isGoalkeeper: true),
    ];

    final lineCount = lines.length;

    for (var line = 0; line < lineCount; line++) {
      // Defensa cerca de la portería, ataque arriba.
      final y = lineCount == 1
          ? 0.45
          : 0.72 - (0.58 * line / (lineCount - 1));

      final players = lines[line];

      for (var index = 0; index < players; index++) {
        final x = (index + 1) / (players + 1);
        result.add(LineupSlotPosition(x: x, y: y));
      }
    }

    return result;
  }
}

class LineupSlotPosition {
  const LineupSlotPosition({
    required this.x,
    required this.y,
    this.isGoalkeeper = false,
  });

  final double x;
  final double y;
  final bool isGoalkeeper;
}

/// Formaciones disponibles por formato de torneo.
const Map<String, List<LineupFormation>> lineupFormationsByFormat = {
  'football5': [
    LineupFormation(id: '2-2', lines: [2, 2]),
    LineupFormation(id: '1-2-1', lines: [1, 2, 1]),
  ],
  'football7': [
    LineupFormation(id: '2-3-1', lines: [2, 3, 1]),
    LineupFormation(id: '3-2-1', lines: [3, 2, 1]),
    LineupFormation(id: '3-1-2', lines: [3, 1, 2]),
  ],
  'football11': [
    LineupFormation(id: '4-4-2', lines: [4, 4, 2]),
    LineupFormation(id: '4-3-3', lines: [4, 3, 3]),
    LineupFormation(id: '3-5-2', lines: [3, 5, 2]),
  ],
};

/// Formato por defecto si el torneo no se puede consultar.
const String defaultLineupFormat = 'football7';

List<LineupFormation> formationsForFormat(String format) {
  return lineupFormationsByFormat[format] ??
      lineupFormationsByFormat[defaultLineupFormat]!;
}

LineupFormation formationFor(String format, String formationId) {
  final options = formationsForFormat(format);

  return options.firstWhere(
    (formation) => formation.id == formationId,
    orElse: () => options.first,
  );
}

// ================================================================
// LÓGICA DE ASIGNACIÓN (sin duplicados)
// ================================================================

/// Coloca [playerId] en [slotIndex].
///
/// - Si el jugador ya estaba en otra posición, se intercambia con
///   quien ocupaba [slotIndex] (o esa posición queda vacía).
/// - Nunca deja al mismo jugador en dos posiciones.
List<String> assignPlayerToSlot(
  List<String> slots,
  int slotIndex,
  String playerId,
) {
  if (slotIndex < 0 || slotIndex >= slots.length || playerId.isEmpty) {
    return List<String>.of(slots);
  }

  final result = List<String>.of(slots);
  final previousIndex = result.indexOf(playerId);
  final displaced = result[slotIndex];

  result[slotIndex] = playerId;

  if (previousIndex != -1 && previousIndex != slotIndex) {
    result[previousIndex] = displaced;
  }

  return result;
}

/// Deja vacía la posición [slotIndex].
List<String> clearSlot(
  List<String> slots,
  int slotIndex,
) {
  final result = List<String>.of(slots);

  if (slotIndex >= 0 && slotIndex < result.length) {
    result[slotIndex] = '';
  }

  return result;
}

/// Adapta las posiciones a una formación con otro número de
/// casillas: conserva el orden y descarta lo que no cabe.
List<String> resizeSlots(
  List<String> slots,
  int slotCount,
) {
  return List<String>.generate(
    slotCount,
    (index) => index < slots.length ? slots[index] : '',
  );
}

/// Quita de la alineación a quien ya no pertenece al equipo.
List<String> keepOnlyRosterPlayers(
  List<String> slots,
  Set<String> rosterIds,
) {
  return [
    for (final id in slots) rosterIds.contains(id) ? id : '',
  ];
}

/// true si ningún jugador aparece dos veces.
bool hasNoDuplicatePlayers(List<String> slots) {
  final filled = slots.where((id) => id.isNotEmpty).toList();

  return filled.toSet().length == filled.length;
}

// ================================================================
// MODELO
// ================================================================

class TeamLineup {
  const TeamLineup({
    required this.teamId,
    required this.format,
    required this.formation,
    required this.slots,
    required this.playerNames,
    this.updatedAt,
  });

  final String teamId;
  final String format;
  final String formation;
  final List<String> slots;
  final List<String> playerNames;
  final DateTime? updatedAt;

  int get filledCount => slots.where((id) => id.isNotEmpty).length;

  factory TeamLineup.empty({
    required String teamId,
    required String format,
  }) {
    final formation = formationsForFormat(format).first;

    return TeamLineup(
      teamId: teamId,
      format: format,
      formation: formation.id,
      slots: List<String>.filled(formation.slotCount, ''),
      playerNames: List<String>.filled(formation.slotCount, ''),
    );
  }

  factory TeamLineup.fromMap(
    String teamId,
    Map<String, dynamic> data,
  ) {
    final format =
        (data['format'] as String?) ?? defaultLineupFormat;

    final formation = formationFor(
      format,
      (data['formation'] as String?) ?? '',
    );

    List<String> readList(dynamic value) {
      final list = value is List
          ? value.map((item) => item is String ? item : '').toList()
          : <String>[];

      return resizeSlots(list, formation.slotCount);
    }

    final updatedAt = data['updatedAt'];

    return TeamLineup(
      teamId: teamId,
      format: format,
      formation: formation.id,
      slots: readList(data['slots']),
      playerNames: readList(data['playerNames']),
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }
}

/// Nombre que se guarda para una posición.
String lineupNameFor(String displayName) {
  final clean = displayName.trim();

  if (clean.isEmpty) {
    return 'Jugador';
  }

  if (clean.length <= maxLineupNameLength) {
    return clean;
  }

  return clean.substring(0, maxLineupNameLength);
}
