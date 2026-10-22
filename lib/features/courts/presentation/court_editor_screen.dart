import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/court_repository.dart';
import '../domain/court.dart';
import 'court_map.dart';

class CourtEditorScreen extends StatefulWidget {
  const CourtEditorScreen({super.key, this.court});
  final Court? court;
  @override
  State<CourtEditorScreen> createState() => _CourtEditorScreenState();
}

class _CourtEditorScreenState extends State<CourtEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.court?.name);
  late final _address = TextEditingController(text: widget.court?.address);
  late final _city = TextEditingController(
    text: widget.court?.city ?? 'Montemorelos',
  );
  late String _sport = widget.court?.sport ?? 'Fútbol 7';
  late LatLng? _point = widget.court?.hasCoordinates == true
      ? LatLng(widget.court!.latitude!, widget.court!.longitude!)
      : null;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CourtRepository().save(
        Court(
          id: widget.court?.id ?? '',
          name: _name.text,
          address: _address.text,
          city: _city.text,
          sport: _sport,
          latitude: _point?.latitude,
          longitude: _point?.longitude,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar. Revisa tu conexión y que tu cuenta tenga el rol de administrador activo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.court == null ? 'Registrar cancha' : 'Editar cancha'),
    ),
    body: AbsorbPointer(
      absorbing: _saving,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Un lugar para jugar',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'También puedes registrar una escuela o una cancha de barrio. No necesita aparecer en Google Maps.',
            ),
            const SizedBox(height: 24),
            _field(_name, 'Nombre de la cancha', 100),
            const SizedBox(height: 14),
            _field(_address, 'Dirección o referencia', 240),
            const SizedBox(height: 14),
            _field(_city, 'Ciudad', 100),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _sport,
              decoration: const InputDecoration(labelText: 'Tipo de cancha'),
              items: [
                'Fútbol 5',
                'Fútbol 7',
                'Fútbol 11',
                'Usos múltiples',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _sport = v!),
            ),
            const SizedBox(height: 22),
            const Text(
              'Toca el mapa sobre la cancha',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 330,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: CourtMap(
                  center: _point ?? montemorelosCenter,
                  onTap: (point) => setState(() => _point = point),
                  markers: [
                    if (_point != null)
                      Marker(
                        point: _point!,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFF0B8F4D),
                          size: 48,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _point == null
                  ? 'Sin punto seleccionado. Puedes guardar la dirección y ubicarla después.'
                  : 'Ubicación seleccionada · ${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}',
            ),
            if (_point != null)
              TextButton(
                onPressed: () => setState(() => _point = null),
                child: const Text('Quitar ubicación'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Guardando…' : 'Guardar cancha'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(TextEditingController controller, String label, int max) =>
      TextFormField(
        controller: controller,
        maxLength: max,
        decoration: InputDecoration(labelText: label, counterText: ''),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Completa este campo.'
            : null,
      );
}
