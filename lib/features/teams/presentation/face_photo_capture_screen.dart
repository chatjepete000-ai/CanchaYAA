import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../profile/data/cloudinary_profile_photo_service.dart';
import '../../profile/data/profile_repository.dart';
import '../data/face_photo_detector.dart';
import '../domain/player_photo.dart';

// ================================================================
// FOTO DE CARA PARA UNIRSE AL EQUIPO
// ================================================================
//
// 1. El jugador se toma una selfie con la cámara frontal
//    (no se permite elegir de la galería).
// 2. ML Kit revisa en el teléfono que haya una sola cara, de
//    frente y lo bastante cerca (nada de cuerpo completo).
// 3. Al confirmar, se sube a Cloudinary, se guarda como foto de
//    perfil y la pantalla devuelve la URL.
// ================================================================

class FacePhotoCaptureScreen extends StatefulWidget {
  const FacePhotoCaptureScreen({
    super.key,
    this.title = 'Foto para tu equipo',
    this.confirmLabel = 'Usar esta foto',
  });

  final String title;
  final String confirmLabel;

  @override
  State<FacePhotoCaptureScreen> createState() => _FacePhotoCaptureScreenState();
}

class _FacePhotoCaptureScreenState extends State<FacePhotoCaptureScreen> {
  final ImagePicker _picker = ImagePicker();

  final FacePhotoDetector _detector = const FacePhotoDetector();

  XFile? _photo;
  Uint8List? _photoBytes;
  FacePhotoIssue? _issue;

  bool _checking = false;
  bool _uploading = false;

  String? _error;

  bool get _busy => _checking || _uploading;

  bool get _canConfirm => _photo != null && _issue?.isValid == true && !_busy;

  Future<void> _takePhoto() async {
    setState(() {
      _error = null;
    });

    XFile? photo;

    try {
      photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'No se pudo abrir la cámara. Revisa que CanchaYA '
            'tenga permiso para usarla.';
      });

      return;
    }

    if (photo == null || !mounted) {
      return;
    }

    final bytes = await photo.readAsBytes();

    if (!mounted) return;

    setState(() {
      _photo = photo;
      _photoBytes = bytes;
      _issue = null;
      _checking = true;
    });

    try {
      final issue = await _detector.check(photo);

      if (!mounted) return;

      setState(() {
        _issue = issue;
      });
    } on FacePhotoUnavailableException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo revisar la foto. Intenta de nuevo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _confirm() async {
    final photo = _photo;

    if (photo == null || !_canConfirm) {
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final url = await CloudinaryProfilePhotoService().uploadProfilePhoto(
        photo,
      );

      if (!isTrustedPlayerPhotoUrl(url)) {
        throw const CloudinaryProfilePhotoException(
          'La foto se subió a un destino no válido.',
        );
      }

      // Una sola foto: también queda como foto de perfil.
      // Si esto falla, la foto del equipo sigue siendo válida.
      try {
        await ProfileRepository().updateProfilePhoto(url);
      } catch (_) {}

      if (!mounted) return;

      Navigator.of(context).pop(url);
    } on CloudinaryProfilePhotoException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo subir la foto. Revisa tu conexión.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final issue = _issue;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Tómate una foto de la cara',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Aparecerá en la plantilla y en la alineación de tu equipo. '
            'Solo la ven tu equipo y el administrador de la liga.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          Center(
            child: _FacePreview(bytes: _photoBytes, valid: issue?.isValid),
          ),
          const SizedBox(height: 18),
          if (_checking)
            const _StatusRow(icon: null, text: 'Revisando la foto…')
          else if (issue != null)
            _StatusRow(
              icon: issue.isValid
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.exclamationmark_circle_fill,
              color: issue.isValid ? colors.primary : colors.error,
              text: issue.isValid
                  ? 'Foto lista. Se ve bien tu cara.'
                  : issue.message,
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _StatusRow(
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              color: colors.error,
              text: _error!,
            ),
          ],
          const SizedBox(height: 18),
          const _TipsCard(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_canConfirm || _uploading) ...[
                FilledButton.icon(
                  onPressed: _canConfirm ? _confirm : null,
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.checkmark_alt),
                  label: Text(
                    _uploading ? 'Subiendo foto…' : widget.confirmLabel,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (_photo == null)
                FilledButton.icon(
                  onPressed: _busy ? null : _takePhoto,
                  icon: const Icon(CupertinoIcons.camera_fill),
                  label: const Text('Tomar foto'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _busy ? null : _takePhoto,
                  icon: const Icon(CupertinoIcons.camera_fill),
                  label: const Text('Tomar otra foto'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacePreview extends StatelessWidget {
  const _FacePreview({required this.bytes, required this.valid});

  final Uint8List? bytes;
  final bool? valid;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final borderColor = valid == null
        ? colors.outlineVariant
        : (valid! ? colors.primary : colors.error);

    final data = bytes;

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primaryContainer.withValues(alpha: 0.5),
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: data == null
          ? Icon(
              CupertinoIcons.person_crop_circle,
              size: 110,
              color: colors.primary.withValues(alpha: 0.6),
            )
          : Image.memory(data, fit: BoxFit.cover),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.text, this.color});

  final IconData? icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon == null)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    const tips = <(IconData, String)>[
      (
        CupertinoIcons.person_crop_circle,
        'Solo tu cara, de frente. Nada de cuerpo completo.',
      ),
      (CupertinoIcons.sun_max, 'Buena luz, sin lentes oscuros ni gorra.'),
      (CupertinoIcons.person_2, 'Sin otras personas en la foto.'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (final (icon, text) in tips)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
