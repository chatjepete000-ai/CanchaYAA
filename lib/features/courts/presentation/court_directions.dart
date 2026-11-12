import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/court.dart';

// ================================================================
// F07 · "CÓMO LLEGAR"
// ================================================================
//
// Criterio de aceptación:
// - Abrir la app de mapas con la ruta a la cancha.
// - Si faltan coordenadas, buscar por dirección y avisarlo.
// - Si falta internet o no se puede abrir el mapa, mostrar la
//   dirección con un mensaje claro (y permitir copiarla).
// - Nunca se pide la ubicación del jugador.
// ================================================================

/// Lee la cancha del servidor y, sin conexión, de la caché local.
Future<Court?> _loadCourt(String courtId) async {
  final reference =
      FirebaseFirestore.instance.collection('courts').doc(courtId);

  DocumentSnapshot<Map<String, dynamic>> snapshot;

  try {
    snapshot = await reference.get();
  } catch (_) {
    snapshot = await reference.get(
      const GetOptions(source: Source.cache),
    );
  }

  final data = snapshot.data();

  if (!snapshot.exists || data == null) {
    return null;
  }

  return Court.fromMap(snapshot.id, data);
}

Future<void> openCourtDirections(
  BuildContext context, {
  required String? courtId,
  String? courtName,
}) async {
  final cleanId = courtId?.trim() ?? '';

  if (cleanId.isEmpty) {
    _snack(context, 'Este partido todavía no tiene cancha asignada.');
    return;
  }

  Court? court;

  try {
    court = await _loadCourt(cleanId);
  } catch (_) {
    court = null;
  }

  if (!context.mounted) {
    return;
  }

  if (court == null) {
    await _showAddressDialog(
      context,
      title: courtName ?? 'Cancha',
      address: null,
      reason: 'No hay conexión y la información de esta cancha no está '
          'guardada en el teléfono. Intenta de nuevo cuando tengas internet.',
    );
    return;
  }

  if (!court.hasCoordinates) {
    _snack(
      context,
      'Esta cancha no tiene ubicación exacta; se buscará por su dirección.',
    );
  }

  var opened = false;

  try {
    opened = await launchUrl(
      court.directionsUri,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }

  if (!opened && context.mounted) {
    await _showAddressDialog(
      context,
      title: court.name,
      address: _fullAddress(court),
      reason: 'No se pudo abrir la aplicación de mapas. Revisa tu conexión '
          'o usa esta dirección:',
    );
  }
}

String _fullAddress(Court court) {
  return [
    court.address.trim(),
    court.city.trim(),
  ].where((part) => part.isNotEmpty).join(', ');
}

Future<void> _showAddressDialog(
  BuildContext context, {
  required String title,
  required String? address,
  required String reason,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final hasAddress = address != null && address.isNotEmpty;

      return AlertDialog(
        icon: const Icon(CupertinoIcons.map_pin_ellipse),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            if (hasAddress) ...[
              const SizedBox(height: 12),
              SelectableText(
                address,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
        actions: [
          if (hasAddress)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: address));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (context.mounted) {
                  _snack(context, 'Dirección copiada.');
                }
              },
              icon: const Icon(CupertinoIcons.doc_on_doc),
              label: const Text('Copiar'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      );
    },
  );
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text)),
  );
}
