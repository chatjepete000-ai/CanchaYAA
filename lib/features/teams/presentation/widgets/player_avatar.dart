import 'package:flutter/material.dart';

import '../../domain/player_photo.dart';

/// Foto circular del jugador centrada en la cara.
///
/// Si no tiene foto (o no es de confianza), muestra su inicial.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.size = 40,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 0,
  });

  final String name;
  final String photoUrl;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final thumbnail = playerFaceThumbnailUrl(
      photoUrl,
      size: (size * 3).clamp(96, 400).round(),
    );

    final initial = Center(
      child: Text(
        playerInitial(name),
        style: TextStyle(
          color: foregroundColor ?? colors.primary,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? colors.primaryContainer,
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? Colors.white, width: borderWidth)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: thumbnail.isEmpty
          ? initial
          : Image.network(
              thumbnail,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => initial,
            ),
    );
  }
}
