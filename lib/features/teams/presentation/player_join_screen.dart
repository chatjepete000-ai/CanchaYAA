import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/team_join_code_repository.dart';
import '../domain/team_join_code.dart';
import '../domain/team_models.dart';
import 'qr_scanner_screen.dart';

class PlayerJoinScreen extends StatefulWidget {
  const PlayerJoinScreen({
    super.key,
    this.initialCode,
  });

  final String? initialCode;

  @override
  State<PlayerJoinScreen> createState() =>
      _PlayerJoinScreenState();
}

class _PlayerJoinScreenState
    extends State<PlayerJoinScreen> {
  final TeamJoinCodeRepository _joinCodeRepository =
      TeamJoinCodeRepository();

  final TextEditingController _codeController =
      TextEditingController();

  TeamJoinCode? _validatedAccess;

  bool _validating = false;
  bool _joining = false;

  String? _validationMessage;

  @override
  void initState() {
    super.initState();

    final initialCode =
        widget.initialCode?.trim();

    if (initialCode != null &&
        initialCode.isNotEmpty) {
      _codeController.text =
          TeamJoinCodeRepository.normalizeCode(
        initialCode,
      );

      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          _validateCode();
        },
      );
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // =============================================================
  // ESCANEAR QR
  // =============================================================

  Future<void> _scanQr() async {
    FocusScope.of(context).unfocus();

    final scannedCode =
        await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            const QrScannerScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    if (scannedCode == null ||
        scannedCode.trim().isEmpty) {
      return;
    }

    final normalizedCode =
        TeamJoinCodeRepository.normalizeCode(
      scannedCode,
    );

    _codeController.text =
        normalizedCode;

    setState(() {
      _validatedAccess = null;
      _validationMessage = null;
    });

    await _validateCode();
  }

  // =============================================================
  // VALIDAR CÓDIGO
  // =============================================================

  Future<void> _validateCode() async {
    FocusScope.of(context).unfocus();

    final rawCode =
        _codeController.text;

    final code =
        TeamJoinCodeRepository.normalizeCode(
      rawCode,
    );

    if (code.isEmpty) {
      setState(() {
        _validatedAccess = null;
        _validationMessage =
            'Escribe el código de invitación.';
      });

      return;
    }

    setState(() {
      _validating = true;
      _validatedAccess = null;
      _validationMessage = null;
    });

    try {
      final access =
          await _joinCodeRepository.getByCode(
        code,
      );

      if (!mounted) {
        return;
      }

      if (access == null) {
        setState(() {
          _validationMessage =
              'No encontramos una invitación con ese código.';
        });

        return;
      }

      if (!access.isPlayerInvitation) {
        setState(() {
          _validationMessage =
              'Este código no corresponde a una invitación para jugador.';
        });

        return;
      }

      if (!access.isActive) {
        setState(() {
          _validationMessage =
              'Esta invitación ya fue utilizada, revocada o expiró.';
        });

        return;
      }

      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          _validationMessage =
              'Debes iniciar sesión para utilizar esta invitación.';
        });

        return;
      }

      final invitedUserId =
          access.invitedUserId?.trim() ?? '';

      if (invitedUserId.isNotEmpty &&
          invitedUserId != user.uid) {
        setState(() {
          _validationMessage =
              'Esta invitación pertenece a otra cuenta.';
        });

        return;
      }

      final invitedEmail =
          access.invitedEmail
                  ?.trim()
                  .toLowerCase() ??
              '';

      final currentEmail =
          user.email
                  ?.trim()
                  .toLowerCase() ??
              '';

      if (invitedEmail.isNotEmpty &&
          invitedEmail != currentEmail) {
        setState(() {
          _validationMessage =
              'Esta invitación fue enviada a otro correo.';
        });

        return;
      }

      _codeController.text =
          access.code;

      setState(() {
        _validatedAccess =
            access;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _validationMessage =
            'No se pudo validar el código. '
            'Firebase: ${error.code}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _validationMessage =
            'No se pudo validar la invitación: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _validating = false;
        });
      }
    }
  }

  // =============================================================
  // UNIRSE AL EQUIPO
  // =============================================================

  Future<void> _joinTeam() async {
    final access =
        _validatedAccess;

    if (access == null ||
        _joining) {
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Debes iniciar sesión para unirte al equipo.',
      );

      return;
    }

    setState(() {
      _joining = true;
    });

    try {
      await _acceptPlayerInvitation(
        access: access,
        user: user,
      );

      if (!mounted) {
        return;
      }

      await _showSuccessDialog();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        true,
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message;

      switch (error.code) {
        case 'permission-denied':
          message =
              'Firestore rechazó la operación. '
              'La invitación no pudo utilizarse con los permisos actuales.';
          break;

        case 'not-found':
          message =
              'El equipo o la invitación ya no existen.';
          break;

        default:
          message =
              'No se pudo completar el ingreso. '
              'Firebase: ${error.code}.';
      }

      _showMessage(
        message,
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message.toString(),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'No se pudo completar el ingreso al equipo: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }

  Future<void> _acceptPlayerInvitation({
    required TeamJoinCode access,
    required User user,
  }) async {
    final firestore =
        FirebaseFirestore.instance;

    final codeId =
        TeamJoinCodeRepository.normalizeCode(
      access.id,
    );

    if (codeId.isEmpty) {
      throw StateError(
        'La invitación no contiene un código válido.',
      );
    }

    if (!access.isPlayerInvitation) {
      throw StateError(
        'La invitación no corresponde a un jugador.',
      );
    }

    if (!access.isActive) {
      throw StateError(
        'Esta invitación ya no está disponible.',
      );
    }

    final currentEmail =
        user.email
                ?.trim()
                .toLowerCase() ??
            '';

    final invitedEmail =
        access.invitedEmail
                ?.trim()
                .toLowerCase() ??
            '';

    if (invitedEmail.isNotEmpty &&
        invitedEmail != currentEmail) {
      throw StateError(
        'Esta invitación pertenece a otro correo.',
      );
    }

    final invitedUserId =
        access.invitedUserId?.trim() ?? '';

    if (invitedUserId.isNotEmpty &&
        invitedUserId != user.uid) {
      throw StateError(
        'Esta invitación pertenece a otra cuenta.',
      );
    }

    final teamId =
        access.teamId.trim();

    final leagueId =
        access.leagueId.trim();

    final tournamentId =
        access.tournamentId?.trim() ?? '';

    if (teamId.isEmpty ||
        leagueId.isEmpty ||
        tournamentId.isEmpty) {
      throw StateError(
        'La invitación no contiene la información completa del equipo.',
      );
    }

    final codeRef =
        firestore
            .collection(
              'teamJoinCodes',
            )
            .doc(
              codeId,
            );

    final teamRef =
        firestore
            .collection(
              'teams',
            )
            .doc(
              teamId,
            );

    final assignmentRef =
        firestore
            .collection(
              'teamAssignments',
            )
            .doc(
              codeId,
            );

    final assignment =
        TeamAssignment(
      id: codeId,
      userId: user.uid,
      userEmail:
          currentEmail,
      userDisplayName:
          user.displayName?.trim() ?? '',
      teamId:
          teamId,
      leagueId:
          leagueId,
      tournamentId:
          tournamentId,
      role:
          TeamAssignmentRole.player,
      status:
          AssignmentStatus.active,
      assignedByUserId:
          access.createdByUserId.trim(),
    );

    final batch =
        firestore.batch();

    batch.set(
      assignmentRef,
      <String, dynamic>{
        ...assignment.toMap(),
        'createdAt':
            FieldValue.serverTimestamp(),
        'acceptedAt':
            FieldValue.serverTimestamp(),
        'joinCodeId':
            codeId,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      teamRef,
      <String, dynamic>{
        'playerUserIds':
            FieldValue.arrayUnion(
          <String>[
            user.uid,
          ],
        ),
        'lastPlayerJoinCodeId':
            codeId,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      codeRef,
      <String, dynamic>{
        'status':
            TeamJoinCodeStatus.used.value,
        'usedByUserId':
            user.uid,
        'usedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  Future<void>
      _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          icon: const Icon(
            CupertinoIcons
                .check_mark_circled_solid,
            size: 42,
          ),
          title: const Text(
            'Ya eres parte del equipo',
          ),
          content: const Text(
            'La invitación fue utilizada correctamente '
            'y tu cuenta quedó registrada como jugador.',
            textAlign:
                TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text(
                'Continuar',
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),
      ),
    );
  }

  void _onCodeChanged(
    String value,
  ) {
    setState(() {
      _validatedAccess = null;
      _validationMessage = null;
    });
  }

  // =============================================================
  // INTERFAZ
  // =============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final access =
        _validatedAccess;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Unirme a un equipo',
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics:
              const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            32,
          ),
          children: [
            Container(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topLeft,
                  end:
                      Alignment.bottomRight,
                  colors: [
                    colors.primary,
                    colors.primary
                        .withValues(
                      alpha:
                          0.76,
                    ),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withValues(
                        alpha:
                            0.17,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons
                          .person_add_solid,
                      color:
                          Colors.white,
                      size: 26,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  Text(
                    'Únete con tu invitación',
                    style: theme
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          color:
                              Colors.white,
                          fontWeight:
                              FontWeight.w900,
                        ),
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  Text(
                    'Escanea el QR del encargado o escribe '
                    'manualmente el código de acceso.',
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: Colors.white
                              .withValues(
                            alpha:
                                0.88,
                          ),
                          height:
                              1.4,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            // =====================================================
            // ESCANEAR QR
            // =====================================================

            SizedBox(
              width:
                  double.infinity,
              child:
                  FilledButton.icon(
                onPressed:
                    _validating ||
                            _joining
                        ? null
                        : _scanQr,
                icon:
                    const Icon(
                  CupertinoIcons.qrcode,
                ),
                label:
                    const Text(
                  'Escanear código QR',
                ),
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      Divider(
                    color: colors
                        .outlineVariant,
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        12,
                  ),
                  child: Text(
                    'o escribe el código',
                    style: theme
                        .textTheme
                        .bodySmall,
                  ),
                ),

                Expanded(
                  child:
                      Divider(
                    color: colors
                        .outlineVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              'Código de invitación',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
            ),

            const SizedBox(
              height: 10,
            ),

            TextField(
              controller:
                  _codeController,
              enabled:
                  !_joining,
              textCapitalization:
                  TextCapitalization.characters,
              autocorrect:
                  false,
              enableSuggestions:
                  false,
              onChanged:
                  _onCodeChanged,
              onSubmitted:
                  (_) {
                if (!_validating &&
                    !_joining) {
                  _validateCode();
                }
              },
              decoration:
                  InputDecoration(
                hintText:
                    'CYA-XXXX-XXXX',
                prefixIcon:
                    const Icon(
                  CupertinoIcons.number,
                ),
                suffixIcon:
                    _codeController
                            .text
                            .isNotEmpty
                        ? IconButton(
                            tooltip:
                                'Limpiar',
                            onPressed:
                                _joining
                                    ? null
                                    : () {
                                        _codeController
                                            .clear();

                                        setState(
                                          () {
                                            _validatedAccess =
                                                null;

                                            _validationMessage =
                                                null;
                                          },
                                        );
                                      },
                            icon:
                                const Icon(
                              CupertinoIcons
                                  .clear_circled,
                            ),
                          )
                        : null,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            SizedBox(
              width:
                  double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed:
                    _validating ||
                            _joining
                        ? null
                        : _validateCode,
                icon:
                    _validating
                        ? const SizedBox(
                            width:
                                18,
                            height:
                                18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            CupertinoIcons
                                .check_mark_circled,
                          ),
                label:
                    Text(
                  _validating
                      ? 'Validando...'
                      : 'Validar código',
                ),
              ),
            ),

            if (_validationMessage !=
                null) ...[
              const SizedBox(
                height: 16,
              ),
              _MessageCard(
                message:
                    _validationMessage!,
                isError:
                    true,
              ),
            ],

            if (access != null) ...[
              const SizedBox(
                height: 24,
              ),

              _ValidAccessCard(
                access:
                    access,
              ),

              const SizedBox(
                height: 18,
              ),

              SizedBox(
                width:
                    double.infinity,
                child:
                    FilledButton.icon(
                  onPressed:
                      _joining
                          ? null
                          : _joinTeam,
                  icon:
                      _joining
                          ? const SizedBox(
                              width:
                                  18,
                              height:
                                  18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              CupertinoIcons
                                  .person_2_fill,
                            ),
                  label:
                      Text(
                    _joining
                        ? 'Uniéndote al equipo...'
                        : 'Unirme al equipo',
                  ),
                ),
              ),
            ],

            const SizedBox(
              height: 24,
            ),

            Container(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration:
                  BoxDecoration(
                color: colors
                    .surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons
                        .shield_fill,
                    color:
                        colors.primary,
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  const Expanded(
                    child: Text(
                      'Cada código solamente puede utilizarse una vez. '
                      'Si fue creado para un correo específico, únicamente '
                      'esa cuenta podrá aceptar la invitación.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================================================
// INVITACIÓN VALIDADA
// ===============================================================

class _ValidAccessCard
    extends StatelessWidget {
  const _ValidAccessCard({
    required this.access,
  });

  final TeamJoinCode access;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final email =
        access.invitedEmail?.trim() ?? '';

    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color: colors
            .primaryContainer
            .withValues(
          alpha: 0.45,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color: colors.primary
              .withValues(
            alpha:
                0.25,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color:
                      colors.primary,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  CupertinoIcons
                      .check_mark_circled_solid,
                  color:
                      colors.onPrimary,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitación válida',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w900,
                          ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    const Text(
                      'Acceso para unirte como jugador',
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          _AccessDetail(
            icon:
                CupertinoIcons.number,
            label:
                'Código',
            value:
                access.code,
          ),

          const SizedBox(
            height: 11,
          ),

          _AccessDetail(
            icon:
                CupertinoIcons
                    .sportscourt_fill,
            label:
                'Tipo de acceso',
            value:
                access.purpose.label,
          ),

          const SizedBox(
            height: 11,
          ),

          _AccessDetail(
            icon: access.isQrAccess
                ? CupertinoIcons.qrcode
                : CupertinoIcons
                    .envelope_fill,
            label:
                'Forma de invitación',
            value:
                access.delivery.label,
          ),

          if (email.isNotEmpty) ...[
            const SizedBox(
              height: 11,
            ),

            _AccessDetail(
              icon:
                  CupertinoIcons.mail_solid,
              label:
                  'Invitado',
              value:
                  email,
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessDetail
    extends StatelessWidget {
  const _AccessDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color:
              colors.primary,
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                value,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageCard
    extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color: isError
            ? colors.errorContainer
            : colors.primaryContainer,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? CupertinoIcons
                    .exclamationmark_triangle_fill
                : CupertinoIcons
                    .check_mark_circled_solid,
            color: isError
                ? colors
                    .onErrorContainer
                : colors.primary,
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child: Text(
              message,
              style:
                  TextStyle(
                color: isError
                    ? colors
                        .onErrorContainer
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}