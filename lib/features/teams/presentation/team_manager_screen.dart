import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/cloudinary_team_logo_service.dart';
import '../data/team_join_code_repository.dart';
import '../data/team_repository.dart';
import '../domain/team_join_code.dart';
import '../domain/team_models.dart';
import 'team_roster_screen.dart';

class TeamManagerScreen extends StatefulWidget {
  const TeamManagerScreen({
    super.key,
    required this.team,
  });

  final Team team;

  @override
  State<TeamManagerScreen> createState() =>
      _TeamManagerScreenState();
}

class _TeamManagerScreenState
    extends State<TeamManagerScreen> {
  final TeamRepository _teamRepository =
      TeamRepository();

  final CloudinaryTeamLogoService _logoService =
      CloudinaryTeamLogoService();

  final ImagePicker _imagePicker =
      ImagePicker();

  late Team _team;

  bool _updatingPresentation = false;

  @override
  void initState() {
    super.initState();

    _team = widget.team;
  }

  bool get _isDesktop {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform ==
            TargetPlatform.windows ||
        defaultTargetPlatform ==
            TargetPlatform.macOS ||
        defaultTargetPlatform ==
            TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Administrar equipo',
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics:
              const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),
          children: [
            _TeamHeaderCard(
              team: _team,
            ),

            const SizedBox(
              height: 20,
            ),

            Text(
              'Gestión del equipo',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w900,
                  ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Administra la plantilla, identidad visual y accesos de tus jugadores.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),

            const SizedBox(
              height: 14,
            ),

            // =====================================================
            // PLANTILLA
            // =====================================================

            _ManagerActionCard(
              icon:
                  CupertinoIcons.person_2_fill,
              title:
                  'Plantilla',
              subtitle:
                  'Consulta los jugadores registrados en este equipo.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TeamRosterScreen(
                      team: _team,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(
              height: 12,
            ),

            // =====================================================
            // INVITACIONES
            // =====================================================

            _ManagerActionCard(
              icon:
                  CupertinoIcons.person_add_solid,
              title:
                  'Invitar jugadores',
              subtitle:
                  'Genera un QR, código manual o acceso para un correo.',
              onTap: () {
                _showInvitationOptions(
                  context,
                );
              },
            ),

            const SizedBox(
              height: 12,
            ),

            // =====================================================
            // NOMBRE CORTO
            // =====================================================

            _ManagerActionCard(
              icon:
                  CupertinoIcons.textformat_alt,
              title:
                  'Nombre corto',
              subtitle: _team.hasShortName
                  ? _team.shortName
                  : 'Actual: ${_team.displayName}',
              onTap:
                  _updatingPresentation
                      ? null
                      : () {
                          _editShortName();
                        },
            ),

            const SizedBox(
              height: 12,
            ),

            // =====================================================
            // ESCUDO
            // =====================================================

            _ManagerActionCard(
              icon:
                  CupertinoIcons.photo_fill,
              imageUrl:
                  _team.logoUrl,
              title:
                  'Escudo del equipo',
              subtitle:
                  _team.hasLogo
                      ? 'Escudo configurado. Toca para cambiarlo.'
                      : 'Agrega el escudo oficial del equipo.',
              onTap:
                  _updatingPresentation
                      ? null
                      : () {
                          _openLogoOptions();
                        },
            ),

            const SizedBox(
              height: 12,
            ),

            // =====================================================
            // UNIFORME
            // =====================================================

            _ManagerActionCard(
              icon:
                  CupertinoIcons.sportscourt_fill,
              title:
                  'Uniforme',
              subtitle:
                  _team.uniformDescription
                          .trim()
                          .isNotEmpty
                      ? _team
                          .uniformDescription
                      : 'Registra la descripción del uniforme del equipo.',
              onTap: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La edición del uniforme será el siguiente apartado.',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(
              height: 20,
            ),

            _SecurityInfoCard(
              team: _team,
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // NOMBRE CORTO
  // ==============================================================

  Future<void> _editShortName() async {
    final controller =
        TextEditingController(
      text: _team.shortName,
    );

    String? errorText;

    final result =
        await showDialog<String>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            final preview =
                controller.text.trim();

            final previewName =
                preview.isEmpty
                    ? Team.compactName(
                        _team.name,
                      )
                    : preview;

            return AlertDialog(
              icon: const Icon(
                CupertinoIcons
                    .textformat_alt,
              ),
              title:
                  const Text(
                'Nombre corto',
              ),
              content:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    'Este nombre se usará en espacios pequeños como calendarios, resultados y tablas.',
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  TextField(
                    controller:
                        controller,
                    autofocus:
                        true,
                    maxLength:
                        20,
                    textCapitalization:
                        TextCapitalization
                            .words,
                    decoration:
                        InputDecoration(
                      labelText:
                          'Nombre corto',
                      hintText:
                          'Diablos Emiliano',
                      prefixIcon:
                          const Icon(
                        CupertinoIcons
                            .textformat,
                      ),
                      errorText:
                          errorText,
                      helperText:
                          'Déjalo vacío para usar una abreviación automática.',
                    ),
                    onChanged:
                        (_) {
                      setDialogState(
                        () {},
                      );
                    },
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Theme.of(
                        dialogContext,
                      )
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vista previa',
                          style: Theme.of(
                            dialogContext,
                          )
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          previewName,
                          style: Theme.of(
                            dialogContext,
                          )
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child:
                      const Text(
                    'Cancelar',
                  ),
                ),

                FilledButton(
                  onPressed:
                      () {
                    final value =
                        controller.text
                            .trim();

                    if (value.isNotEmpty &&
                        value.length < 2) {
                      setDialogState(
                        () {
                          errorText =
                              'Usa al menos 2 caracteres.';
                        },
                      );

                      return;
                    }

                    if (value.length >
                        20) {
                      setDialogState(
                        () {
                          errorText =
                              'Usa máximo 20 caracteres.';
                        },
                      );

                      return;
                    }

                    Navigator.of(
                      dialogContext,
                    ).pop(
                      value,
                    );
                  },
                  child:
                      const Text(
                    'Guardar',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (result == null ||
        !mounted) {
      return;
    }

    if (result.trim() ==
        _team.shortName.trim()) {
      return;
    }

    setState(() {
      _updatingPresentation =
          true;
    });

    _showLoadingDialog(
      context,
      'Guardando nombre corto...',
    );

    try {
      final updatedTeam =
          await _teamRepository
              .updateTeamShortName(
        team:
            _team,
        shortName:
            result,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      setState(() {
        _team =
            updatedTeam;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Nombre corto actualizado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      _showError(
        context,
        'No se pudo actualizar el nombre corto: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPresentation =
              false;
        });
      }
    }
  }

  // ==============================================================
  // ESCUDO
  // ==============================================================

  Future<void> _openLogoOptions() async {
    final action =
        await showModalBottomSheet<
            String>(
      context: context,
      showDragHandle:
          true,
      isScrollControlled:
          true,
      builder: (
        sheetContext,
      ) {
        final theme =
            Theme.of(
          sheetContext,
        );

        final colors =
            theme.colorScheme;

        return SafeArea(
          child:
              Padding(
            padding:
                const EdgeInsets.fromLTRB(
              22,
              4,
              22,
              28,
            ),
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  'Escudo del equipo',
                  style: theme
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  'Este escudo aparecerá en calendarios, partidos y resultados.',
                  textAlign:
                      TextAlign.center,
                  style: theme
                      .textTheme
                      .bodyMedium,
                ),

                const SizedBox(
                  height: 22,
                ),

                _LargeTeamLogo(
                  team:
                      _team,
                ),

                const SizedBox(
                  height: 14,
                ),

                Text(
                  _team.displayName,
                  textAlign:
                      TextAlign.center,
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                ),

                const SizedBox(
                  height: 22,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton.icon(
                    onPressed:
                        () {
                      Navigator.of(
                        sheetContext,
                      ).pop(
                        'select',
                      );
                    },
                    icon:
                        Icon(
                      _isDesktop
                          ? CupertinoIcons
                              .folder_open
                          : CupertinoIcons
                              .photo_on_rectangle,
                    ),
                    label:
                        Text(
                      _team.hasLogo
                          ? 'Cambiar escudo'
                          : 'Seleccionar escudo',
                    ),
                  ),
                ),

                if (_team.hasLogo) ...[
                  const SizedBox(
                    height: 8,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        TextButton.icon(
                      onPressed:
                          () {
                        Navigator.of(
                          sheetContext,
                        ).pop(
                          'remove',
                        );
                      },
                      icon:
                          const Icon(
                        CupertinoIcons
                            .trash,
                      ),
                      label:
                          const Text(
                        'Quitar escudo',
                      ),
                    ),
                  ),
                ],

                const SizedBox(
                  height: 12,
                ),

                Container(
                  padding:
                      const EdgeInsets.all(
                    13,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colors
                        .surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  child:
                      Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons
                            .shield_fill,
                        color:
                            colors.primary,
                        size: 19,
                      ),

                      const SizedBox(
                        width: 9,
                      ),

                      const Expanded(
                        child:
                            Text(
                          'Solo se utilizará la imagen que selecciones. Recomendamos un escudo cuadrado y con fondo limpio.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action ==
        'select') {
      await _pickAndUploadLogo();
    } else if (action ==
        'remove') {
      await _removeLogo();
    }
  }

  Future<void> _pickAndUploadLogo() async {
    XFile? image;

    try {
      image =
          await _imagePicker
              .pickImage(
        source:
            ImageSource.gallery,
        imageQuality:
            90,
        maxWidth:
            1200,
        maxHeight:
            1200,
        requestFullMetadata:
            false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        context,
        _isDesktop
            ? 'No se pudo abrir el explorador de archivos: $error'
            : 'No se pudo abrir la galería: $error',
      );

      return;
    }

    if (image == null ||
        !mounted) {
      return;
    }

    setState(() {
      _updatingPresentation =
          true;
    });

    _showLoadingDialog(
      context,
      'Subiendo escudo...',
    );

    try {
      final logoUrl =
          await _logoService
              .uploadTeamLogo(
        image,
      );

      final updatedTeam =
          await _teamRepository
              .updateTeamLogoUrl(
        team:
            _team,
        logoUrl:
            logoUrl,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      setState(() {
        _team =
            updatedTeam;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Escudo actualizado correctamente.',
          ),
        ),
      );
    } on CloudinaryTeamLogoException catch (
      error
    ) {
      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      _showError(
        context,
        error.message,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      _showError(
        context,
        'No se pudo actualizar el escudo: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPresentation =
              false;
        });
      }
    }
  }

  Future<void> _removeLogo() async {
    setState(() {
      _updatingPresentation =
          true;
    });

    _showLoadingDialog(
      context,
      'Quitando escudo...',
    );

    try {
      final updatedTeam =
          await _teamRepository
              .updateTeamPresentation(
        team:
            _team,
        logoUrl:
            '',
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      setState(() {
        _team =
            updatedTeam;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Escudo eliminado. Se usará el escudo predeterminado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      _showError(
        context,
        'No se pudo quitar el escudo: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPresentation =
              false;
        });
      }
    }
  }

  // ==============================================================
  // INVITACIONES
  // ==============================================================

  Future<void> _showInvitationOptions(
    BuildContext context,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled:
          true,
      showDragHandle:
          true,
      builder: (
        sheetContext,
      ) {
        final theme =
            Theme.of(
          sheetContext,
        );

        final colors =
            theme.colorScheme;

        return SafeArea(
          child:
              Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              28,
            ),
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Invitar jugador',
                  style: theme
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  'Elige cómo quieres crear el acceso para "${_team.name}".',
                  style: theme
                      .textTheme
                      .bodyMedium,
                ),

                const SizedBox(
                  height: 20,
                ),

                _InvitationOption(
                  icon:
                      CupertinoIcons.qrcode,
                  title:
                      'Generar código QR',
                  subtitle:
                      'Para un jugador que está contigo. También podrá escribir el código manualmente.',
                  color:
                      colors.primary,
                  onTap:
                      () {
                    Navigator.of(
                      sheetContext,
                    ).pop();

                    _createQrInvitation(
                      context,
                    );
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                _InvitationOption(
                  icon:
                      CupertinoIcons.envelope_fill,
                  title:
                      'Crear acceso para correo',
                  subtitle:
                      'El código quedará ligado a un correo específico y otra cuenta no podrá utilizarlo.',
                  color:
                      colors.secondary,
                  onTap:
                      () {
                    Navigator.of(
                      sheetContext,
                    ).pop();

                    _showEmailInvitationDialog(
                      context,
                    );
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                Container(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colors
                        .surfaceContainerHighest,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child:
                      Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons
                            .shield_fill,
                        color:
                            colors.primary,
                        size: 20,
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      const Expanded(
                        child:
                            Text(
                          'Cada invitación genera un código único. Cuando un jugador lo utiliza correctamente, ese código deja de estar disponible.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createQrInvitation(
    BuildContext context,
  ) async {
    final repository =
        TeamJoinCodeRepository();

    _showLoadingDialog(
      context,
      'Generando acceso...',
    );

    try {
      final access =
          await repository
              .createPlayerQrAccess(
        teamId:
            _team.id,
        leagueId:
            _team.leagueId,
        tournamentId:
            _team.tournamentId,
      );

      if (!context.mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      await _showGeneratedAccess(
        context,
        access:
            access,
        repository:
            repository,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      _showError(
        context,
        'No se pudo generar la invitación: $error',
      );
    }
  }

  Future<void>
      _showEmailInvitationDialog(
    BuildContext context,
  ) async {
    final controller =
        TextEditingController();

    final email =
        await showDialog<String>(
      context:
          context,
      builder:
          (
        dialogContext,
      ) {
        String?
            errorText;

        return StatefulBuilder(
          builder:
              (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              icon:
                  const Icon(
                CupertinoIcons
                    .envelope_fill,
              ),
              title:
                  const Text(
                'Invitar por correo',
              ),
              content:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Text(
                    'Escribe el correo de la cuenta CanchaYA que quieres invitar.',
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  TextField(
                    controller:
                        controller,
                    keyboardType:
                        TextInputType
                            .emailAddress,
                    autocorrect:
                        false,
                    enableSuggestions:
                        false,
                    decoration:
                        InputDecoration(
                      labelText:
                          'Correo electrónico',
                      hintText:
                          'jugador@correo.com',
                      prefixIcon:
                          const Icon(
                        CupertinoIcons.mail,
                      ),
                      errorText:
                          errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child:
                      const Text(
                    'Cancelar',
                  ),
                ),

                FilledButton(
                  onPressed:
                      () {
                    final value =
                        controller.text
                            .trim()
                            .toLowerCase();

                    if (value.isEmpty ||
                        !value.contains(
                          '@',
                        ) ||
                        !value.contains(
                          '.',
                        )) {
                      setDialogState(
                        () {
                          errorText =
                              'Escribe un correo válido.';
                        },
                      );

                      return;
                    }

                    Navigator.of(
                      dialogContext,
                    ).pop(
                      value,
                    );
                  },
                  child:
                      const Text(
                    'Crear acceso',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (email == null ||
        email.trim().isEmpty ||
        !context.mounted) {
      return;
    }

    await _createEmailInvitation(
      context,
      email,
    );
  }

  Future<void> _createEmailInvitation(
    BuildContext context,
    String email,
  ) async {
    final repository =
        TeamJoinCodeRepository();

    _showLoadingDialog(
      context,
      'Creando invitación...',
    );

    try {
      final access =
          await repository
              .createPlayerEmailAccess(
        teamId:
            _team.id,
        leagueId:
            _team.leagueId,
        tournamentId:
            _team.tournamentId,
        invitedEmail:
            email,
      );

      if (!context.mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      await _showGeneratedAccess(
        context,
        access:
            access,
        repository:
            repository,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      _showError(
        context,
        'No se pudo crear la invitación: $error',
      );
    }
  }

  // ==============================================================
  // DIÁLOGO DE CARGA
  // ==============================================================

  void _showLoadingDialog(
    BuildContext context,
    String message,
  ) {
    showDialog<void>(
      context:
          context,
      barrierDismissible:
          false,
      builder:
          (_) {
        return AlertDialog(
          content:
              Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child:
                    CircularProgressIndicator(
                  strokeWidth:
                      2.5,
                ),
              ),

              const SizedBox(
                width: 16,
              ),

              Expanded(
                child:
                    Text(
                  message,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==============================================================
  // ACCESO GENERADO
  // ==============================================================

  Future<void> _showGeneratedAccess(
    BuildContext context, {
    required TeamJoinCode access,
    required TeamJoinCodeRepository repository,
  }) async {
    await showDialog<void>(
      context:
          context,
      barrierDismissible:
          false,
      builder:
          (
        dialogContext,
      ) {
        final theme =
            Theme.of(
          dialogContext,
        );

        final colors =
            theme.colorScheme;

        bool revoking =
            false;

        return StatefulBuilder(
          builder:
              (
            context,
            setDialogState,
          ) {
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(
                horizontal:
                    20,
                vertical:
                    24,
              ),
              child:
                  ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth:
                      430,
                  maxHeight:
                      720,
                ),
                child:
                    ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    28,
                  ),
                  child:
                      Material(
                    color:
                        colors.surface,
                    child:
                        Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(
                            22,
                            22,
                            22,
                            14,
                          ),
                          child:
                              Row(
                            children: [
                              Container(
                                width:
                                    42,
                                height:
                                    42,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      colors.primaryContainer,
                                  borderRadius:
                                      BorderRadius.circular(
                                    13,
                                  ),
                                ),
                                child:
                                    Icon(
                                  access.isQrAccess
                                      ? CupertinoIcons.qrcode
                                      : CupertinoIcons.envelope_fill,
                                  color:
                                      colors.primary,
                                ),
                              ),

                              const SizedBox(
                                width:
                                    12,
                              ),

                              const Expanded(
                                child:
                                    Text(
                                  'Invitación creada',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        20,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Flexible(
                          child:
                              SingleChildScrollView(
                            physics:
                                const BouncingScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(
                              22,
                              2,
                              22,
                              16,
                            ),
                            child:
                                Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                if (access
                                    .isQrAccess) ...[
                                  Container(
                                    width:
                                        238,
                                    height:
                                        238,
                                    padding:
                                        const EdgeInsets.all(
                                      14,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(
                                        20,
                                      ),
                                    ),
                                    child:
                                        SizedBox(
                                      width:
                                          210,
                                      height:
                                          210,
                                      child:
                                          QrImageView(
                                        data:
                                            access.qrPayload,
                                        version:
                                            QrVersions.auto,
                                        size:
                                            210,
                                        padding:
                                            EdgeInsets.zero,
                                        backgroundColor:
                                            Colors.white,
                                        errorCorrectionLevel:
                                            QrErrorCorrectLevel.M,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        16,
                                  ),

                                  const Text(
                                    'El jugador puede escanear este QR o escribir el código manual.',
                                    textAlign:
                                        TextAlign.center,
                                  ),

                                  const SizedBox(
                                    height:
                                        18,
                                  ),
                                ] else ...[
                                  Text(
                                    'Acceso reservado para:',
                                    style:
                                        theme.textTheme.bodyMedium,
                                  ),

                                  const SizedBox(
                                    height:
                                        5,
                                  ),

                                  Text(
                                    access.invitedEmail ??
                                        '',
                                    textAlign:
                                        TextAlign.center,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        18,
                                  ),
                                ],

                                Text(
                                  'CÓDIGO DE ACCESO',
                                  style:
                                      theme.textTheme.labelMedium?.copyWith(
                                    color:
                                        colors.primary,
                                    fontWeight:
                                        FontWeight.w900,
                                    letterSpacing:
                                        1,
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      7,
                                ),

                                Container(
                                  width:
                                      double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal:
                                        14,
                                    vertical:
                                        13,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        colors.surfaceContainerHighest,
                                    borderRadius:
                                        BorderRadius.circular(
                                      15,
                                    ),
                                  ),
                                  child:
                                      SelectableText(
                                    access.code,
                                    textAlign:
                                        TextAlign.center,
                                    style:
                                        theme.textTheme.titleLarge?.copyWith(
                                      fontWeight:
                                          FontWeight.w900,
                                      letterSpacing:
                                          1.5,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      12,
                                ),

                                SizedBox(
                                  width:
                                      double.infinity,
                                  child:
                                      OutlinedButton.icon(
                                    onPressed:
                                        revoking
                                            ? null
                                            : () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text:
                                                        access.code,
                                                  ),
                                                );

                                                if (!dialogContext.mounted) {
                                                  return;
                                                }

                                                ScaffoldMessenger.of(
                                                  dialogContext,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content:
                                                        Text(
                                                      'Código copiado.',
                                                    ),
                                                  ),
                                                );
                                              },
                                    icon:
                                        const Icon(
                                      CupertinoIcons.doc_on_doc,
                                    ),
                                    label:
                                        const Text(
                                      'Copiar código',
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      10,
                                ),

                                Container(
                                  padding:
                                      const EdgeInsets.all(
                                    13,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        colors.surfaceContainerHighest,
                                    borderRadius:
                                        BorderRadius.circular(
                                      15,
                                    ),
                                  ),
                                  child:
                                      Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        CupertinoIcons.shield_fill,
                                        color:
                                            colors.primary,
                                        size:
                                            19,
                                      ),

                                      const SizedBox(
                                        width:
                                            9,
                                      ),

                                      Expanded(
                                        child:
                                            Text(
                                          access.isEmailAccess
                                              ? 'Solo la cuenta con el correo indicado podrá utilizar este acceso.'
                                              : 'Este acceso no está ligado a una cuenta específica. Entrégalo únicamente al jugador que quieras registrar.',
                                          style:
                                              theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Divider(
                          height:
                              1,
                        ),

                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            16,
                          ),
                          child:
                              Row(
                            mainAxisAlignment:
                                MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed:
                                    revoking
                                        ? null
                                        : () async {
                                            setDialogState(
                                              () {
                                                revoking =
                                                    true;
                                              },
                                            );

                                            try {
                                              await repository.revokeAccess(
                                                access.id,
                                              );

                                              if (!dialogContext.mounted) {
                                                return;
                                              }

                                              Navigator.of(
                                                dialogContext,
                                              ).pop();

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text(
                                                    'La invitación fue revocada.',
                                                  ),
                                                ),
                                              );
                                            } catch (error) {
                                              if (!dialogContext.mounted) {
                                                return;
                                              }

                                              setDialogState(
                                                () {
                                                  revoking =
                                                      false;
                                                },
                                              );

                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content:
                                                      Text(
                                                    'No se pudo revocar: $error',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                child:
                                    Text(
                                  revoking
                                      ? 'Revocando...'
                                      : 'Revocar',
                                ),
                              ),

                              const SizedBox(
                                width:
                                    8,
                              ),

                              FilledButton(
                                onPressed:
                                    revoking
                                        ? null
                                        : () {
                                            Navigator.of(
                                              dialogContext,
                                            ).pop();
                                          },
                                child:
                                    const Text(
                                  'Listo',
                                ),
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
          },
        );
      },
    );
  }

  void _showError(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),
      ),
    );
  }
}

// ================================================================
// CABECERA DEL EQUIPO
// ================================================================

class _TeamHeaderCard
    extends StatelessWidget {
  const _TeamHeaderCard({
    required this.team,
  });

  final Team team;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          colors: [
            theme
                .colorScheme
                .primary,
            theme
                .colorScheme
                .primary
                .withValues(
              alpha:
                  0.78,
            ),
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(
          22,
        ),
      ),
      child:
          Row(
        children: [
          Container(
            width:
                68,
            height:
                68,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha:
                    0.18,
              ),
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),
            child:
                team.hasLogo
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                        child:
                            Image.network(
                          team.logoUrl,
                          fit:
                              BoxFit.cover,
                          errorBuilder:
                              (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return const Icon(
                              CupertinoIcons.shield_fill,
                              color:
                                  Colors.white,
                              size:
                                  36,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.shield_fill,
                        color:
                            Colors.white,
                        size:
                            36,
                      ),
          ),

          const SizedBox(
            width:
                16,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  team.displayName,
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.w900,
                      ),
                ),

                if (team.hasShortName &&
                    team.name !=
                        team.displayName) ...[
                  const SizedBox(
                    height:
                        3,
                  ),

                  Text(
                    team.name,
                    maxLines:
                        1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Colors.white
                              .withValues(
                            alpha:
                                0.78,
                          ),
                        ),
                  ),
                ],

                const SizedBox(
                  height:
                      7,
                ),

                Text(
                  'Encargado activo',
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: Colors.white
                            .withValues(
                          alpha:
                              0.88,
                        ),
                      ),
                ),

                const SizedBox(
                  height:
                      8,
                ),

                Wrap(
                  spacing:
                      8,
                  runSpacing:
                      8,
                  children: [
                    _HeaderBadge(
                      icon:
                          CupertinoIcons.person_2_fill,
                      text:
                          '${team.totalPlayers} jugadores',
                    ),

                    _HeaderBadge(
                      icon:
                          CupertinoIcons.sportscourt_fill,
                      text:
                          team.status.label,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ESCUDO GRANDE
// ================================================================

class _LargeTeamLogo
    extends StatelessWidget {
  const _LargeTeamLogo({
    required this.team,
  });

  final Team team;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      width:
          118,
      height:
          118,
      padding:
          const EdgeInsets.all(
        8,
      ),
      decoration:
          BoxDecoration(
        color: colors
            .primaryContainer,
        borderRadius:
            BorderRadius.circular(
          30,
        ),
      ),
      child:
          team.hasLogo
              ? ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    24,
                  ),
                  child:
                      Image.network(
                    team.logoUrl,
                    fit:
                        BoxFit.cover,
                    errorBuilder:
                        (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return Icon(
                        CupertinoIcons.shield_fill,
                        size:
                            55,
                        color:
                            colors.primary,
                      );
                    },
                  ),
                )
              : Icon(
                  CupertinoIcons.shield_fill,
                  size:
                      55,
                  color:
                      colors.primary,
                ),
    );
  }
}

// ================================================================
// BADGE DEL HEADER
// ================================================================

class _HeaderBadge
    extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.text,
  });

  final IconData icon;

  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            10,
        vertical:
            6,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white
            .withValues(
          alpha:
              0.16,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color:
                Colors.white,
            size:
                16,
          ),

          const SizedBox(
            width:
                6,
          ),

          Text(
            text,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// TARJETA DE ACCIÓN
// ================================================================

class _ManagerActionCard
    extends StatelessWidget {
  const _ManagerActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageUrl = '',
  });

  final IconData icon;

  final String title;

  final String subtitle;

  final VoidCallback? onTap;

  final String imageUrl;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final hasImage =
        imageUrl.trim().isNotEmpty;

    return Card(
      elevation:
          0,
      clipBehavior:
          Clip.antiAlias,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        side:
            BorderSide(
          color: theme
              .colorScheme
              .outlineVariant,
        ),
      ),
      child:
          InkWell(
        onTap:
            onTap,
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            16,
          ),
          child:
              Row(
            children: [
              Container(
                width:
                    48,
                height:
                    48,
                decoration:
                    BoxDecoration(
                  color: theme
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                    hasImage
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            child:
                                Image.network(
                              imageUrl,
                              fit:
                                  BoxFit.cover,
                              errorBuilder:
                                  (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return Icon(
                                  icon,
                                  color: theme
                                      .colorScheme
                                      .onPrimaryContainer,
                                );
                              },
                            ),
                          )
                        : Icon(
                            icon,
                            color: theme
                                .colorScheme
                                .onPrimaryContainer,
                          ),
              ),

              const SizedBox(
                width:
                    14,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w900,
                          ),
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      subtitle,
                      maxLines:
                          2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: theme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width:
                    8,
              ),

              Icon(
                CupertinoIcons.chevron_right,
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// OPCIÓN DE INVITACIÓN
// ================================================================

class _InvitationOption
    extends StatelessWidget {
  const _InvitationOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;

  final String title;

  final String subtitle;

  final Color color;

  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      elevation:
          0,
      clipBehavior:
          Clip.antiAlias,
      child:
          InkWell(
        onTap:
            onTap,
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            16,
          ),
          child:
              Row(
            children: [
              Container(
                width:
                    50,
                height:
                    50,
                decoration:
                    BoxDecoration(
                  color: color
                      .withValues(
                    alpha:
                        0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child:
                    Icon(
                  icon,
                  color:
                      color,
                  size:
                      23,
                ),
              ),

              const SizedBox(
                width:
                    14,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodyMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width:
                    8,
              ),

              const Icon(
                CupertinoIcons.chevron_right,
                size:
                    18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SEGURIDAD
// ================================================================

class _SecurityInfoCard
    extends StatelessWidget {
  const _SecurityInfoCard({
    required this.team,
  });

  final Team team;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.shield_fill,
            color: theme
                .colorScheme
                .primary,
          ),

          const SizedBox(
            width:
                12,
          ),

          Expanded(
            child:
                Text(
              'Tus permisos de encargado corresponden únicamente a '
              '"${team.name}" dentro de esta liga y torneo. '
              'No modifican tu rol global de usuario.',
              style: theme
                  .textTheme
                  .bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}