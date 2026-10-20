import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/team_join_code_repository.dart';
import '../domain/team_join_code.dart';
import '../domain/team_models.dart';
import 'team_roster_screen.dart';

class TeamManagerScreen extends StatelessWidget {
  const TeamManagerScreen({
    super.key,
    required this.team,
  });

  final Team team;

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
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),
          children: [
            _TeamHeaderCard(
              team: team,
            ),

            const SizedBox(height: 20),

            Text(
              'Gestión del equipo',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),

            const SizedBox(height: 6),

            Text(
              'Administra la plantilla y los accesos de tus jugadores.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium,
            ),

            const SizedBox(height: 14),

            _ManagerActionCard(
              icon: CupertinoIcons.person_2_fill,
              title: 'Plantilla',
              subtitle:
                  'Consulta los jugadores registrados en este equipo.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TeamRosterScreen(
                      team: team,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _ManagerActionCard(
              icon: CupertinoIcons.person_add_solid,
              title: 'Invitar jugadores',
              subtitle:
                  'Genera un QR, código manual o acceso para un correo.',
              onTap: () {
                _showInvitationOptions(
                  context,
                );
              },
            ),

            const SizedBox(height: 12),

            _ManagerActionCard(
              icon: CupertinoIcons.photo_fill,
              title: 'Escudo del equipo',
              subtitle:
                  'Configura o actualiza la imagen del equipo.',
              onTap: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La carga de escudo se implementará después.',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _ManagerActionCard(
              icon: CupertinoIcons.sportscourt_fill,
              title: 'Uniforme',
              subtitle:
                  'Registra la descripción del uniforme del equipo.',
              onTap: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La edición del uniforme se implementará después.',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            _SecurityInfoCard(
              team: team,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInvitationOptions(
    BuildContext context,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              28,
            ),
            child: Column(
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

                const SizedBox(height: 6),

                Text(
                  'Elige cómo quieres crear el acceso para "${team.name}".',
                  style:
                      theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 20),

                _InvitationOption(
                  icon:
                      CupertinoIcons.qrcode,
                  title:
                      'Generar código QR',
                  subtitle:
                      'Para un jugador que está contigo. También podrá escribir el código manualmente.',
                  color: colors.primary,
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop();

                    _createQrInvitation(
                      context,
                    );
                  },
                ),

                const SizedBox(height: 12),

                _InvitationOption(
                  icon:
                      CupertinoIcons.envelope_fill,
                  title:
                      'Crear acceso para correo',
                  subtitle:
                      'El código quedará ligado a un correo específico y otra cuenta no podrá utilizarlo.',
                  color:
                      colors.secondary,
                  onTap: () {
                    Navigator.of(
                      sheetContext,
                    ).pop();

                    _showEmailInvitationDialog(
                      context,
                    );
                  },
                ),

                const SizedBox(height: 16),

                Container(
                  padding:
                      const EdgeInsets.all(14),
                  decoration:
                      BoxDecoration(
                    color: colors
                        .surfaceContainerHighest,
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
                        child: Text(
                          'Cada invitación genera un código único. '
                          'Cuando un jugador lo utiliza correctamente, '
                          'ese código deja de estar disponible.',
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
        teamId: team.id,
        leagueId: team.leagueId,
        tournamentId:
            team.tournamentId,
      );

      if (!context.mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();

      await _showGeneratedAccess(
        context,
        access: access,
        repository: repository,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();

      _showError(
        context,
        'No se pudo generar la invitación: $error',
      );
    }
  }

  Future<void> _showEmailInvitationDialog(
    BuildContext context,
  ) async {
    final controller =
        TextEditingController();

    final email =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              icon: const Icon(
                CupertinoIcons
                    .envelope_fill,
              ),
              title: const Text(
                'Invitar por correo',
              ),
              content: Column(
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
                    autocorrect: false,
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
                        CupertinoIcons
                            .mail,
                      ),
                      errorText:
                          errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child: const Text(
                    'Cancelar',
                  ),
                ),
                FilledButton(
                  onPressed: () {
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
                  child: const Text(
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
        teamId: team.id,
        leagueId: team.leagueId,
        tournamentId:
            team.tournamentId,
        invitedEmail: email,
      );

      if (!context.mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();

      await _showGeneratedAccess(
        context,
        access: access,
        repository: repository,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();

      _showError(
        context,
        'No se pudo crear la invitación: $error',
      );
    }
  }

  void _showLoadingDialog(
    BuildContext context,
    String message,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
              ),

              const SizedBox(
                width: 16,
              ),

              Expanded(
                child: Text(
                  message,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showGeneratedAccess(
    BuildContext context, {
    required TeamJoinCode access,
    required TeamJoinCodeRepository repository,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme =
            Theme.of(dialogContext);

        final colors =
            theme.colorScheme;

        bool revoking = false;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              titlePadding:
                  const EdgeInsets.fromLTRB(
                22,
                22,
                22,
                0,
              ),
              contentPadding:
                  const EdgeInsets.fromLTRB(
                22,
                16,
                22,
                8,
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(
                16,
                4,
                16,
                16,
              ),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(
                      color: colors
                          .primaryContainer,
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                    child: Icon(
                      access.isQrAccess
                          ? CupertinoIcons
                              .qrcode
                          : CupertinoIcons
                              .envelope_fill,
                      color:
                          colors.primary,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  const Expanded(
                    child: Text(
                      'Invitación creada',
                    ),
                  ),
                ],
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    if (access.isQrAccess) ...[
                      Container(
                        padding:
                            const EdgeInsets
                                .all(
                          14,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),
                        child: QrImageView(
                          data:
                              access.qrPayload,
                          version:
                              QrVersions
                                  .auto,
                          size: 210,
                          backgroundColor:
                              Colors.white,
                          errorCorrectionLevel:
                              QrErrorCorrectLevel
                                  .M,
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      const Text(
                        'El jugador puede escanear este QR o escribir el código manual.',
                        textAlign:
                            TextAlign.center,
                      ),

                      const SizedBox(
                        height: 18,
                      ),
                    ] else ...[
                      Text(
                        'Acceso reservado para:',
                        style: theme
                            .textTheme
                            .bodyMedium,
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        access.invitedEmail ??
                            '',
                        textAlign:
                            TextAlign.center,
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),
                    ],

                    Text(
                      'CÓDIGO DE ACCESO',
                      style: theme
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color:
                                colors.primary,
                            fontWeight:
                                FontWeight
                                    .w900,
                            letterSpacing:
                                1,
                          ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration:
                          BoxDecoration(
                        color: colors
                            .surfaceContainerHighest,
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                      ),
                      child: SelectableText(
                        access.code,
                        textAlign:
                            TextAlign.center,
                        style: theme
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w900,
                              letterSpacing:
                                  1.5,
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
                            revoking
                                ? null
                                : () async {
                                    await Clipboard
                                        .setData(
                                      ClipboardData(
                                        text:
                                            access.code,
                                      ),
                                    );

                                    if (!dialogContext
                                        .mounted) {
                                      return;
                                    }

                                    ScaffoldMessenger
                                            .of(
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
                        icon: const Icon(
                          CupertinoIcons
                              .doc_on_doc,
                        ),
                        label:
                            const Text(
                          'Copiar código',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Container(
                      padding:
                          const EdgeInsets
                              .all(
                        13,
                      ),
                      decoration:
                          BoxDecoration(
                        color: colors
                            .surfaceContainerHighest,
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
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
                          Expanded(
                            child: Text(
                              access.isEmailAccess
                                  ? 'Solo la cuenta con el correo indicado podrá utilizar este acceso.'
                                  : 'Este acceso no está ligado a una cuenta específica. Entrégalo únicamente al jugador que quieras registrar.',
                              style: theme
                                  .textTheme
                                  .bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: revoking
                      ? null
                      : () async {
                          setDialogState(
                            () {
                              revoking =
                                  true;
                            },
                          );

                          try {
                            await repository
                                .revokeAccess(
                              access.id,
                            );

                            if (!dialogContext
                                .mounted) {
                              return;
                            }

                            Navigator.of(
                              dialogContext,
                            ).pop();

                            ScaffoldMessenger
                                    .of(
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
                            if (!dialogContext
                                .mounted) {
                              return;
                            }

                            setDialogState(
                              () {
                                revoking =
                                    false;
                              },
                            );

                            ScaffoldMessenger
                                    .of(
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
                  child: Text(
                    revoking
                        ? 'Revocando...'
                        : 'Revocar',
                  ),
                ),

                FilledButton(
                  onPressed: revoking
                      ? null
                      : () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  child: const Text(
                    'Listo',
                  ),
                ),
              ],
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
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }
}

class _TeamHeaderCard extends StatelessWidget {
  const _TeamHeaderCard({
    required this.team,
  });

  final Team team;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary
                .withValues(
              alpha: 0.78,
            ),
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: 0.18,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                18,
              ),
            ),
            child:
                team.logoUrl
                        .trim()
                        .isEmpty
                    ? const Icon(
                        CupertinoIcons
                            .shield_fill,
                        color:
                            Colors.white,
                        size: 34,
                      )
                    : ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          18,
                        ),
                        child:
                            Image.network(
                          team.logoUrl,
                          fit:
                              BoxFit.cover,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return const Icon(
                              CupertinoIcons
                                  .shield_fill,
                              color:
                                  Colors.white,
                              size: 34,
                            );
                          },
                        ),
                      ),
          ),

          const SizedBox(
            width: 16,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  team.name,
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  'Encargado activo',
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: Colors
                            .white
                            .withValues(
                          alpha:
                              0.88,
                        ),
                      ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeaderBadge(
                      icon:
                          CupertinoIcons
                              .person_2_fill,
                      text:
                          '${team.totalPlayers} jugadores',
                    ),
                    _HeaderBadge(
                      icon:
                          CupertinoIcons
                              .sportscourt_fill,
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

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(
          alpha: 0.16,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(
            width: 6,
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

class _ManagerActionCard
    extends StatelessWidget {
  const _ManagerActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior:
          Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme
              .outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: theme
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color: theme
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      subtitle,
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
                width: 8,
              ),

              Icon(
                CupertinoIcons
                    .chevron_right,
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
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                    BoxDecoration(
                  color:
                      color.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    15,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 23,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              const Icon(
                CupertinoIcons
                    .chevron_right,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityInfoCard
    extends StatelessWidget {
  const _SecurityInfoCard({
    required this.team,
  });

  final Team team;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons
                .shield_fill,
            color: theme
                .colorScheme
                .primary,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Text(
              'Tus permisos de encargado corresponden únicamente a '
              '"${team.name}" dentro de esta liga y torneo. '
              'No modifican tu rol global de usuario.',
              style:
                  theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}