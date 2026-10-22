import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/domain/user_role.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../tournaments/data/tournament_schedule_repository.dart';
import '../data/court_repository.dart';
import '../domain/court.dart';
import 'court_editor_screen.dart';
import 'court_map.dart';

class CourtsScreen extends StatefulWidget {
  const CourtsScreen({super.key});
  @override
  State<CourtsScreen> createState() => _CourtsScreenState();
}

class _CourtsScreenState extends State<CourtsScreen> {
  final _map = MapController();
  late final _repository = CourtRepository();
  late final _courts = _repository.watchCourts();
  late final _profile = ProfileRepository().watchCurrentProfile();
  String _query = '', _sport = 'Todas';
  Court? _selected;
  bool _importing = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _edit([Court? court]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourtEditorScreen(court: court)),
    );
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      await _repository.importExamples();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Canchas de Montemorelos agregadas. Edita cada una para marcar su ubicación exacta.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron importar. Revisa tu conexión y permisos.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _select(Court court) {
    FocusScope.of(context).unfocus();
    setState(() => _selected = court);
    if (court.hasCoordinates) {
      _map.move(LatLng(court.latitude!, court.longitude!), 16);
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .66,
        child: CourtDetail(court: court),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Explorar canchas')),
        body: const Center(
          child: Text(
            'Configura Firebase e inicia sesión para consultar las canchas.',
          ),
        ),
      );
    }
    return StreamBuilder<UserProfile?>(
      stream: _profile,
      builder: (context, profile) {
        final admin =
            profile.data?.isAdmin == true &&
            profile.data?.status == AccountStatus.active;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Explorar canchas'),
            actions: [
              if (admin)
                IconButton(
                  tooltip: 'Agregar canchas de Montemorelos',
                  onPressed: _importing ? null : _import,
                  icon: _importing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add),
                ),
              if (admin)
                IconButton(
                  tooltip: 'Registrar cancha',
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add_location_alt_outlined),
                ),
            ],
          ),
          body: StreamBuilder<List<Court>>(
            stream: _courts,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudieron cargar las canchas. Revisa tu conexión y los permisos de Firestore.',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data!.where((c) => c.active).toList();
              final courts = all
                  .where(
                    (c) =>
                        (_sport == 'Todas' || c.sport == _sport) &&
                        '${c.name} ${c.address} ${c.city}'
                            .toLowerCase()
                            .contains(_query.toLowerCase().trim()),
                  )
                  .toList();
              final map = ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    CourtMap(
                      controller: _map,
                      markers: courts
                          .where((c) => c.hasCoordinates)
                          .map(
                            (c) => Marker(
                              point: LatLng(c.latitude!, c.longitude!),
                              width: 52,
                              height: 52,
                              child: Tooltip(
                                message: c.name,
                                child: IconButton(
                                  onPressed: () => _select(c),
                                  style: IconButton.styleFrom(
                                    backgroundColor: _selected?.id == c.id
                                        ? const Color(0xFF0B8F4D)
                                        : Colors.white,
                                    foregroundColor: _selected?.id == c.id
                                        ? Colors.white
                                        : const Color(0xFF0B8F4D),
                                  ),
                                  icon: const Icon(Icons.sports_soccer),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 32,
                      child: Row(
                        children: [
                          _mapButton(
                            Icons.add,
                            'Acercar',
                            () => _map.move(
                              _map.camera.center,
                              (_map.camera.zoom + 1).clamp(3, 19),
                            ),
                          ),
                          _mapButton(
                            Icons.remove,
                            'Alejar',
                            () => _map.move(
                              _map.camera.center,
                              (_map.camera.zoom - 1).clamp(3, 19),
                            ),
                          ),
                          _mapButton(
                            Icons.center_focus_strong,
                            'Centrar Montemorelos',
                            () => _map.move(montemorelosCenter, 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              final list = ListView.separated(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: courts.isEmpty ? 1 : courts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (courts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.sports_soccer_outlined, size: 42),
                          const SizedBox(height: 12),
                          Text(
                            all.isEmpty
                                ? 'La próxima sede empieza aquí'
                                : 'No hay canchas con estos filtros',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            all.isEmpty
                                ? 'Un administrador puede registrar canchas de escuelas, barrios o unidades deportivas.'
                                : 'Prueba otro nombre o tipo de cancha.',
                            textAlign: TextAlign.center,
                          ),
                          if (admin && all.isEmpty)
                            TextButton(
                              onPressed: _importing ? null : _import,
                              child: const Text(
                                'Agregar canchas de Montemorelos',
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                  final court = courts[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: const Icon(Icons.sports_soccer),
                      ),
                      title: Text(
                        court.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${court.sport} · ${court.city}\n${court.address}${court.hasCoordinates ? '' : '\nUbicación en mapa pendiente'}',
                        ),
                      ),
                      onTap: () => _select(court),
                      trailing:
                          admin &&
                              (court.createdBy == profile.data?.uid ||
                                  profile.data?.isPlatformAdmin == true)
                          ? IconButton(
                              tooltip: 'Editar cancha',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _edit(court),
                            )
                          : const Icon(Icons.chevron_right),
                    ),
                  );
                },
              );
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encuentra tu próxima cancha',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${all.length} sedes · Explora, elige y juega',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Buscar cancha, colonia o ciudad',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            [
                                  'Todas',
                                  'Fútbol 5',
                                  'Fútbol 7',
                                  'Fútbol 11',
                                  'Usos múltiples',
                                ]
                                .map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(s),
                                      selected: _sport == s,
                                      onSelected: (_) =>
                                          setState(() => _sport = s),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            constraints.maxWidth >= 850
                            ? Row(
                                children: [
                                  SizedBox(width: 340, child: list),
                                  const SizedBox(width: 16),
                                  Expanded(child: map),
                                ],
                              )
                            : Column(
                                children: [
                                  Expanded(flex: 5, child: map),
                                  const SizedBox(height: 12),
                                  Expanded(flex: 4, child: list),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _mapButton(IconData icon, String label, VoidCallback action) =>
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: IconButton.filledTonal(
          tooltip: label,
          onPressed: action,
          icon: Icon(icon),
        ),
      );
}

class CourtDetail extends StatefulWidget {
  const CourtDetail({super.key, required this.court});
  final Court court;
  @override
  State<CourtDetail> createState() => _CourtDetailState();
}

class _CourtDetailState extends State<CourtDetail> {
  late final _matches = CourtRepository().watchCourtMatches(widget.court.id);
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    children: [
      Text(
        widget.court.sport.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        widget.court.name,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 12),
      SelectableText('${widget.court.address}, ${widget.court.city}'),
      if (!widget.court.hasCoordinates)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'La ubicación exacta está pendiente. La ruta buscará la cancha por su dirección; verifica el destino.',
          ),
        ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => openCourtLink(context, widget.court.directionsUri),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Cómo llegar'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text:
                      '${widget.court.name}, ${widget.court.address}, ${widget.court.city}',
                ),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dirección copiada')),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copiar dirección'),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Text(
        'Próximos partidos',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      StreamBuilder<List<TournamentMatchRecord>>(
        stream: _matches,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'No se pudo consultar la agenda. Revisa tu conexión y vuelve a abrir la cancha.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = snapshot.data!
              .where((m) => m.startsAt?.isAfter(DateTime.now()) == true)
              .toList();
          if (matches.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Todavía no hay partidos próximos programados en esta cancha.',
              ),
            );
          }
          return Column(
            children: matches
                .map(
                  (m) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: Text('${m.homeTeamName} vs ${m.awayTeamName}'),
                      subtitle: Text(
                        '${formatCourtDate(m.startsAt!)} · Jornada ${m.roundNumber}',
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

String formatCourtDate(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}
