import 'package:cloud_firestore/cloud_firestore.dart';

// ================================================================
// F08 · RESULTADOS DE PARTIDOS
// ================================================================
//
// Cada vez que el administrador publica o corrige un marcador se
// guarda una entrada inmutable en:
//
//   tournamentMatches/{matchId}/resultHistory/v{n}
//
// n es el valor de resultVersion del partido después del cambio.
// Así se registra quién, cuándo, por qué y qué marcador había antes.
// ================================================================

/// Marcador máximo permitido (coincide con firestore.rules).
const int maxMatchScore = 99;

/// Longitud mínima del motivo de una corrección.
const int minCorrectionReasonLength = 5;

/// Longitud máxima del motivo.
const int maxResultReasonLength = 240;

enum MatchResultAction {
  published,
  corrected,
}

extension MatchResultActionX on MatchResultAction {
  String get value => name;

  String get label {
    switch (this) {
      case MatchResultAction.published:
        return 'Resultado publicado';
      case MatchResultAction.corrected:
        return 'Resultado corregido';
    }
  }

  static MatchResultAction fromValue(
    String? value,
  ) {
    return MatchResultAction.values.firstWhere(
      (action) => action.name == value,
      orElse: () => MatchResultAction.published,
    );
  }
}

class MatchResultHistoryEntry {
  const MatchResultHistoryEntry({
    required this.id,
    required this.version,
    required this.action,
    required this.homeScore,
    required this.awayScore,
    required this.changedByUserId,
    this.previousHomeScore,
    this.previousAwayScore,
    this.reason = '',
    this.changedAt,
  });

  final String id;
  final int version;
  final MatchResultAction action;
  final int homeScore;
  final int awayScore;
  final int? previousHomeScore;
  final int? previousAwayScore;
  final String reason;
  final String changedByUserId;
  final DateTime? changedAt;

  bool get hasPreviousScore =>
      previousHomeScore != null &&
      previousAwayScore != null;

  factory MatchResultHistoryEntry.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final changedAt = data['changedAt'];

    return MatchResultHistoryEntry(
      id: id,
      version: versionFromEntryId(id),
      action: MatchResultActionX.fromValue(
        data['action'] as String?,
      ),
      homeScore:
          (data['homeScore'] as num?)?.toInt() ?? 0,
      awayScore:
          (data['awayScore'] as num?)?.toInt() ?? 0,
      previousHomeScore:
          (data['previousHomeScore'] as num?)?.toInt(),
      previousAwayScore:
          (data['previousAwayScore'] as num?)?.toInt(),
      reason:
          (data['reason'] as String?)?.trim() ?? '',
      changedByUserId:
          (data['changedByUserId'] as String?) ?? '',
      changedAt: changedAt is Timestamp
          ? changedAt.toDate()
          : null,
    );
  }

  static String entryIdForVersion(
    int version,
  ) {
    return 'v$version';
  }

  static int versionFromEntryId(
    String id,
  ) {
    if (!id.startsWith('v')) {
      return 0;
    }

    return int.tryParse(
          id.substring(1),
        ) ??
        0;
  }
}

/// Valida un marcador capturado con los selectores.
///
/// Devuelve un mensaje de error o null si es válido.
String? validateMatchScore(
  int? score,
) {
  if (score == null) {
    return 'Selecciona los goles.';
  }

  if (score < 0) {
    return 'Los goles no pueden ser negativos.';
  }

  if (score > maxMatchScore) {
    return 'El máximo permitido es $maxMatchScore goles.';
  }

  return null;
}

/// Valida el motivo obligatorio de una corrección.
String? validateCorrectionReason(
  String reason,
) {
  final clean = reason.trim();

  if (clean.length < minCorrectionReasonLength) {
    return 'Explica el motivo de la corrección '
        '(mínimo $minCorrectionReasonLength caracteres).';
  }

  if (clean.length > maxResultReasonLength) {
    return 'El motivo admite máximo $maxResultReasonLength caracteres.';
  }

  return null;
}
