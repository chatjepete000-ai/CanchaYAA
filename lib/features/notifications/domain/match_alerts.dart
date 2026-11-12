// ================================================================
// F06 · AVISOS Y RECORDATORIOS DE PARTIDOS (lógica pura)
// ================================================================
//
// Criterio de aceptación (plan, sección 3):
// - Avisar cuando se programa o cambia un partido.
// - Recordar 24 horas y 1 hora antes (si hay tiempo) y avisar al
//   inicio.
// - Reprogramar los avisos si cambia el partido.
// - Evitar que se repitan por un reintento.
//
// Los identificadores son deterministas: el mismo aviso siempre
// tiene el mismo ID, así que reintentar no lo duplica (Firestore
// rechaza crear un documento que ya existe y el teléfono reemplaza
// una notificación programada con el mismo ID).
// ================================================================

enum MatchReminderKind {
  dayBefore,
  hourBefore,
  kickoff,
}

extension MatchReminderKindX on MatchReminderKind {
  /// Clave corta usada en IDs y en firestore.rules.
  String get key {
    switch (this) {
      case MatchReminderKind.dayBefore:
        return 'r24';
      case MatchReminderKind.hourBefore:
        return 'r1';
      case MatchReminderKind.kickoff:
        return 'r0';
    }
  }

  Duration get offset {
    switch (this) {
      case MatchReminderKind.dayBefore:
        return const Duration(hours: 24);
      case MatchReminderKind.hourBefore:
        return const Duration(hours: 1);
      case MatchReminderKind.kickoff:
        return Duration.zero;
    }
  }
}

/// Momento en que debe sonar un recordatorio.
DateTime reminderFireTime(
  DateTime startsAt,
  MatchReminderKind kind,
) {
  return startsAt.subtract(kind.offset);
}

/// Recordatorios que todavía tienen tiempo de sonar.
///
/// Si el partido se programa con menos de 24 horas de anticipación,
/// el aviso de 24 horas se omite ("si hay tiempo para eso").
List<MatchReminderKind> upcomingReminders(
  DateTime startsAt,
  DateTime now,
) {
  return [
    for (final kind in MatchReminderKind.values)
      if (reminderFireTime(startsAt, kind).isAfter(now)) kind,
  ];
}

/// Recordatorios que ya debieron sonar y deben aparecer en la
/// bandeja (se registran cuando el usuario abre la app).
///
/// Solo se consideran los de las últimas [window] horas para no
/// llenar la bandeja con partidos viejos.
List<MatchReminderKind> dueReminders(
  DateTime startsAt,
  DateTime now, {
  Duration window = const Duration(hours: 30),
}) {
  return [
    for (final kind in MatchReminderKind.values)
      if (!reminderFireTime(startsAt, kind).isAfter(now) &&
          now.difference(reminderFireTime(startsAt, kind)) <= window)
        kind,
  ];
}

/// ID numérico estable para la notificación local de un
/// recordatorio. El mismo partido + tipo siempre da el mismo ID, así
/// que reprogramar reemplaza el aviso anterior en vez de duplicarlo.
int reminderNotificationId(
  String matchId,
  MatchReminderKind kind,
) {
  return stableNotificationId('$matchId|${kind.key}');
}

/// Hash estable (FNV-1a de 31 bits); no depende de la ejecución.
int stableNotificationId(String source) {
  var hash = 0x811c9dc5;

  for (final unit in source.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }

  return hash & 0x7fffffff;
}

/// ID del documento de la bandeja para un evento del partido.
///
/// Ejemplos:
///   m1_sched_1731618000000_uid
///   m1_result_v2_uid
///   m1_r24_uid
String matchNotificationDocId({
  required String matchId,
  required String eventKey,
  required String recipientUserId,
}) {
  return '${matchId}_${eventKey}_$recipientUserId';
}

String scheduleEventKey(DateTime startsAt) =>
    'sched_${startsAt.toUtc().millisecondsSinceEpoch}';

String resultEventKey(int version) => 'result_v$version';

// ================================================================
// TEXTOS
// ================================================================

const List<String> _weekdays = <String>[
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const List<String> _months = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// 6:00 PM
String alertTime(DateTime date) {
  final local = date.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minutes = local.minute.toString().padLeft(2, '0');

  return '$hour12:$minutes ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// sábado 14 nov
String alertDay(DateTime date) {
  final local = date.toLocal();

  return '${_weekdays[local.weekday - 1]} ${local.day} '
      '${_months[local.month - 1]}';
}

/// "Faltan 24 horas", "Falta 1 hora", "¡Ya empieza!"
String reminderHeadline(MatchReminderKind kind) {
  switch (kind) {
    case MatchReminderKind.dayBefore:
      return 'Faltan 24 horas';
    case MatchReminderKind.hourBefore:
      return 'Falta 1 hora';
    case MatchReminderKind.kickoff:
      return '¡Ya empieza tu partido!';
  }
}

/// Título corto: "Diablos Emiliano vs Tigres"
String matchupTitle(String home, String away) => '$home vs $away';

/// Texto corto de la notificación del teléfono.
String reminderShortBody({
  required MatchReminderKind kind,
  required DateTime startsAt,
  required String courtName,
}) {
  final court = courtName.trim().isEmpty ? 'la cancha' : courtName.trim();

  if (kind == MatchReminderKind.kickoff) {
    return 'Dirígete a $court.';
  }

  return '${reminderHeadline(kind)} · ${alertTime(startsAt)} · '
      'Dirígete a $court.';
}

/// Mensaje completo para la bandeja.
String reminderFullBody({
  required MatchReminderKind kind,
  required String myTeam,
  required String rival,
  required DateTime startsAt,
  required String courtName,
}) {
  final court = courtName.trim().isEmpty ? 'la cancha asignada' : courtName.trim();

  final when = kind == MatchReminderKind.kickoff
      ? 'Tu partido empieza ahora'
      : '${reminderHeadline(kind)} para tu partido';

  return '$when: $myTeam vs $rival, ${alertDay(startsAt)} a las '
      '${alertTime(startsAt)}. Dirígete a $court. Toca "Cómo llegar" '
      'en el calendario para abrir la ruta.';
}

String scheduledShortBody({
  required bool rescheduled,
  required DateTime startsAt,
  required String courtName,
}) {
  final court = courtName.trim().isEmpty ? 'cancha por confirmar' : courtName.trim();

  return '${rescheduled ? 'Nuevo horario' : 'Programado'}: '
      '${alertDay(startsAt)} · ${alertTime(startsAt)} · $court';
}

String scheduledFullBody({
  required bool rescheduled,
  required String home,
  required String away,
  required DateTime startsAt,
  required String courtName,
}) {
  final court = courtName.trim().isEmpty ? 'la cancha asignada' : courtName.trim();

  return rescheduled
      ? 'Cambió el partido $home vs $away. Ahora se juega el '
          '${alertDay(startsAt)} a las ${alertTime(startsAt)} en $court. '
          'Te recordaremos 24 horas y 1 hora antes.'
      : 'Se programó el partido $home vs $away para el '
          '${alertDay(startsAt)} a las ${alertTime(startsAt)} en $court. '
          'Te recordaremos 24 horas y 1 hora antes.';
}

String resultFullBody({
  required bool corrected,
  required String home,
  required String away,
  required int homeScore,
  required int awayScore,
}) {
  return corrected
      ? 'Se corrigió el resultado: $home $homeScore - $awayScore $away. '
          'La tabla de posiciones ya está actualizada.'
      : 'Resultado final: $home $homeScore - $awayScore $away. '
          'Consulta la tabla de posiciones en Torneos.';
}
