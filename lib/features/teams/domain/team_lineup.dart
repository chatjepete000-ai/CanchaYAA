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
//   slotX, slotY  posición libre de cada casilla en la cancha
//                 (0..1). Opcional: sin ellas se usa el acomodo de
//                 la formación. El encargado las cambia con el dedo.
//   playerPhotoUrls  foto de la cara de cada posición ('' = sin
//                 foto). Opcional: alineaciones anteriores no la
//                 tienen.
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
// POSICIONES LIBRES (el encargado acomoda con el dedo)
// ================================================================

/// Margen para que la ficha del jugador no se salga de la cancha.
const double lineupMinX = 0.07;
const double lineupMaxX = 0.93;
const double lineupMinY = 0.05;
const double lineupMaxY = 0.95;

/// Mantiene un punto dentro de la cancha.
LineupSlotPosition clampLineupPosition(
  double x,
  double y, {
  bool isGoalkeeper = false,
}) {
  double fix(double value, double min, double max) =>
      value.isFinite ? value.clamp(min, max).toDouble() : (min + max) / 2;

  return LineupSlotPosition(
    x: fix(x, lineupMinX, lineupMaxX),
    y: fix(y, lineupMinY, lineupMaxY),
    isGoalkeeper: isGoalkeeper,
  );
}

/// Posiciones a mostrar: las libres guardadas si son válidas y
/// coinciden con las casillas; si no, las de la formación.
List<LineupSlotPosition> resolveLineupPositions(
  LineupFormation formation,
  List<double>? slotX,
  List<double>? slotY,
) {
  final base = formation.positions;

  if (slotX == null ||
      slotY == null ||
      slotX.length != base.length ||
      slotY.length != base.length) {
    return base;
  }

  return [
    for (var i = 0; i < base.length; i++)
      clampLineupPosition(
        slotX[i],
        slotY[i],
        isGoalkeeper: base[i].isGoalkeeper,
      ),
  ];
}

/// Mueve la casilla [index] a un punto nuevo (ya ajustado a la cancha).
List<LineupSlotPosition> moveLineupPosition(
  List<LineupSlotPosition> positions,
  int index,
  double x,
  double y,
) {
  if (index < 0 || index >= positions.length) {
    return List<LineupSlotPosition>.of(positions);
  }

  final result = List<LineupSlotPosition>.of(positions);

  result[index] = clampLineupPosition(
    x,
    y,
    isGoalkeeper: positions[index].isGoalkeeper,
  );

  return result;
}

/// Redondea para guardar (3 decimales bastan en cualquier pantalla).
double roundLineupCoordinate(double value) =>
    (value * 1000).roundToDouble() / 1000;

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
    this.playerPhotoUrls = const <String>[],
    this.slotX,
    this.slotY,
    this.updatedAt,
  });

  final String teamId;
  final String format;
  final String formation;
  final List<String> slots;
  final List<String> playerNames;

  /// Misma longitud que [slots] cuando viene de Firestore.
  final List<String> playerPhotoUrls;

  /// Posición libre de cada casilla (null = acomodo de la formación).
  final List<double>? slotX;
  final List<double>? slotY;
  final DateTime? updatedAt;

  /// Posiciones a dibujar en la cancha.
  List<LineupSlotPosition> get positions => resolveLineupPositions(
        formationFor(format, formation),
        slotX,
        slotY,
      );

  bool get hasCustomPositions =>
      slotX != null && slotX!.length == slots.length;

  /// Foto de la posición [index] o '' si no hay.
  String photoAt(int index) =>
      index >= 0 && index < playerPhotoUrls.length
          ? playerPhotoUrls[index]
          : '';

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

    List<double>? readNumbers(dynamic value) {
      if (value is! List || value.length != formation.slotCount) {
        return null;
      }

      final numbers = <double>[];

      for (final item in value) {
        if (item is! num || !item.toDouble().isFinite) return null;
        numbers.add(item.toDouble());
      }

      return numbers;
    }

    return TeamLineup(
      teamId: teamId,
      format: format,
      formation: formation.id,
      slots: readList(data['slots']),
      playerNames: readList(data['playerNames']),
      playerPhotoUrls: readList(data['playerPhotoUrls']),
      slotX: readNumbers(data['slotX']),
      slotY: readNumbers(data['slotY']),
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
