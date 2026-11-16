import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/domain/user_role.dart';
import '../../location/data/location_controller.dart';
import '../../location/domain/user_location.dart';
import '../../location/presentation/location_picker_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../tournaments/data/tournament_schedule_repository.dart';
import '../data/court_repository.dart';
import '../data/osm_pitch_service.dart';
import '../domain/court.dart';
import 'court_editor_screen.dart';
import 'court_map.dart';

class CourtsScreen extends StatefulWidget {
  const CourtsScreen({super.key});
  @override
  State<CourtsScreen> createState() => _CourtsScreenState();
}

class _CourtsScreenState extends State<CourtsScreen> {
  // Canchas registradas a esta distancia se consideran "cerca".
  static const double nearbyRadiusKm = 30;

  static const Color _green = Color(0xFF0B8F4D);
  static const Color _greenDark = Color(0xFF0B3D25);
  static const Color _suggested = Color(0xFFE0861A);

  final _map = MapController();
  late final _repository = CourtRepository();
  late final _courts = _repository.watchCourts();
  late final _profile = ProfileRepository().watchCurrentProfile();
  final OsmPitchService _osm = OsmPitchService();

  String _query = '', _sport = 'Todas';
  Court? _selected;
  bool _importing = false;

  List<OsmPitch> _osmPitches = const [];
  bool _osmLoading = false;
  String? _osmError;
  int _osmRequest = 0;

  // Ciudad elegida por el usuario (sin GPS).
  UserLocation get _location => LocationController.instance.current;

  LatLng get _cityCenter => _location.point ?? montemorelosCenter;

