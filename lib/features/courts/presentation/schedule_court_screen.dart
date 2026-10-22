import 'package:flutter/material.dart';

import '../../tournaments/data/tournament_schedule_repository.dart';
import '../data/court_repository.dart';
import '../domain/court.dart';
import 'courts_screen.dart';

class ScheduleCourtScreen extends StatefulWidget {
  const ScheduleCourtScreen({super.key, required this.match});
  final TournamentMatchRecord match;
  @override
  State<ScheduleCourtScreen> createState() => _ScheduleCourtScreenState();
}

class _ScheduleCourtScreenState extends State<ScheduleCourtScreen> {
  final _repository = CourtRepository();
  late final _courts = _repository.watchCourts();
  late String? _courtId = widget.match.courtId;
  late DateTime _date =
      widget.match.startsAt?.toLocal() ??
      DateTime.now().add(const Duration(days: 1));
  late int _hour = widget.match.startsAt?.toLocal().hour ?? 18;
  bool _saving = false;
  String? _error;

  Future<void> _save(Court court) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.scheduleMatch(
        widget.match,
        court,
        DateTime(_date.year, _date.month, _date.day, _hour),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : error is ArgumentError
              ? error.message.toString()
              : 'No se pudo programar. Revisa la conexión y tus permisos de administrador de liga.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cancha y horario')),
    body: StreamBuilder<List<Court>>(
      stream: _courts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'No se pudieron consultar las canchas. Revisa tu conexión y permisos.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final courts = snapshot.data!.where((c) => c.active).toList();
        final selected = courts.where((c) => c.id == _courtId).firstOrNull;
        // Align blocks in UTC even when the phone is outside Nuevo León.
        final hours = List.generate(24, (i) => i)
            .where(
              (h) =>
                  DateTime(
                        _date.year,
                        _date.month,
                        _date.day,
                        h,
                      ).toUtc().millisecondsSinceEpoch %
                      7200000 ==
                  0,
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${widget.match.homeTeamName} vs ${widget.match.awayTeamName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              key: ValueKey(selected?.id),
              initialValue: selected?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cancha'),
              items: courts
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => _courtId = v),
            ),
            TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CourtsScreen()),
                    ),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Explorar / registrar canchas'),
            ),
            if (selected != null) Text('${selected.address}, ${selected.city}'),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Fecha: ${_date.day}/${_date.month}/${_date.year}'),
              onPressed: _saving
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final first = DateTime(now.year, now.month, now.day);
                      final last = DateTime(now.year + 2, 12, 31);
                      final date = await showDatePicker(
                        context: context,
                        firstDate: first,
                        lastDate: last,
                        initialDate: _date.isBefore(first)
                            ? first
                            : _date.isAfter(last)
                            ? last
                            : _date,
                      );
                      if (date != null && mounted) setState(() => _date = date);
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey('${_date.day}-${_date.month}-${_date.year}'),
              initialValue: hours.contains(_hour) ? _hour : null,
              decoration: const InputDecoration(
                labelText: 'Hora de inicio (hora de tu dispositivo)',
              ),
              items: hours
                  .map(
                    (h) => DropdownMenuItem(
                      value: h,
                      child: Text('${h.toString().padLeft(2, '0')}:00'),
                    ),
                  )
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => _hour = v!),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cada partido reserva un bloque de 2 horas. Ni la cancha ni los equipos pueden tener otro partido en ese bloque.',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || selected == null || !hours.contains(_hour)
                  ? null
                  : () => _save(selected),
              child: Text(_saving ? 'Guardando…' : 'Guardar cancha y horario'),
            ),
          ],
        );
      },
    ),
  );
}
