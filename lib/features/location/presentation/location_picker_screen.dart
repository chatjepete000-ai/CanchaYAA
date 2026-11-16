import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../courts/data/court_repository.dart';
import '../../courts/domain/court.dart';
import '../data/location_controller.dart';
import '../data/location_search_service.dart';
import '../domain/user_location.dart';

// ================================================================
// ELIGE TU CIUDAD
// ================================================================
//
// 1) Ciudades con canchas en CanchaYA (un toque).
// 2) Buscador de cualquier ciudad o municipio de México
//    (OpenStreetMap).
//
// No se usa el GPS del teléfono.
// ================================================================

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final LocationSearchService _search = LocationSearchService();
  final TextEditingController _queryController = TextEditingController();

  late final Stream<List<Court>>? _courts =
      Firebase.apps.isEmpty ? null : CourtRepository().watchCourts();

  Timer? _debounce;
  List<UserLocation> _results = const [];
  bool _searching = false;
  bool _saving = false;
  String? _error;
  int _searchId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();

    if (value.trim().length < LocationSearchService.minQueryLength) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }

    // Espera a que el usuario deje de escribir (máximo una búsqueda
    // por segundo, como pide OpenStreetMap).
    _debounce = Timer(
      const Duration(milliseconds: 900),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String value) async {
    final id = ++_searchId;

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await _search.search(value);

      if (!mounted || id != _searchId) return;

      setState(() {
        _results = results;
        _searching = false;
      });
    } on LocationSearchException catch (error) {
      if (!mounted || id != _searchId) return;

      setState(() {
        _results = const [];
        _searching = false;
        _error = error.message;
      });
    }
  }

  Future<void> _choose(UserLocation location) async {
    setState(() {
      _saving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await LocationController.instance.select(location);

      messenger.showSnackBar(
        SnackBar(content: Text('Ciudad cambiada a ${location.label}.')),
      );
    } catch (_) {
      // La ciudad ya se aplicó en esta sesión; solo no se guardó.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Ahora ves ${location.label}. No se pudo guardar en tu '
            'perfil; revisa tu conexión.',
          ),
        ),
      );
    }

    if (mounted) {
      navigator.pop(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = LocationController.instance.current;
    final showingSearch =
        _queryController.text.trim().length >= LocationSearchService.minQueryLength;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elige tu ciudad'),
      ),
      body: SafeArea(
        top: false,
        child: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              _CurrentCityCard(location: current),
              const SizedBox(height: 16),
              TextField(
                controller: _queryController,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  _runSearch(value);
                },
                decoration: InputDecoration(
                  hintText: 'Busca tu ciudad o municipio',
                  prefixIcon: const Icon(CupertinoIcons.search),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar',
                          icon: const Icon(CupertinoIcons.xmark_circle_fill),
                          onPressed: () {
                            _queryController.clear();
                            _onQueryChanged('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (showingSearch) ...[
                _SectionLabel(text: 'Resultados en México'),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _InfoText(icon: CupertinoIcons.wifi_slash, text: _error!)
                else if (_results.isEmpty)
                  const _InfoText(
                    icon: CupertinoIcons.map,
                    text: 'No encontramos esa ciudad. Revisa cómo está '
                        'escrita o prueba con el nombre del municipio.',
                  )
                else
                  for (final result in _results)
                    _CityTile(
                      location: result,
                      selected: result == current,
                      onTap: () => _choose(result),
                    ),
                const SizedBox(height: 8),
                Text(
                  'Búsqueda: © colaboradores de OpenStreetMap',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
              ],
              _SectionLabel(text: 'Ciudades con canchas en CanchaYA'),
              if (_courts == null)
                _CityTile(
                  location: UserLocation.montemorelos,
                  selected: UserLocation.montemorelos == current,
                  onTap: () => _choose(UserLocation.montemorelos),
                )
              else
                StreamBuilder<List<Court>>(
                  stream: _courts,
                  builder: (context, snapshot) {
                    final cities = citiesFromCourts(
                      snapshot.data ?? const <Court>[],
                    );

                    // Montemorelos siempre aparece como opción base.
                    final options = <UserLocation>[
                      UserLocation.montemorelos,
                      for (final city in cities)
                        if (!city.matchesCity(UserLocation.montemorelos.city))
                          city,
                    ];

                    return Column(
                      children: [
                        for (final city in options)
                          _CityTile(
                            location: city,
                            selected: city.matchesCity(current.city),
                            onTap: () => _choose(city),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 12),
              Text(
                'CanchaYA no usa el GPS de tu teléfono: tú eliges la ciudad '
                'y se guarda en tu perfil.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentCityCard extends StatelessWidget {
  const _CurrentCityCard({
    required this.location,
  });

  final UserLocation location;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.78)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.location_fill, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ciudad actual',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  location.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.location,
    required this.selected,
    required this.onTap,
  });

  final UserLocation location;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          selected
              ? CupertinoIcons.checkmark_circle_fill
              : CupertinoIcons.location,
          color: colors.primary,
        ),
        title: Text(
          location.city,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: location.state.isEmpty ? null : Text(location.state),
        trailing: selected
            ? Text(
                'Actual',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              )
            : const Icon(CupertinoIcons.chevron_right, size: 16),
        onTap: selected ? null : onTap,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
