// ================================================================
// ESTADOS DE UN PARTIDO
// ================================================================
//
//   scheduled  Programado (con o sin cancha y horario).
//   postponed  Suspendido: por clima, cancha u otro motivo. Se libera
//              la cancha y queda pendiente de reprogramar. No cuenta
//              en la tabla hasta que se juegue.
//   cancelled  Cancelado: definitivo. Libera la cancha, no se puede
//              reprogramar ni capturar resultado y no cuenta en la
//              tabla.
//   completed  Finalizado con resultado (cuenta en la tabla).
//
// El motivo se guarda en statusReason (weather | court | other) y una
// nota opcional en statusNote (hasta 140 caracteres).
// ================================================================

/// Longitud máxima de la nota del motivo.
const int maxMatchStatusNoteLength = 140;

enum MatchStatusReason { weather, court, other }

extension MatchStatusReasonX on MatchStatusReason {
  String get value {
    switch (this) {
      case MatchStatusReason.weather:
        return 'weather';
      case MatchStatusReason.court:
        return 'court';
      case MatchStatusReason.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case MatchStatusReason.weather:
        return 'Clima';
      case MatchStatusReason.court:
        return 'Cancha no disponible';
      case MatchStatusReason.other:
        return 'Otro motivo';
    }
  }

  static MatchStatusReason? fromValue(String? value) {
    switch (value) {
      case 'weather':
        return MatchStatusReason.weather;
      case 'court':
        return MatchStatusReason.court;
      case 'other':
        return MatchStatusReason.other;
      default:
        return null;
    }
  }
}

/// Texto del estado para mostrar en calendario y tarjetas.
String matchStatusLabel(String status) {
  switch (status) {
    case 'postponed':
      return 'Suspendido';
    case 'cancelled':
      return 'Cancelado';
    case 'completed':
      return 'Finalizado';
    default:
      return 'Programado';
  }
}

/// "Suspendido · Clima (tormenta eléctrica)"
String matchStatusDetail({
  required String status,
  String? reason,
  String? note,
}) {
  final label = matchStatusLabel(status);
  final reasonLabel = MatchStatusReasonX.fromValue(reason)?.label;
  final cleanNote = (note ?? '').trim();

  if (reasonLabel == null) return label;

  return cleanNote.isEmpty
      ? '$label · $reasonLabel'
      : '$label · $reasonLabel ($cleanNote)';
}

/// Limpia la nota: sin saltos de línea y del largo permitido.
String cleanMatchStatusNote(String note) {
  final clean = note.replaceAll(RegExp(r'\s+'), ' ').trim();

  return clean.length <= maxMatchStatusNoteLength
      ? clean
      : clean.substring(0, maxMatchStatusNoteLength);
}
