import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../courts/presentation/courts_screen.dart';
import '../../notifications/data/match_notification_publisher.dart';
import '../data/match_result_repository.dart';
import '../data/tournament_schedule_repository.dart';
import '../domain/match_result.dart';

// ================================================================
// F08 · CAPTURAR / CORREGIR RESULTADO (solo administrador de liga)
// ================================================================
//
// - Los goles se eligen con selectores (+ / −), sin teclear.
// - Antes de guardar se pide confirmación.
// - Corregir exige un motivo y queda en el historial.
// - firestore.rules rechaza cualquier intento de un jugador o
//   encargado, aunque llegue directo al servicio.
// ================================================================

class MatchResultScreen extends StatefulWidget {
  const MatchResultScreen({
    super.key,
    required this.match,
  });

  final TournamentMatchRecord match;

  @override
  State<MatchResultScreen> createState() =>
      _MatchResultScreenState();
}

class _MatchResultScreenState
    extends State<MatchResultScreen> {
  final MatchResultRepository _repository =
      MatchResultRepository();

  final TextEditingController _reasonController =
      TextEditingController();

  late final Stream<TournamentMatchRecord?> _matchStream =
      _repository.watchMatch(widget.match.id);

  late final Stream<List<MatchResultHistoryEntry>>
      _historyStream =
      _repository.watchHistory(widget.match.id);

  late int _homeScore = widget.match.homeScore ?? 0;
  late int _awayScore = widget.match.awayScore ?? 0;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _save(
    TournamentMatchRecord match,
  ) async {
    final isCorrection = match.isCompleted;

    if (isCorrection) {
      final reasonError = validateCorrectionReason(
        _reasonController.text,
      );

      if (reasonError != null) {
        setState(() {
          _error = reasonError;
        });
        return;
      }

      if (match.homeScore == _homeScore &&
          match.awayScore == _awayScore) {
        setState(() {
          _error = 'El marcador corregido es igual al actual.';
        });
        return;
      }
    }

    final notStartedYet = match.startsAt != null &&
        match.startsAt!.isAfter(DateTime.now());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isCorrection
                ? 'Confirmar corrección'
                : 'Confirmar resultado',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${match.homeTeamName} $_homeScore - '
                '$_awayScore ${match.awayTeamName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (isCorrection) ...[
                const SizedBox(height: 8),
                Text(
                  'Antes: ${match.homeScore} - ${match.awayScore}',
                ),
              ],
              if (notStartedYet) ...[
                const SizedBox(height: 12),
                const Text(
                  'Atención: según el calendario este partido '
                  'todavía no ha comenzado.',
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'La tabla de posiciones se actualizará '
                'automáticamente.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: Text(
                isCorrection ? 'Corregir' : 'Publicar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (isCorrection) {
        await _repository.correctResult(
          matchId: match.id,
          homeScore: _homeScore,
          awayScore: _awayScore,
          reason: _reasonController.text,
        );
      } else {
        await _repository.publishResult(
          matchId: match.id,
          homeScore: _homeScore,
          awayScore: _awayScore,
        );
      }

      // F06: avisar a ambos equipos. Si falla, el resultado ya
      // quedó guardado.
      var notified = 0;
      try {
        notified = await MatchNotificationPublisher().notifyResult(
          matchId: match.id,
        );
      } catch (_) {}

      if (!mounted) {
        return;
      }

      _reasonController.clear();

      final saved = isCorrection
          ? 'Resultado corregido.'
          : 'Resultado publicado.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notified > 0
                ? '$saved Se avisó a $notified integrantes.'
                : saved,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _friendlyError(
    Object error,
  ) {
    final text = error.toString();

    if (text.contains('permission-denied') ||
        text.contains('PERMISSION_DENIED')) {
      return 'No tienes permiso para guardar este resultado, '
          'o el partido cambió mientras lo editabas. '
          'Vuelve a intentarlo.';
    }

    if (error is StateError) {
      return error.message;
    }

    if (error is ArgumentError) {
      return '${error.message}';
    }

    return 'No se pudo guardar el resultado. '
        'Revisa tu conexión e inténtalo de nuevo.';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado del partido'),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<TournamentMatchRecord?>(
          stream: _matchStream,
          initialData: widget.match,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Message(
                icon: CupertinoIcons.exclamationmark_triangle,
                text: 'No se pudo cargar el partido.\n'
                    '${snapshot.error}',
              );
            }

            final match = snapshot.data;

            if (match == null) {
              return const _Message(
                icon: CupertinoIcons.xmark_circle,
                text: 'Este partido ya no existe.',
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                32,
              ),
              children: [
                _MatchHeader(match: match),
                const SizedBox(height: 18),
                if (match.status == 'postponed')
                  const _Message(
                    icon: CupertinoIcons.clock,
                    text: 'El partido está pospuesto. '
                        'Reprográmalo antes de capturar el resultado.',
                  )
                else if (!match.isCompleted &&
                    match.startsAt == null)
                  const _Message(
                    icon: CupertinoIcons.calendar_badge_plus,
                    text: 'Primero asigna cancha y horario. '
                        'Después podrás capturar el resultado.',
                  )
                else
                  _ScoreEditor(
                    match: match,
                    homeScore: _homeScore,
                    awayScore: _awayScore,
                    saving: _saving,
                    reasonController: _reasonController,
                    error: _error,
                    onHomeChanged: (value) {
                      setState(() {
                        _homeScore = value;
                        _error = null;
                      });
                    },
                    onAwayChanged: (value) {
                      setState(() {
                        _awayScore = value;
                        _error = null;
                      });
                    },
                    onSave: () => _save(match),
                  ),
                const SizedBox(height: 26),
                Text(
                  'Historial',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<MatchResultHistoryEntry>>(
                  stream: _historyStream,
                  builder: (context, historySnapshot) {
                    if (historySnapshot.hasError) {
                      return const Text(
                        'No se pudo cargar el historial.',
                      );
                    }

                    final entries = historySnapshot.data ??
                        const <MatchResultHistoryEntry>[];

                    if (entries.isEmpty) {
                      return Text(
                        match.isCompleted
                            ? 'Este resultado se capturó antes de que '
                                'existiera el historial.'
                            : 'Todavía no hay cambios registrados.',
                      );
                    }

                    return Column(
                      children: [
                        for (final entry in entries)
                          _HistoryTile(entry: entry),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ================================================================
// ENCABEZADO
// ================================================================

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({
    required this.match,
  });

  final TournamentMatchRecord match;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final statusLabel = match.isCompleted
        ? 'Finalizado'
        : match.status == 'postponed'
            ? 'Pospuesto'
            : 'Programado';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jornada ${match.roundNumber} · $statusLabel',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${match.homeTeamName} vs ${match.awayTeamName}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            match.startsAt == null
                ? 'Sin cancha ni horario'
                : '${match.courtName ?? 'Cancha'} · '
                    '${formatCourtDate(match.startsAt!)}',
            style: theme.textTheme.bodyMedium,
          ),
          if (match.hasResult) ...[
            const SizedBox(height: 10),
            Text(
              'Marcador actual: ${match.homeScore} - ${match.awayScore}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ================================================================
// SELECTORES DE MARCADOR
// ================================================================

class _ScoreEditor extends StatelessWidget {
  const _ScoreEditor({
    required this.match,
    required this.homeScore,
    required this.awayScore,
    required this.saving,
    required this.reasonController,
    required this.error,
    required this.onHomeChanged,
    required this.onAwayChanged,
    required this.onSave,
  });

  final TournamentMatchRecord match;
  final int homeScore;
  final int awayScore;
  final bool saving;
  final TextEditingController reasonController;
  final String? error;
  final ValueChanged<int> onHomeChanged;
  final ValueChanged<int> onAwayChanged;
  final VoidCallback onSave;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final isCorrection = match.isCompleted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isCorrection ? 'Corregir marcador' : 'Capturar marcador',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ScoreStepper(
                teamName: match.homeTeamName,
                caption: 'Local',
                value: homeScore,
                enabled: !saving,
                onChanged: onHomeChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ScoreStepper(
                teamName: match.awayTeamName,
                caption: 'Visitante',
                value: awayScore,
                enabled: !saving,
                onChanged: onAwayChanged,
              ),
            ),
          ],
        ),
        if (isCorrection) ...[
          const SizedBox(height: 14),
          TextField(
            controller: reasonController,
            enabled: !saving,
            maxLength: maxResultReasonLength,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo de la corrección',
              hintText: 'Ej. Gol anotado al equipo equivocado',
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  isCorrection
                      ? CupertinoIcons.pencil
                      : CupertinoIcons.checkmark_seal_fill,
                ),
          label: Text(
            isCorrection
                ? 'Guardar corrección'
                : 'Publicar resultado',
          ),
        ),
      ],
    );
  }
}

class _ScoreStepper extends StatelessWidget {
  const _ScoreStepper({
    required this.teamName,
    required this.caption,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String teamName;
  final String caption;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Text(
            caption,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            teamName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Quitar gol',
                onPressed: enabled && value > 0
                    ? () => onChanged(value - 1)
                    : null,
                icon: const Icon(CupertinoIcons.minus),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Agregar gol',
                onPressed: enabled && value < maxMatchScore
                    ? () => onChanged(value + 1)
                    : null,
                icon: const Icon(CupertinoIcons.plus),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================
// HISTORIAL
// ================================================================

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
  });

  final MatchResultHistoryEntry entry;

  @override
  Widget build(
    BuildContext context,
  ) {
    final when = entry.changedAt == null
        ? 'Guardando…'
        : formatCourtDate(entry.changedAt!);

    final score = entry.hasPreviousScore
        ? '${entry.previousHomeScore}-${entry.previousAwayScore}'
            ' → ${entry.homeScore}-${entry.awayScore}'
        : '${entry.homeScore}-${entry.awayScore}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          entry.action == MatchResultAction.corrected
              ? CupertinoIcons.pencil_circle_fill
              : CupertinoIcons.checkmark_circle_fill,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          '${entry.action.label} · $score',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          entry.reason.isEmpty
              ? when
              : '$when\nMotivo: ${entry.reason}',
        ),
        isThreeLine: entry.reason.isNotEmpty,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}
