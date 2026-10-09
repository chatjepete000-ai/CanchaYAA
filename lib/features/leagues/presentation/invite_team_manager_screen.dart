import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../teams/data/team_join_code_repository.dart';
import '../../teams/data/team_repository.dart';
import '../../teams/domain/team_join_code.dart';
import '../../teams/domain/team_models.dart';

enum _InvitationMethod {
  email,
  qr,
}

class InviteTeamManagerScreen extends StatefulWidget {
  const InviteTeamManagerScreen({
    super.key,
    required this.team,
  });

  final Team team;

  @override
  State<InviteTeamManagerScreen> createState() =>
      _InviteTeamManagerScreenState();
}

class _InviteTeamManagerScreenState
    extends State<InviteTeamManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  final TeamRepository _teamRepository =
      TeamRepository();

  final TeamJoinCodeRepository
      _joinCodeRepository =
      TeamJoinCodeRepository();

  _InvitationMethod _method =
      _InvitationMethod.email;

  bool _sending = false;
  bool _generatingQr = false;
  bool _revokingQr = false;

  TeamJoinCode? _generatedAccess;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    final valid =
        _formKey.currentState?.validate() ??
            false;

    if (!valid) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _teamRepository
          .sendManagerInvitation(
        teamId: widget.team.id,
        teamName: widget.team.name,
        leagueId: widget.team.leagueId,
        tournamentId:
            widget.team.tournamentId,
        invitedEmail:
            _emailController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Invitación enviada correctamente.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo enviar la invitación: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _generateQrInvitation() async {
    if (_generatingQr ||
        _revokingQr) {
      return;
    }

    setState(() {
      _generatingQr = true;
    });

    try {
      final previousAccess =
          _generatedAccess;

      // Si desde esta misma pantalla ya se había
      // generado otro acceso y todavía está activo,
      // lo revocamos antes de crear uno nuevo.
      //
      // Nunca se recicla el código anterior.
      if (previousAccess != null &&
          previousAccess.isActive) {
        await _joinCodeRepository
            .revokeAccess(
          previousAccess.id,
        );
      }

      final access =
          await _joinCodeRepository
              .createManagerQrAccess(
        teamId: widget.team.id,
        leagueId: widget.team.leagueId,
        tournamentId:
            widget.team.tournamentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _generatedAccess = access;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Nuevo acceso generado correctamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo generar el acceso: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingQr = false;
        });
      }
    }
  }

  Future<void> _revokeQrInvitation() async {
    final access =
        _generatedAccess;

    if (access == null ||
        !access.isActive ||
        _revokingQr) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text(
                    'Cancelar acceso',
                  ),
                  content: const Text(
                    'Este código dejará de funcionar y nunca podrá reutilizarse. ¿Deseas continuar?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                        ).pop(false);
                      },
                      child: const Text(
                        'No',
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                        ).pop(true);
                      },
                      child: const Text(
                        'Sí, cancelar',
                      ),
                    ),
                  ],
                );
              },
            ) ??
            false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _revokingQr = true;
    });

    try {
      await _joinCodeRepository
          .revokeAccess(
        access.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
  _generatedAccess = TeamJoinCode(
    id: access.id,
    teamId: access.teamId,
    leagueId: access.leagueId,
    tournamentId: access.tournamentId,
    code: access.code,
    status: TeamJoinCodeStatus.revoked,
    purpose: access.purpose,
    delivery: access.delivery,
    createdByUserId: access.createdByUserId,
    invitedUserId: access.invitedUserId,
    invitedEmail: access.invitedEmail,
    usedByUserId: access.usedByUserId,
    createdAt: access.createdAt,
    usedAt: access.usedAt,
    revokedAt: DateTime.now(),
    expiresAt: access.expiresAt,
  );
});

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'El acceso fue cancelado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cancelar el acceso: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _revokingQr = false;
        });
      }
    }
  }

  Future<void> _copyManualCode() async {
    final access =
        _generatedAccess;

    if (access == null) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: access.code,
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Código copiado.',
        ),
      ),
    );
  }

  String? _validateEmail(
    String? value,
  ) {
    final email =
        value?.trim().toLowerCase() ?? '';

    if (email.isEmpty) {
      return 'Escribe el correo del usuario.';
    }

    final emailExpression = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailExpression
        .hasMatch(email)) {
      return 'Escribe un correo electrónico válido.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Invitar encargado',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
                const EdgeInsets.all(24),
            children: [
              _buildTeamHeader(
                context,
                colors,
              ),

              const SizedBox(
                height: 26,
              ),

              Text(
                '¿Cómo quieres entregar la invitación?',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w900,
                    ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                'Puedes invitar al encargado mediante su correo registrado en CanchaYA o generar un QR con código manual.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),

              const SizedBox(
                height: 18,
              ),

              SegmentedButton<
                  _InvitationMethod>(
                segments: const [
                  ButtonSegment<
                      _InvitationMethod>(
                    value:
                        _InvitationMethod
                            .email,
                    icon: Icon(
                      Icons.email_outlined,
                    ),
                    label: Text(
                      'Correo',
                    ),
                  ),
                  ButtonSegment<
                      _InvitationMethod>(
                    value:
                        _InvitationMethod.qr,
                    icon: Icon(
                      Icons.qr_code_2,
                    ),
                    label: Text(
                      'QR / código',
                    ),
                  ),
                ],
                selected: {
                  _method,
                },
                onSelectionChanged:
                    (selection) {
                  if (selection.isEmpty) {
                    return;
                  }

                  setState(() {
                    _method =
                        selection.first;
                  });
                },
              ),

              const SizedBox(
                height: 26,
              ),

              if (_method ==
                  _InvitationMethod.email)
                _buildEmailSection(
                  context,
                  colors,
                )
              else
                _buildQrSection(
                  context,
                  colors,
                ),

              const SizedBox(
                height: 26,
              ),

              _buildWhatHappensCard(
                context,
                colors,
              ),

              const SizedBox(
                height: 24,
              ),

              _buildPermissionsCard(
                context,
                colors,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamHeader(
    BuildContext context,
    ColorScheme colors,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.primary.withValues(
              alpha: 0.78,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      colors.onPrimary
                          .withValues(
                    alpha: 0.15,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(16),
                ),
                child: Icon(
                  Icons
                      .manage_accounts_outlined,
                  color:
                      colors.onPrimary,
                  size: 30,
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
                      widget.team.name,
                      style:
                          Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: colors
                                    .onPrimary,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Asignar encargado temporal',
                      style: TextStyle(
                        color: colors
                            .onPrimary
                            .withValues(
                          alpha: 0.88,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          Text(
            'La persona recibirá una invitación para administrar este equipo durante el torneo.',
            style: TextStyle(
              color: colors.onPrimary
                  .withValues(
                alpha: 0.92,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSection(
    BuildContext context,
    ColorScheme colors,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Correo del usuario',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w900,
              ),
        ),

        const SizedBox(
          height: 8,
        ),

        Text(
          'Escribe el mismo correo con el que la persona está registrada en CanchaYA.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium,
        ),

        const SizedBox(
          height: 18,
        ),

        TextFormField(
          controller:
              _emailController,
          keyboardType:
              TextInputType
                  .emailAddress,
          textInputAction:
              TextInputAction.done,
          autocorrect: false,
          autofillHints: const [
            AutofillHints.email,
          ],
          decoration:
              const InputDecoration(
            labelText:
                'Correo electrónico',
            hintText:
                'usuario@correo.com',
            prefixIcon: Icon(
              Icons.email_outlined,
            ),
          ),
          validator:
              _validateEmail,
          onFieldSubmitted: (_) {
            if (!_sending) {
              _sendInvitation();
            }
          },
        ),

        const SizedBox(
          height: 24,
        ),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _sending
                ? null
                : _sendInvitation,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons
                        .send_outlined,
                  ),
            label: Text(
              _sending
                  ? 'Enviando...'
                  : 'Enviar invitación',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrSection(
    BuildContext context,
    ColorScheme colors,
  ) {
    final access =
        _generatedAccess;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'QR y código manual',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w900,
              ),
        ),

        const SizedBox(
          height: 8,
        ),

        Text(
          'Úsalo cuando la persona esté contigo. El QR y el código escrito representan exactamente la misma invitación.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium,
        ),

        const SizedBox(
          height: 18,
        ),

        if (access == null)
          SizedBox(
            width: double.infinity,
            child:
                FilledButton.icon(
              onPressed:
                  _generatingQr
                      ? null
                      : _generateQrInvitation,
              icon: _generatingQr
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.qr_code_2,
                    ),
              label: Text(
                _generatingQr
                    ? 'Generando...'
                    : 'Generar QR / código',
              ),
            ),
          )
        else
          _buildGeneratedAccessCard(
            context,
            colors,
            access,
          ),
      ],
    );
  }

  Widget _buildGeneratedAccessCard(
    BuildContext context,
    ColorScheme colors,
    TeamJoinCode access,
  ) {
    final active =
        access.isActive;

    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  active
                      ? Icons
                          .verified_outlined
                      : Icons
                          .block_outlined,
                  color: active
                      ? colors.primary
                      : colors.error,
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Text(
                    active
                        ? 'Acceso activo'
                        : 'Acceso cancelado',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            if (active) ...[
              Container(
                padding:
                    const EdgeInsets
                        .all(12),
                color: Colors.white,
                child: QrImageView(
                  data:
                      access.qrPayload,
                  version:
                      QrVersions.auto,
                  size: 220,
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              const Text(
                'Código manual',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              SelectableText(
                access.code,
                textAlign:
                    TextAlign.center,
                style:
                    Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight:
                              FontWeight
                                  .w900,
                          letterSpacing:
                              2,
                        ),
              ),

              const SizedBox(
                height: 14,
              ),

              OutlinedButton.icon(
                onPressed:
                    _copyManualCode,
                icon: const Icon(
                  Icons.copy_outlined,
                ),
                label: const Text(
                  'Copiar código',
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets
                        .all(14),
                decoration:
                    BoxDecoration(
                  color: colors
                      .surfaceContainerHighest,
                  borderRadius:
                      BorderRadius
                          .circular(14),
                ),
                child:
                    const Text(
                  'Si la cámara o el lector QR no están disponibles, la persona podrá escribir manualmente este mismo código.',
                  textAlign:
                      TextAlign.center,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          _revokingQr
                              ? null
                              : _revokeQrInvitation,
                      icon: _revokingQr
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .cancel_outlined,
                            ),
                      label: const Text(
                        'Cancelar acceso',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              SizedBox(
                width: double.infinity,
                child:
                    FilledButton.tonalIcon(
                  onPressed:
                      _generatingQr ||
                              _revokingQr
                          ? null
                          : _generateQrInvitation,
                  icon: const Icon(
                    Icons.refresh,
                  ),
                  label: const Text(
                    'Generar otro acceso',
                  ),
                ),
              ),
            ] else ...[
              Icon(
                Icons
                    .qr_code_2_outlined,
                size: 64,
                color:
                    colors.outline,
              ),

              const SizedBox(
                height: 14,
              ),

              Text(
                access.code,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              const Text(
                'Este código ya no puede utilizarse y nunca será reciclado.',
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height: 18,
              ),

              SizedBox(
                width: double.infinity,
                child:
                    FilledButton.icon(
                  onPressed:
                      _generatingQr
                          ? null
                          : _generateQrInvitation,
                  icon: const Icon(
                    Icons
                        .add_circle_outline,
                  ),
                  label: const Text(
                    'Generar nuevo acceso',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWhatHappensCard(
    BuildContext context,
    ColorScheme colors,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            colors.surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_outlined,
              ),
              SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  '¿Qué pasará después?',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(
            height: 12,
          ),

          Text(
            '1. El usuario recibirá o abrirá la invitación de CanchaYA.',
          ),

          SizedBox(
            height: 7,
          ),

          Text(
            '2. Podrá aceptarla o rechazarla.',
          ),

          SizedBox(
            height: 7,
          ),

          Text(
            '3. Si acepta, obtendrá permisos temporales sobre este equipo.',
          ),

          SizedBox(
            height: 7,
          ),

          Text(
            '4. Podrá administrar plantilla, jugadores, escudo, uniforme y otras funciones del equipo.',
          ),

          SizedBox(
            height: 7,
          ),

          Text(
            '5. Cuando termine el torneo o se revoque su cargo, perderá esos permisos pero se conservará su historial.',
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(
    BuildContext context,
    ColorScheme colors,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              colors.outlineVariant,
        ),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
          ),
          SizedBox(
            width: 12,
          ),
          Expanded(
            child: Text(
              'Ser encargado de equipo no convierte al usuario en administrador de liga ni en administrador de plataforma. Sus permisos quedan limitados al equipo y al torneo correspondientes.',
            ),
          ),
        ],
      ),
    );
  }
}