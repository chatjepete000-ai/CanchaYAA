import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

const montemorelosCenter = LatLng(25.187, -99.828);

/// No location permission: the map always starts at the city or selected court.
class CourtMap extends StatefulWidget {
  const CourtMap({
    super.key,
    this.center = montemorelosCenter,
    this.markers = const [],
    this.onTap,
    this.controller,
  });
  final LatLng center;
  final List<Marker> markers;
  final ValueChanged<LatLng>? onTap;
  final MapController? controller;

  @override
  State<CourtMap> createState() => _CourtMapState();
}

class _CourtMapState extends State<CourtMap> {
  bool _failed = false;
  int _attempt = 0;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      FlutterMap(
        mapController: widget.controller,
        options: MapOptions(
          initialCenter: widget.center,
          initialZoom: 13,
          minZoom: 3,
          maxZoom: 19,
          onTap: (_, point) => widget.onTap?.call(point),
        ),
        children: [
          TileLayer(
            key: ValueKey(_attempt),
            urlTemplate: const String.fromEnvironment(
              'MAP_TILE_URL',
              defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            userAgentPackageName: 'com.canchaya.cancha_ya',
            maxNativeZoom: 19,
            errorTileCallback: (_, _, _) {
              if (!_failed && mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _failed = true);
                });
              }
            },
          ),
          MarkerLayer(markers: widget.markers),
          SimpleAttributionWidget(
            source: const Text(
              'OpenStreetMap contributors',
              style: TextStyle(fontSize: 11),
            ),
            onTap: () => openCourtLink(
              context,
              Uri.parse('https://www.openstreetmap.org/copyright'),
            ),
          ),
        ],
      ),
      if (_failed)
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Material(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'No se pudo cargar el mapa. Revisa tu conexión; las direcciones siguen disponibles.',
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _failed = false;
                      _attempt++;
                    }),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

Future<void> openCourtLink(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    /* A missing maps app must not break the court detail. */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo abrir el enlace. Puedes copiar la dirección de la cancha.',
        ),
      ),
    );
  }
}
