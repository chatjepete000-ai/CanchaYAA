import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/team_join_code_repository.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
  });

  @override
  State<QrScannerScreen> createState() =>
      _QrScannerScreenState();
}

class _QrScannerScreenState
    extends State<QrScannerScreen> {
  final MobileScannerController _controller =
      MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const <BarcodeFormat>[
      BarcodeFormat.qrCode,
    ],
  );

  bool _processing = false;
  bool _torchEnabled = false;

  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetection(
    BarcodeCapture capture,
  ) async {
    if (_processing) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }

    final rawValue =
        capture.barcodes.first.rawValue?.trim();

    if (rawValue == null ||
        rawValue.isEmpty) {
      return;
    }

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    final code =
        TeamJoinCodeRepository
            .extractCodeFromQrPayload(
      rawValue,
    );

    if (code == null ||
        code.trim().isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processing = false;
        _errorMessage =
            'Este QR no pertenece a una invitación válida de CanchaYA.';
      });

      return;
    }

    await _controller.stop();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(
      code,
    );
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();

      if (!mounted) {
        return;
      }

      setState(() {
        _torchEnabled =
            !_torchEnabled;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cambiar el estado de la linterna.',
          ),
        ),
      );
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cambiar de cámara.',
          ),
        ),
      );
    }
  }

  Future<void> _resumeScanner() async {
    setState(() {
      _processing = false;
      _errorMessage = null;
    });

    try {
      await _controller.start();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'No se pudo iniciar nuevamente la cámara.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Scaffold(
      backgroundColor:
          Colors.black,
      appBar: AppBar(
        backgroundColor:
            Colors.black,
        foregroundColor:
            Colors.white,
        title: const Text(
          'Escanear QR',
        ),
        actions: [
          IconButton(
            tooltip:
                'Cambiar cámara',
            onPressed:
                _processing
                    ? null
                    : _switchCamera,
            icon: const Icon(
              CupertinoIcons.switch_camera_solid,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller:
                _controller,
            onDetect:
                _handleDetection,
            errorBuilder: (
              context,
              error,
            ) {
              return _CameraError(
                message:
                    error.errorDetails?.message ??
                        'No se pudo abrir la cámara.',
              );
            },
          ),

          IgnorePointer(
            child: CustomPaint(
              painter:
                  _ScannerOverlayPainter(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                Container(
                  margin:
                      const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    24,
                  ),
                  padding:
                      const EdgeInsets.all(
                    18,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.black
                        .withValues(
                      alpha: 0.78,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                    border:
                        Border.all(
                      color: Colors.white
                          .withValues(
                        alpha: 0.14,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      if (_errorMessage ==
                          null) ...[
                        const Text(
                          'Coloca el código QR dentro del cuadro',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),

                        const SizedBox(
                          height: 7,
                        ),

                        Text(
                          _processing
                              ? 'Leyendo invitación...'
                              : 'CanchaYA detectará automáticamente el acceso del equipo.',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color: Colors
                                .white
                                .withValues(
                              alpha:
                                  0.76,
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Icon(
                              CupertinoIcons
                                  .exclamationmark_triangle_fill,
                              color:
                                  Colors.orangeAccent,
                            ),

                            const SizedBox(
                              width: 10,
                            ),

                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        SizedBox(
                          width:
                              double.infinity,
                          child:
                              FilledButton.icon(
                            onPressed:
                                _resumeScanner,
                            icon:
                                const Icon(
                              CupertinoIcons
                                  .refresh,
                            ),
                            label:
                                const Text(
                              'Intentar otra vez',
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 18,
                      ),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          _CameraControlButton(
                            icon: _torchEnabled
                                ? CupertinoIcons
                                    .lightbulb_fill
                                : CupertinoIcons
                                    .lightbulb,
                            label:
                                _torchEnabled
                                    ? 'Apagar'
                                    : 'Linterna',
                            onPressed:
                                _processing
                                    ? null
                                    : _toggleTorch,
                          ),

                          const SizedBox(
                            width: 14,
                          ),

                          _CameraControlButton(
                            icon:
                                CupertinoIcons
                                    .number,
                            label:
                                'Código manual',
                            onPressed:
                                () {
                              Navigator.of(
                                context,
                              ).pop();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_processing)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black
                      .withValues(
                    alpha: 0.18,
                  ),
                  alignment:
                      Alignment.center,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration:
                        BoxDecoration(
                      color: colors.surface
                          .withValues(
                        alpha: 0.96,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2.5,
                          ),
                        ),
                        SizedBox(
                          width: 12,
                        ),
                        Text(
                          'Leyendo QR...',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraControlButton
    extends StatelessWidget {
  const _CameraControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white
          .withValues(
        alpha: 0.12,
      ),
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                    onPressed == null
                        ? Colors.white38
                        : Colors.white,
                size: 23,
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                label,
                style:
                    TextStyle(
                  color:
                      onPressed == null
                          ? Colors.white38
                          : Colors.white,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraError
    extends StatelessWidget {
  const _CameraError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding:
          const EdgeInsets.all(
        24,
      ),
      alignment:
          Alignment.center,
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons
                .camera_fill,
            color:
                Colors.white,
            size: 52,
          ),

          const SizedBox(
            height: 16,
          ),

          const Text(
            'No pudimos acceder a la cámara',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 18,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            message,
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color: Colors.white
                  .withValues(
                alpha: 0.72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final scanSize =
        size.width * 0.72;

    final safeScanSize =
        scanSize.clamp(
      220.0,
      320.0,
    );

    final left =
        (size.width -
                safeScanSize) /
            2;

    final top =
        (size.height -
                safeScanSize) /
            2 -
            40;

    final rect =
        Rect.fromLTWH(
      left,
      top,
      safeScanSize,
      safeScanSize,
    );

    final overlayPaint =
        Paint()
          ..color = Colors.black
              .withValues(
            alpha: 0.48,
          );

    final fullPath =
        Path()
          ..addRect(
            Offset.zero &
                size,
          );

    final holePath =
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              rect,
              const Radius.circular(
                24,
              ),
            ),
          );

    final overlayPath =
        Path.combine(
      PathOperation.difference,
      fullPath,
      holePath,
    );

    canvas.drawPath(
      overlayPath,
      overlayPaint,
    );

    final borderPaint =
        Paint()
          ..color =
              Colors.white
          ..style =
              PaintingStyle.stroke
          ..strokeWidth =
              3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(
          24,
        ),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}