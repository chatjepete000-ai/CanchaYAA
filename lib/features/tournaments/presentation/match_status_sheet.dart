import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../notifications/data/match_notification_publisher.dart';
import '../data/match_status_repository.dart';
import '../data/tournament_schedule_repository.dart';
import '../domain/match_status.dart';

/// Pide el motivo y suspende o cancela el partido. Después avisa a
/// jugadores y encargados de los dos equipos.
///
/// Devuelve true si el cambio se guardó.
Future<bool> showMatchStatusSheet(
  BuildContext context, {
  required TournamentMatchRecord match,
  required bool cancel,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MatchStatusSheet(match: match, cancel: cancel),
  );

  return changed == true;
}

class _MatchStatusSheet extends StatefulWidget {
  const _MatchStatusSheet({
    required this.match,
    required this.cancel,
  });

  final TournamentMatchRecord match;
  final bool cancel;

  @override
  State<_MatchStatusSheet> createState() => _MatchStatusSheetState();
}

class _MatchStatusSheetState extends State<_MatchStatusSheet> {
  final TextEditingController _note = TextEditingController();

  MatchStatusReason _reason = MatchStatusReason.weather;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final repository = MatchStatusRepository();
    final note = cleanMatchStatusNote(_note.text);

    try {
      if (widget.cancel) {
        await repository.cancel(
          match: widget.match,
          reason: _reason,
          note: note,
        );
      } else {
        await repository.suspend(
          match: widget.match,
          reason: _reason,
          note: note,
        );
      }
    } catch (error) {
      if (!mounted) return;

      final text = error.toString();

      setState(() {
        _saving = false;
        _error = text.contains('permission-denied') ||
                text.contains('PERMISSION_DENIED')
            ? 'Firestore rechazó el cambio. Revisa que las reglas nuevas '
                'estén desplegadas.'
            : 'No se pudo guardar: ${error is StateError ? error.message : text}';
      });

      return;
    }

    // El cambio ya quedó guardado: los avisos son un complemento.
    var notified = 0;

    try {
      notified = await MatchNotificationPublisher().notifyStatusChange(
        matchId: widget.match.id,
        cancelled: widget.cancel,
        reasonLabel: _reason.label,
        note: note,
        previousStartsAt: widget.match.startsAt,
      );
    } catch (_) {}

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    Navigator.of(context).pop(true);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${widget.cancel ? 'Partido cancelado' : 'Partido suspendido'}. '
          '${notified > 0 ? 'Se avisó a $notified personas.' : 'No se pudieron enviar los avisos.'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final match = widget.match;
    final cancel = widget.cancel;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cancel ? 'Cancelar partido' : 'Suspender partido',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${match.homeTeamName} vs ${match.awayTeamName}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (cancel ? colors.errorContainer : colors.primaryContainer)
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    cancel
                        ? CupertinoIcons.xmark_octagon
                        : CupertinoIcons.cloud_rain,
                    color: cancel ? colors.error : colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cancel
                          ? 'Es definitivo: se libera la cancha, no se podrá '
                              'reprogramar ni capturar resultado y no cuenta '
                              'en la tabla.'
                          : 'Se libera la cancha y el horario. El partido '
                              'queda pendiente para reprogramarlo después.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Motivo',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in MatchStatusReason.values)
                  ChoiceChip(
                    label: Text(reason.label),
                    selected: _reason == reason,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _reason = reason),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              enabled: !_saving,
              maxLength: maxMatchStatusNoteLength,
              decoration: const InputDecoration(
                labelText: 'Detalle (opcional)',
                hintText: 'Ej. tormenta eléctrica, cancha inundada',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: cancel
                    ? FilledButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: colors.onError,
                      )
                    : null,
                onPressed: _saving ? null : _confirm,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        cancel
                            ? CupertinoIcons.xmark_octagon
                            : CupertinoIcons.pause_circle,
                      ),
                label: Text(
                  cancel
                      ? 'Cancelar y avisar a los equipos'
                      : 'Suspender y avisar a los equipos',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
