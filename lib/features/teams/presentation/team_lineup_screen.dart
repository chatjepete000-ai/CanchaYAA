import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../data/team_lineup_repository.dart';
import '../domain/team_lineup.dart';
import '../domain/team_models.dart';

// ================================================================
// F04 · ALINEACIÓN VISUAL
// ================================================================
//
// Encargado (canEdit = true):
//   - Mantén presionado un jugador y arrástralo a una posición.
//   - También puedes tocar una posición para elegir al jugador.
//   - Un jugador nunca queda en dos posiciones (se intercambian).
//   - Guardar y exportar como imagen.
//
// Jugadores (canEdit = false): consultan y exportan la alineación
// guardada. firestore.rules impide que la modifiquen.
// ================================================================

class TeamLineupScreen extends StatefulWidget {
  const TeamLineupScreen({
    super.key,
    required this.team,
    required this.canEdit,
  });

  final Team team;
  final bool canEdit;

  @override
  State<TeamLineupScreen> createState() => _TeamLineupScreenState();
}

class _TeamLineupScreenState extends State<TeamLineupScreen> {
  final TeamLineupRepository _repository = TeamLineupRepository();

  final GlobalKey _exportKey = GlobalKey();

  late final Future<String> _formatFuture =
      _repository.getTournamentFormat(widget.team.tournamentId);

  late final Stream<TeamLineup?> _lineupStream =
      _repository.watchLineup(widget.team.id);

  late final Stream<List<LineupPlayer>> _rosterStream = widget.canEdit
      ? _repository.watchRosterPlayers(widget.team)
      : Stream<List<LineupPlayer>>.value(const <LineupPlayer>[]);

  // Borrador local del encargado.
  String? _format;
  String? _formationId;
  List<String>? _slots;
  bool _dirty = false;
  bool _saving = false;
  bool _exporting = false;

  void _loadDraft(TeamLineup? saved, String tournamentFormat) {
    if (_dirty && _slots != null) {
      return;
    }

    // Si el torneo cambió de formato, se empieza una alineación
    // nueva con el formato correcto.
    final lineup = saved != null && saved.format == tournamentFormat
        ? saved
        : TeamLineup.empty(
            teamId: widget.team.id,
            format: tournamentFormat,
          );

    _format = lineup.format;
    _formationId = lineup.formation;
    _slots = keepOnlyRosterPlayers(
      lineup.slots,
      widget.team.playerUserIds.toSet(),
    );
  }

  void _update(List<String> slots) {
    setState(() {
      _slots = slots;
      _dirty = true;
    });
  }

  void _changeFormation(String formationId) {
    final formation = formationFor(_format!, formationId);

    setState(() {
      _formationId = formation.id;
      _slots = resizeSlots(_slots!, formation.slotCount);
      _dirty = true;
    });
  }

