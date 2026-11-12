import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

// ================================================================
// F06 · IMAGEN "LOCAL VS VISITANTE" PARA LA NOTIFICACIÓN
// ================================================================
//
// Dibuja los escudos de ambos equipos (desde publicTeams.logoUrl)
// con "VS" en medio y los nombres cortos. Si un equipo no tiene
// escudo o no hay internet, se dibuja un escudo genérico con sus
// iniciales. Devuelve un PNG para BigPictureStyle de Android.
// ================================================================

class MatchCrestImage {
  const MatchCrestImage._();

  static const double _width = 720;
  static const double _height = 360;
  static const double _crest = 150;

  static const Color _background = Color(0xFF0B3D25);
  static const Color _accent = Color(0xFF43E97B);

  static Future<Uint8List?> build({
    required String homeName,
    required String awayName,
    String homeLogoUrl = '',
    String awayLogoUrl = '',
  }) async {
    try {
      final images = await Future.wait([
        _loadImage(homeLogoUrl),
        _loadImage(awayLogoUrl),
      ]);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        const Rect.fromLTWH(0, 0, _width, _height),
      );

      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _width, _height),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(_width, _height),
            [_background, const Color(0xFF0B8F4D)],
          ),
      );

      const homeCenter = Offset(_width * 0.22, _height * 0.42);
      const awayCenter = Offset(_width * 0.78, _height * 0.42);

      _drawCrest(canvas, homeCenter, images[0], homeName);
      _drawCrest(canvas, awayCenter, images[1], awayName);

      _drawText(
        canvas,
        'VS',
        center: const Offset(_width / 2, _height * 0.42),
        width: 160,
        fontSize: 56,
        color: _accent,
        weight: FontWeight.w900,
      );

      _drawText(
        canvas,
        homeName,
        center: Offset(homeCenter.dx, _height * 0.83),
        width: 300,
        fontSize: 28,
        color: const Color(0xFFFFFFFF),
        weight: FontWeight.w800,
      );

      _drawText(
        canvas,
        awayName,
        center: Offset(awayCenter.dx, _height * 0.83),
        width: 300,
        fontSize: 28,
        color: const Color(0xFFFFFFFF),
        weight: FontWeight.w800,
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(_width.toInt(), _height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();
      picture.dispose();

      for (final loaded in images) {
        loaded?.dispose();
      }

      return bytes?.buffer.asUint8List();
    } catch (_) {
      // Sin imagen la notificación se muestra igual, solo con texto.
      return null;
    }
  }

  static Future<ui.Image?> _loadImage(String url) async {
    final clean = url.trim();

    if (clean.isEmpty || !clean.startsWith('https://')) {
      return null;
    }

    try {
      final response = await http
          .get(Uri.parse(clean))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      final codec = await ui.instantiateImageCodec(
        response.bodyBytes,
        targetWidth: _crest.toInt() * 2,
      );
      final frame = await codec.getNextFrame();

      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static void _drawCrest(
    Canvas canvas,
    Offset center,
    ui.Image? image,
    String name,
  ) {
    final rect = Rect.fromCenter(
      center: center,
      width: _crest,
      height: _crest,
    );
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(36));

    canvas.drawRRect(
      rounded.inflate(6),
      Paint()..color = const Color(0x33FFFFFF),
    );
    canvas.drawRRect(rounded, Paint()..color = const Color(0xFFFFFFFF));

    if (image != null) {
      canvas.save();
      canvas.clipRRect(rounded);
      paintImage(
        canvas: canvas,
        rect: rect.deflate(8),
        image: image,
        fit: BoxFit.contain,
      );
      canvas.restore();
      return;
    }

    _drawText(
      canvas,
      _initials(name),
      center: center,
      width: _crest,
      fontSize: 54,
      color: _background,
      weight: FontWeight.w900,
    );
  }

  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }

    return (words[0][0] + words[1][0]).toUpperCase();
  }

  static void _drawText(
    Canvas canvas,
    String text, {
    required Offset center,
    required double width,
    required double fontSize,
    required Color color,
    required FontWeight weight,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
        ),
      )
      ..addText(text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width));

    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - width / 2, center.dy - paragraph.height / 2),
    );
  }
}