  @override
  void initState() {
    super.initState();
    LocationController.instance.addListener(_onLocationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSuggested();
    });
  }

  void _onLocationChanged() {
    if (!mounted) return;

    setState(() {
      _selected = null;
    });

    // El mapa ya está creado: moverlo a la nueva ciudad.
    try {
      _map.move(_cityCenter, 13);
    } catch (_) {
      // El mapa todavía no se dibuja; usará el centro inicial.
    }

    _loadSuggested();
  }

  /// Canchas de fútbol reales de OpenStreetMap alrededor de la ciudad.
  Future<void> _loadSuggested() async {
    final point = _location.point;
    final request = ++_osmRequest;

    if (point == null || Firebase.apps.isEmpty) {
      setState(() {
        _osmPitches = const [];
        _osmLoading = false;
        _osmError = null;
      });
      return;
    }

    setState(() {
      _osmLoading = true;
      _osmError = null;
    });

    try {
      final pitches = await _osm.pitchesAround(
        point.latitude,
        point.longitude,
      );

      if (!mounted || request != _osmRequest) return;

      setState(() {
        _osmPitches = pitches;
        _osmLoading = false;
      });
    } on OsmPitchException catch (error) {
      if (!mounted || request != _osmRequest) return;

      setState(() {
        _osmPitches = const [];
        _osmLoading = false;
        _osmError = error.message;
      });
    }
  }

  Future<void> _changeCity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
  }

  /// Distancia en km desde la ciudad elegida (null sin coordenadas).
  double? _distanceKm(Court court) => court.hasCoordinates
      ? _location.distanceKmTo(court.latitude, court.longitude)
      : null;

  /// Cerca: a menos de [nearbyRadiusKm]; sin coordenadas, misma ciudad.
  bool _isNearby(Court court) {
    final km = _distanceKm(court);

    if (km != null) return km <= nearbyRadiusKm;

    return _location.matchesCity(court.city);
  }

  /// Más cercanas primero; sin coordenadas, primero las de la ciudad
  /// elegida y después el resto por nombre.
  int _byProximity(Court a, Court b) {
    final distanceA = _distanceKm(a);
    final distanceB = _distanceKm(b);

    if (distanceA != null && distanceB != null) {
      return distanceA.compareTo(distanceB);
    }

    if (distanceA != null) return -1;
    if (distanceB != null) return 1;

    final sameA = _location.matchesCity(a.city);
    final sameB = _location.matchesCity(b.city);

    if (sameA != sameB) return sameA ? -1 : 1;

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  @override
  void dispose() {
    LocationController.instance.removeListener(_onLocationChanged);
    _map.dispose();
    super.dispose();
  }

  Future<void> _edit([Court? court]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourtEditorScreen(court: court)),
    );
  }

  /// Un administrador registra una cancha sugerida de OpenStreetMap.
  Future<void> _registerSuggested(OsmPitch pitch) async {
    Navigator.of(context).pop();

    await _edit(
      Court(
        id: '',
        name: pitch.name,
        address: pitch.street,
        city: _location.city,
        latitude: pitch.latitude,
        longitude: pitch.longitude,
      ),
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

  void _selectSuggested(OsmPitch pitch, {required bool admin}) {
    FocusScope.of(context).unfocus();
    _map.move(LatLng(pitch.latitude, pitch.longitude), 16);

    final km = _location.distanceKmTo(pitch.latitude, pitch.longitude);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => _SuggestedPitchSheet(
        pitch: pitch,
        distance: _formatKm(km),
        canRegister: admin,
        onRegister: () => _registerSuggested(pitch),
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
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No se pudieron cargar las canchas. Revisa tu conexión y los permisos de Firestore.',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final query = _query.toLowerCase().trim();
              final all = snapshot.data!.where((c) => c.active).toList();
              final filtered = all
                  .where(
                    (c) =>
                        (_sport == 'Todas' || c.sport == _sport) &&
                        '${c.name} ${c.address} ${c.city}'
                            .toLowerCase()
                            .contains(query),
                  )
                  .toList()
                ..sort(_byProximity);

              final nearby = filtered.where(_isNearby).toList();
              final elsewhere =
                  filtered.where((c) => !_isNearby(c)).toList();

              // Las sugeridas son de fútbol sin tipo exacto: solo con
              // "Todas". Se omiten las que ya están registradas.
              final suggested = _sport != 'Todas'
                  ? const <OsmPitch>[]
                  : _osmPitches
                      .where(
                        (pitch) =>
                            pitch.displayName.toLowerCase().contains(query) &&
                            !all.any(
                              (court) =>
                                  court.hasCoordinates &&
                                  const Distance().as(
                                        LengthUnit.Meter,
                                        LatLng(
                                          court.latitude!,
                                          court.longitude!,
                                        ),
                                        LatLng(
                                          pitch.latitude,
                                          pitch.longitude,
                                        ),
                                      ) <
                                      80,
                            ),
                      )
                      .toList()
                    ..sort(
                      (a, b) => (_location.distanceKmTo(
                                a.latitude,
                                a.longitude,
                              ) ??
                              0)
                          .compareTo(
                        _location.distanceKmTo(b.latitude, b.longitude) ?? 0,
                      ),
                    );

              final map = _buildMap(
                courts: filtered,
                suggested: suggested,
                admin: admin,
              );

              final listChildren = <Widget>[
                _buildSectionTitle(
                  icon: Icons.verified_outlined,
                  title: 'En CanchaYA cerca de ${_location.city}',
                  count: nearby.length,
                  color: _green,
                ),
                if (nearby.isEmpty)
                  _buildNoNearby(all: all, admin: admin)
                else
                  for (final court in nearby)
                    _buildCourtCard(court, admin: admin, profile: profile.data),
                const SizedBox(height: 18),
                _buildSectionTitle(
                  icon: Icons.travel_explore,
                  title: 'Canchas sugeridas en el mapa',
                  count: suggested.length,
                  color: _suggested,
                ),
                ..._buildSuggestedList(suggested, admin: admin),
                if (elsewhere.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildElsewhere(elsewhere, admin: admin, profile: profile.data),
                ],
              ];

              return LayoutBuilder(
                builder: (context, constraints) {
                  final header = <Widget>[
                    _buildHero(
                      nearbyCount: nearby.length,
                      suggestedCount: suggested.length,
                    ),
                    const SizedBox(height: 14),
                    _buildFilters(),
                    const SizedBox(height: 14),
                  ];

                  if (constraints.maxWidth >= 850) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 400,
                            child: ListView(
                              children: [...header, ...listChildren],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: map),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      ...header,
                      SizedBox(height: 270, child: map),
                      const SizedBox(height: 18),
                      ...listChildren,
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // ==============================================================
  // ENCABEZADO
  // ==============================================================

  Widget _buildHero({
    required int nearbyCount,
    required int suggestedCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_greenDark, _green],
        ),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canchas cerca de',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _location.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: _changeCity,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, size: 18, color: _green),
                        SizedBox(width: 4),
                        Text(
                          'Cambiar',
                          style: TextStyle(
                            color: _green,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroStat(
                value: '$nearbyCount',
                label: 'en CanchaYA',
                icon: Icons.verified,
              ),
              const SizedBox(width: 10),
              _HeroStat(
                value: _osmLoading ? '…' : '$suggestedCount',
                label: 'sugeridas',
                icon: Icons.travel_explore,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const sports = <(String, IconData)>[
      ('Todas', Icons.grid_view_rounded),
      ('Fútbol 5', Icons.sports_soccer),
      ('Fútbol 7', Icons.sports_soccer),
      ('Fútbol 11', Icons.stadium_outlined),
      ('Usos múltiples', Icons.sports_basketball_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Buscar cancha, colonia o ciudad',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (sport, icon) in sports)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(
                      icon,
                      size: 18,
                      color: _sport == sport ? Colors.white : _green,
                    ),
                    showCheckmark: false,
                    label: Text(sport),
                    selected: _sport == sport,
                    selectedColor: _green,
                    labelStyle: TextStyle(
                      color: _sport == sport ? Colors.white : null,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const StadiumBorder(),
                    onSelected: (_) => setState(() => _sport = sport),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // MAPA
  // ==============================================================

  Widget _buildMap({
    required List<Court> courts,
    required List<OsmPitch> suggested,
    required bool admin,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          CourtMap(
            controller: _map,
            center: _cityCenter,
            markers: [
              for (final pitch in suggested)
                Marker(
                  point: LatLng(pitch.latitude, pitch.longitude),
                  width: 34,
                  height: 34,
                  child: GestureDetector(
                    onTap: () => _selectSuggested(pitch, admin: admin),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _suggested, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        size: 18,
                        color: _suggested,
                      ),
                    ),
                  ),
                ),
              for (final court in courts.where((c) => c.hasCoordinates))
                Marker(
                  point: LatLng(court.latitude!, court.longitude!),
                  width: 46,
                  height: 46,
                  child: Tooltip(
                    message: court.name,
                    child: GestureDetector(
                      onTap: () => _select(court),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selected?.id == court.id
                              ? _greenDark
                              : _green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports_soccer,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(100),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendDot(color: _green),
                  SizedBox(width: 4),
                  Text(
                    'CanchaYA',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 10),
                  _LegendDot(color: _suggested),
                  SizedBox(width: 4),
                  Text(
                    'Sugeridas',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (_osmLoading)
            const Positioned(
              right: 12,
              top: 12,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
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
                  Icons.my_location,
                  'Centrar ${_location.city}',
                  () => _map.move(_cityCenter, 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // LISTAS
  // ==============================================================

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoNearby({required List<Court> all, required bool admin}) {
    return _EmptyCard(
      icon: Icons.add_location_alt_outlined,
      title: 'Aún no hay canchas registradas cerca de ${_location.city}',
      message: all.isEmpty
          ? 'Un administrador puede registrar canchas de escuelas, barrios o unidades deportivas.'
          : 'Mira las canchas sugeridas del mapa o las otras sedes de CanchaYA.',
      action: admin
          ? FilledButton.icon(
              onPressed: () => _edit(),
              style: FilledButton.styleFrom(backgroundColor: _green),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Registrar cancha'),
            )
          : null,
    );
  }

  List<Widget> _buildSuggestedList(
    List<OsmPitch> suggested, {
    required bool admin,
  }) {
    if (!_location.hasCoordinates) {
      return const [
        _EmptyCard(
          icon: Icons.map_outlined,
          title: 'Sin coordenadas para esta ciudad',
          message:
              'Elige tu ciudad con el buscador para ver canchas sugeridas del mapa.',
        ),
      ];
    }

    if (_osmLoading) {
      return const [
        Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_osmError != null) {
      return [
        _EmptyCard(
          icon: Icons.wifi_off_rounded,
          title: 'No se cargaron las sugeridas',
          message: _osmError!,
          action: TextButton.icon(
            onPressed: _loadSuggested,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ];
    }

    if (suggested.isEmpty) {
      return const [
        _EmptyCard(
          icon: Icons.travel_explore,
          title: 'Sin canchas sugeridas',
          message:
              'OpenStreetMap no tiene canchas de fútbol registradas en esta zona.',
        ),
      ];
    }

    return [
      for (final pitch in suggested.take(15))
        _CourtCard(
          title: pitch.displayName,
          subtitle: [
            'Fútbol',
            if (pitch.surfaceLabel.isNotEmpty) pitch.surfaceLabel,
          ].join(' · '),
          detail: pitch.street.isEmpty ? null : pitch.street,
          distance: _formatKm(
            _location.distanceKmTo(pitch.latitude, pitch.longitude),
          ),
          color: _suggested,
          badge: 'Sugerida',
          onTap: () => _selectSuggested(pitch, admin: admin),
          onDirections: () => openCourtLink(context, pitch.directionsUri),
        ),
      if (suggested.length > 15)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Y ${suggested.length - 15} más en el mapa.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Sugeridas: © colaboradores de OpenStreetMap. Aún no están en CanchaYA.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ];
  }

  Widget _buildElsewhere(
    List<Court> courts, {
    required bool admin,
    required UserProfile? profile,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.public, color: _green),
        title: Text(
          'Otras sedes de CanchaYA (${courts.length})',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('Fuera de tu ciudad'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final court in courts)
            _buildCourtCard(court, admin: admin, profile: profile),
        ],
      ),
    );
  }

  Widget _buildCourtCard(
    Court court, {
    required bool admin,
    required UserProfile? profile,
  }) {
    final canEdit = admin &&
        (court.createdBy == profile?.uid || profile?.isPlatformAdmin == true);

    return _CourtCard(
      title: court.name,
      subtitle: '${court.sport} · ${court.city}',
      detail: court.hasCoordinates
          ? court.address
          : '${court.address}\nUbicación en mapa pendiente',
      distance: _formatKm(_distanceKm(court)),
      color: _green,
      selected: _selected?.id == court.id,
      onTap: () => _select(court),
      onDirections: () => openCourtLink(context, court.directionsUri),
      onEdit: canEdit ? () => _edit(court) : null,
    );
  }

  static String? _formatKm(double? km) {
    if (km == null) return null;
    if (km < 1) return '${(km * 1000).round()} m';

    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  Widget _mapButton(IconData icon, String label, VoidCallback action) =>
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          child: IconButton(
            tooltip: label,
            onPressed: action,
            color: _green,
            icon: Icon(icon),
          ),
        ),
      );
}

// ================================================================
// COMPONENTES VISUALES
// ================================================================

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _CourtCard extends StatelessWidget {
  const _CourtCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.onDirections,
    this.detail,
    this.distance,
    this.badge,
    this.selected = false,
    this.onEdit,
  });

  final String title;
  final String subtitle;
  final String? detail;
  final String? distance;
  final String? badge;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDirections;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? color : colors.outlineVariant,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.7)],
                    ),
                  ),
                  child: const Icon(
                    Icons.sports_soccer,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (distance != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                distance!,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (badge != null) ...[
                            Text(
                              badge!,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const Text(' · '),
                          ],
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (detail != null && detail!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _SmallAction(
                            icon: Icons.directions,
                            label: 'Cómo llegar',
                            color: color,
                            onTap: onDirections,
                          ),
                          if (onEdit != null) ...[
                            const SizedBox(width: 8),
                            _SmallAction(
                              icon: Icons.edit_outlined,
                              label: 'Editar',
                              color: colors.onSurfaceVariant,
                              onTap: onEdit!,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: colors.primary),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 10),
            action!,
          ],
        ],
      ),
    );
  }
}

class _SuggestedPitchSheet extends StatelessWidget {
  const _SuggestedPitchSheet({
    required this.pitch,
    required this.distance,
    required this.canRegister,
    required this.onRegister,
  });

  final OsmPitch pitch;
  final String? distance;
  final bool canRegister;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFE0861A);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CANCHA SUGERIDA',
              style: TextStyle(
                color: orange,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pitch.displayName,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (distance != null) 'A $distance de tu ciudad',
                if (pitch.surfaceLabel.isNotEmpty) pitch.surfaceLabel,
                if (pitch.street.isNotEmpty) pitch.street,
              ].join(' · '),
            ),
            const SizedBox(height: 10),
            const Text(
              'Esta cancha aparece en OpenStreetMap, pero todavía no está '
              'registrada en CanchaYA, así que no tiene partidos ni '
              'horarios.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => openCourtLink(context, pitch.directionsUri),
                  style: FilledButton.styleFrom(backgroundColor: orange),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Cómo llegar'),
                ),
                if (canRegister)
                  OutlinedButton.icon(
                    onPressed: onRegister,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Registrar en CanchaYA'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