  Future<void> _save(Map<String, String> namesById) async {
    setState(() {
      _saving = true;
    });

    try {
      await _repository.saveLineup(
        team: widget.team,
        format: _format!,
        formation: _formationId!,
        slots: _slots!,
        namesById: namesById,
      );

      if (!mounted) return;

      setState(() {
        _dirty = false;
      });

      _showMessage('Alineación guardada.');
    } catch (error) {
      if (!mounted) return;

      final text = error.toString();

      _showMessage(
        text.contains('permission-denied') ||
                text.contains('PERMISSION_DENIED')
            ? 'No tienes permiso para modificar esta alineación.'
            : error is ArgumentError
                ? '${error.message}'
                : 'No se pudo guardar. Revisa tu conexión.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _export() async {
    setState(() {
      _exporting = true;
    });

    try {
      final boundary = _exportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw StateError('No se encontró la alineación.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (bytes == null) {
        throw StateError('No se pudo generar la imagen.');
      }

      final fileName =
          'alineacion_${widget.team.displayName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.png';

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/png',
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
          text: 'Alineación de ${widget.team.displayName}',
        ),
      );
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudo exportar la imagen.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _pickPlayerForSlot(
    int slotIndex,
    List<LineupPlayer> roster,
  ) async {
    final slots = _slots!;
    final current = slots[slotIndex];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                if (current.isNotEmpty)
                  ListTile(
                    leading: const Icon(CupertinoIcons.minus_circle),
                    title: const Text('Dejar vacía esta posición'),
                    onTap: () => Navigator.pop(sheetContext, ''),
                  ),
                for (final player in roster)
                  ListTile(
                    leading: Icon(
                      player.userId == current
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.person_crop_circle,
                    ),
                    title: Text(player.displayName),
                    subtitle: slots.contains(player.userId) &&
                            player.userId != current
                        ? const Text('Ya está en otra posición (se intercambian)')
                        : null,
                    onTap: () => Navigator.pop(sheetContext, player.userId),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    _update(
      selected.isEmpty
          ? clearSlot(slots, slotIndex)
          : assignPlayerToSlot(slots, slotIndex, selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alineación'),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<String>(
          future: _formatFuture,
          builder: (context, formatSnapshot) {
            if (!formatSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final tournamentFormat = formatSnapshot.data!;

            return StreamBuilder<TeamLineup?>(
              stream: _lineupStream,
              builder: (context, lineupSnapshot) {
                if (lineupSnapshot.hasError) {
                  return const _InfoMessage(
                    icon: CupertinoIcons.exclamationmark_triangle,
                    text: 'No se pudo cargar la alineación.',
                  );
                }

                if (lineupSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !lineupSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final saved = lineupSnapshot.data;

                if (!widget.canEdit) {
                  return _buildReadOnly(saved);
                }

                return StreamBuilder<List<LineupPlayer>>(
                  stream: _rosterStream,
                  builder: (context, rosterSnapshot) {
                    if (rosterSnapshot.hasError) {
                      return const _InfoMessage(
                        icon: CupertinoIcons.exclamationmark_triangle,
                        text: 'No se pudo cargar la plantilla.',
                      );
                    }

                    if (!rosterSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    _loadDraft(saved, tournamentFormat);

                    return _buildEditor(
                      saved: saved,
                      roster: rosterSnapshot.data!,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ==============================================================
  // SOLO LECTURA (jugadores)
  // ==============================================================

  Widget _buildReadOnly(TeamLineup? saved) {
    if (saved == null || saved.filledCount == 0) {
      return const _InfoMessage(
        icon: CupertinoIcons.sportscourt,
        text: 'El encargado todavía no publica la alineación.',
      );
    }

    final formation = formationFor(saved.format, saved.formation);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        RepaintBoundary(
          key: _exportKey,
          child: _LineupCard(
            teamName: widget.team.displayName,
            formation: formation,
            names: saved.playerNames,
          ),
        ),
        const SizedBox(height: 16),
        _ExportButton(
          exporting: _exporting,
          onPressed: _export,
        ),
      ],
    );
  }

  // ==============================================================
  // EDITOR (encargado)
  // ==============================================================

  Widget _buildEditor({
    required TeamLineup? saved,
    required List<LineupPlayer> roster,
  }) {
    final theme = Theme.of(context);
    final slots = _slots!;
    final formation = formationFor(_format!, _formationId!);

    final namesById = <String, String>{
      for (final player in roster) player.userId: player.displayName,
    };

    // Nombres guardados, por si un jugador ya no aparece en la
    // consulta de la plantilla.
    if (saved != null) {
      for (var i = 0; i < saved.slots.length; i++) {
        final id = saved.slots[i];
        if (id.isNotEmpty && !namesById.containsKey(id)) {
          namesById[id] = saved.playerNames[i];
        }
      }
    }

    final names = [
      for (final id in slots) id.isEmpty ? '' : (namesById[id] ?? 'Jugador'),
    ];

    final bench =
        roster.where((player) => !slots.contains(player.userId)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Text(
          'Formación',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final option in formationsForFormat(_format!))
              ChoiceChip(
                label: Text(option.id),
                selected: option.id == formation.id,
                onSelected: _saving
                    ? null
                    : (_) => _changeFormation(option.id),
              ),
          ],
        ),
        const SizedBox(height: 14),
        RepaintBoundary(
          key: _exportKey,
          child: _LineupCard(
            teamName: widget.team.displayName,
            formation: formation,
            names: names,
            slotBuilder: (index, child) => _EditableSlot(
              slotIndex: index,
              playerId: slots[index],
              enabled: !_saving,
              onDropPlayer: (playerId) =>
                  _update(assignPlayerToSlot(slots, index, playerId)),
              onTap: () => _pickPlayerForSlot(index, roster),
              child: child,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Banca (${bench.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          roster.isEmpty
              ? 'Aún no hay jugadores aceptados en el equipo. Invítalos '
                  'desde Administrar equipo.'
              : 'Mantén presionado un jugador y arrástralo a su posición, '
                  'o toca una posición para elegirlo.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        DragTarget<String>(
          // Soltar un jugador de la cancha en la banca lo retira.
          onWillAcceptWithDetails: (details) =>
              !_saving && slots.contains(details.data),
          onAcceptWithDetails: (details) => _update(
            clearSlot(slots, slots.indexOf(details.data)),
          ),
          builder: (context, candidates, rejected) {
            return Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: candidates.isNotEmpty
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: bench.isEmpty
                  ? Text(
                      roster.isEmpty
                          ? 'Sin jugadores'
                          : 'Todos los jugadores están en la cancha.',
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final player in bench)
                          LongPressDraggable<String>(
                            data: player.userId,
                            maxSimultaneousDrags: _saving ? 0 : 1,
                            feedback: Material(
                              color: Colors.transparent,
                              child: _PlayerChip(
                                name: player.displayName,
                                dragging: true,
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: _PlayerChip(name: player.displayName),
                            ),
                            child: _PlayerChip(name: player.displayName),
                          ),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving || !_dirty ? null : () => _save(namesById),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(CupertinoIcons.checkmark_alt),
          label: Text(_dirty ? 'Guardar alineación' : 'Alineación guardada'),
        ),
        const SizedBox(height: 10),
        _ExportButton(
          exporting: _exporting,
          onPressed: _export,
        ),
      ],
    );
  }
}

// ================================================================
// TARJETA EXPORTABLE (encabezado + cancha)
// ================================================================

typedef _SlotBuilder = Widget Function(int index, Widget child);

class _LineupCard extends StatelessWidget {
  const _LineupCard({
    required this.teamName,
    required this.formation,
    required this.names,
    this.slotBuilder,
  });

  final String teamName;
  final LineupFormation formation;
  final List<String> names;
  final _SlotBuilder? slotBuilder;

  @override
  Widget build(BuildContext context) {
    final positions = formation.positions;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3D25),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  formation.id,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 0.72,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final slotWidth = (width / 4.2).clamp(64.0, 92.0);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _PitchPainter()),
                    ),
                    for (var i = 0; i < positions.length; i++)
                      Positioned(
                        left: positions[i].x * width - slotWidth / 2,
                        top: positions[i].y * height - 30,
                        width: slotWidth,
                        child: _wrapSlot(
                          i,
                          _SlotView(
                            name: i < names.length ? names[i] : '',
                            isGoalkeeper: positions[i].isGoalkeeper,
                            editable: slotBuilder != null,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'CanchaYA',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapSlot(int index, Widget child) {
    final builder = slotBuilder;
    return builder == null ? child : builder(index, child);
  }
}

class _SlotView extends StatelessWidget {
  const _SlotView({
    required this.name,
    required this.isGoalkeeper,
    required this.editable,
    this.highlighted = false,
  });

  final String name;
  final bool isGoalkeeper;
  final bool editable;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final filled = name.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (isGoalkeeper
                    ? const Color(0xFFF2B705)
                    : Colors.white)
                : Colors.white.withValues(alpha: highlighted ? 0.45 : 0.18),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFF43E97B)
                  : Colors.white.withValues(alpha: 0.8),
              width: highlighted ? 3 : 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            filled
                ? CupertinoIcons.person_fill
                : (editable ? CupertinoIcons.plus : CupertinoIcons.person),
            size: 18,
            color: filled ? const Color(0xFF0B3D25) : Colors.white,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: filled ? 0.45 : 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            filled ? name : (isGoalkeeper ? 'Portero' : 'Libre'),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditableSlot extends StatelessWidget {
  const _EditableSlot({
    required this.slotIndex,
    required this.playerId,
    required this.enabled,
    required this.onDropPlayer,
    required this.onTap,
    required this.child,
  });

  final int slotIndex;
  final String playerId;
  final bool enabled;
  final ValueChanged<String> onDropPlayer;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          enabled && details.data != playerId,
      onAcceptWithDetails: (details) => onDropPlayer(details.data),
      builder: (context, candidates, rejected) {
        final view = child is _SlotView
            ? _SlotView(
                name: (child as _SlotView).name,
                isGoalkeeper: (child as _SlotView).isGoalkeeper,
                editable: true,
                highlighted: candidates.isNotEmpty,
              )
            : child;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: view,
        );
      },
    );

    if (playerId.isEmpty) {
      return target;
    }

    // Un jugador ya colocado se puede arrastrar a otra posición
    // (se intercambian) o de vuelta a la banca.
    return LongPressDraggable<String>(
      data: playerId,
      maxSimultaneousDrags: enabled ? 1 : 0,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 80, child: child),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: child),
      child: target,
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.name,
    this.dragging = false,
  });

  final String name;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dragging ? colors.primary : colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        boxShadow: dragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.person_fill,
            size: 16,
            color: dragging ? Colors.white : colors.primary,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: dragging ? Colors.white : colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.exporting,
    required this.onPressed,
  });

  final bool exporting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: exporting ? null : onPressed,
      icon: exporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(CupertinoIcons.square_arrow_up),
      label: const Text('Exportar imagen'),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// CANCHA
// ================================================================

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final grass = Paint()..color = const Color(0xFF128C4A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      grass,
    );

    // Franjas de césped.
    final stripe = Paint()..color = const Color(0xFF16A055);
    const stripes = 8;
    for (var i = 0; i < stripes; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          size.height * i / stripes,
          size.width,
          size.height / stripes,
        ),
        stripe,
      );
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final inset = rect.deflate(8);
    canvas.drawRect(inset, line);

    // Medio campo y círculo central.
    canvas.drawLine(
      Offset(inset.left, inset.center.dy),
      Offset(inset.right, inset.center.dy),
      line,
    );
    canvas.drawCircle(inset.center, size.width * 0.13, line);

    // Áreas.
    final boxWidth = inset.width * 0.5;
    final boxHeight = inset.height * 0.13;
    canvas.drawRect(
      Rect.fromLTWH(
        inset.center.dx - boxWidth / 2,
        inset.top,
        boxWidth,
        boxHeight,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        inset.center.dx - boxWidth / 2,
        inset.bottom - boxHeight,
        boxWidth,
        boxHeight,
      ),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
