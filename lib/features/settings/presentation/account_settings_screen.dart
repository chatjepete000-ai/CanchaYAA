import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/theme_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../data/account_security_repository.dart';

const Color _settingsGreen = Color(0xFF0E9F57);
const double _settingsMaxWidth = 720;

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    required this.themeController,
  });

  final ThemeController themeController;

  @override
  State<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState
    extends State<AccountSettingsScreen> {
  final AccountSecurityRepository _securityRepository =
      AccountSecurityRepository();

  final ProfileRepository _profileRepository =
      ProfileRepository();

  late final Future<void> _ensureProfileFuture;

  bool _processingSensitiveAction = false;
  bool _refreshingAccount = false;

  @override
  void initState() {
    super.initState();

    _ensureProfileFuture =
        _profileRepository.ensureCurrentProfile();
  }

  Future<void> _changeEmail() async {
    if (_processingSensitiveAction) {
      return;
    }

    final result = await showDialog<_EmailChangeInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const _ChangeEmailDialog();
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _processingSensitiveAction = true;
    });

    try {
      await _securityRepository.requestEmailChange(
        currentPassword: result.currentPassword,
        newEmail: result.newEmail,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              CupertinoIcons.envelope_badge,
              color: _settingsGreen,
              size: 34,
            ),
            title: const Text(
              'Revisa tu nuevo correo',
              textAlign: TextAlign.center,
            ),
            content: Text(
              'Enviamos una verificación a:\n\n'
              '${result.newEmail}\n\n'
              'Tu correo no cambiará hasta que abras el enlace de verificación.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  'Entendido',
                ),
              ),
            ],
          );
        },
      );
    } on AccountSecurityException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError(
        'No se pudo solicitar el cambio de correo.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingSensitiveAction = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    if (_processingSensitiveAction) {
      return;
    }

    final result =
        await showDialog<_PasswordChangeInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const _ChangePasswordDialog();
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _processingSensitiveAction = true;
    });

    try {
      await _securityRepository.changePassword(
        currentPassword: result.currentPassword,
        newPassword: result.newPassword,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contraseña actualizada correctamente.',
          ),
        ),
      );
    } on AccountSecurityException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError(
        'No se pudo cambiar la contraseña.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingSensitiveAction = false;
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_processingSensitiveAction) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            CupertinoIcons.lock_rotation,
            color: _settingsGreen,
            size: 34,
          ),
          title: const Text(
            'Recuperar contraseña',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Firebase enviará un enlace de recuperación al correo asociado actualmente a tu cuenta.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Enviar enlace',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processingSensitiveAction = true;
    });

    try {
      await _securityRepository
          .sendPasswordResetToCurrentEmail();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enlace de recuperación enviado.',
          ),
        ),
      );
    } on AccountSecurityException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        error.message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingSensitiveAction = false;
        });
      }
    }
  }

  Future<void> _changePhone(
    UserProfile profile,
  ) async {
    final newPhone = await showDialog<String>(
      context: context,
      builder: (_) {
        return _ChangePhoneDialog(
          currentPhone: profile.phone,
        );
      },
    );

    if (newPhone == null || !mounted) {
      return;
    }

    try {
      await _profileRepository.updateCurrentProfile(
        displayName: profile.displayName,
        phone: newPhone,
        position: profile.position,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newPhone.trim().isEmpty
                ? 'Número de teléfono eliminado.'
                : 'Número de teléfono actualizado.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError(
        'No se pudo actualizar el número de teléfono.',
      );
    }
  }

  Future<void> _refreshAccount() async {
    if (_refreshingAccount) {
      return;
    }

    setState(() {
      _refreshingAccount = true;
    });

    try {
      await _securityRepository.reloadCurrentUser();

      if (!mounted) {
        return;
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Información de cuenta actualizada.',
          ),
        ),
      );
    } on AccountSecurityException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        error.message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshingAccount = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            CupertinoIcons.square_arrow_right,
            color:
                Theme.of(dialogContext).colorScheme.error,
            size: 32,
          ),
          title: const Text(
            'Cerrar sesión',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            '¿Quieres cerrar tu sesión de CanchaYA en este dispositivo?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Cerrar sesión',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } on FirebaseAuthException {
      if (!mounted) {
        return;
      }

      _showError(
        'No se pudo cerrar la sesión.',
      );
    }
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }

  String _maskEmail(
    String email,
  ) {
    final clean =
        email.trim().toLowerCase();

    if (clean.isEmpty ||
        !clean.contains('@')) {
      return 'No disponible';
    }

    final atIndex =
        clean.lastIndexOf('@');

    if (atIndex <= 0) {
      return 'Correo protegido';
    }

    final local =
        clean.substring(0, atIndex);

    final domain =
        clean.substring(atIndex);

    final visibleCount =
        local.length >= 2 ? 2 : 1;

    final visible =
        local.substring(
      local.length - visibleCount,
    );

    final hiddenCount =
        local.length - visibleCount;

    final hidden =
        List<String>.filled(
      hiddenCount > 0 ? hiddenCount : 2,
      '•',
    ).join();

    return '$hidden$visible$domain';
  }

  String _maskPhone(
    String phone,
  ) {
    final clean =
        phone.trim();

    if (clean.isEmpty) {
      return 'No registrado';
    }

    final digits = clean.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (digits.isEmpty) {
      return 'Número protegido';
    }

    if (digits.length <= 4) {
      return '••••$digits';
    }

    final lastFour =
        digits.substring(
      digits.length - 4,
    );

    final hidden =
        List<String>.filled(
      digits.length - 4,
      '•',
    ).join();

    return '$hidden$lastFour';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configuración',
        ),
        actions: [
          IconButton(
            tooltip:
                'Actualizar información',
            onPressed: _refreshingAccount
                ? null
                : _refreshAccount,
            icon: _refreshingAccount
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    CupertinoIcons.refresh,
                  ),
          ),
          const SizedBox(
            width: 6,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _ensureProfileFuture,
        builder: (
          context,
          ensureSnapshot,
        ) {
          if (ensureSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (ensureSnapshot.hasError) {
            return const _SettingsError(
              message:
                  'No se pudo cargar la configuración de la cuenta.',
            );
          }

          return StreamBuilder<UserProfile?>(
            stream:
                _profileRepository.watchCurrentProfile(),
            builder: (
              context,
              snapshot,
            ) {
              if (snapshot.connectionState ==
                      ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return const _SettingsError(
                  message:
                      'No se pudo cargar la información de tu cuenta.',
                );
              }

              final profile =
                  snapshot.data;

              if (profile == null) {
                return const _SettingsError(
                  message:
                      'No encontramos la información de tu cuenta.',
                );
              }

              return _buildSettings(
                context,
                profile,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSettings(
    BuildContext context,
    UserProfile profile,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final authUser =
        FirebaseAuth.instance.currentUser;

    final email =
        authUser?.email?.trim() ?? '';

    final emailVerified =
        authUser?.emailVerified ?? false;

    final usesPassword =
        _securityRepository
            .usesPasswordProvider;

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final contentWidth =
            constraints.maxWidth >
                    _settingsMaxWidth
                ? _settingsMaxWidth
                : constraints.maxWidth;

        final horizontalPadding =
            constraints.maxWidth < 380
                ? 12.0
                : constraints.maxWidth < 600
                    ? 16.0
                    : 22.0;

        return Center(
          child: SizedBox(
            width: contentWidth,
            child: ListView(
              physics:
                  const BouncingScrollPhysics(),
              padding:
                  EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                36,
              ),
              children: [
                _SecurityHeader(
                  emailVerified:
                      emailVerified,
                ),

                const SizedBox(
                  height: 28,
                ),

                const _SettingsSectionTitle(
                  title: 'CUENTA',
                ),

                const SizedBox(
                  height: 12,
                ),

                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon:
                          CupertinoIcons.mail,
                      title:
                          'Correo electrónico',
                      value:
                          _maskEmail(email),
                      badge: emailVerified
                          ? 'Verificado'
                          : 'Sin verificar',
                      onTap: usesPassword
                          ? _changeEmail
                          : null,
                    ),

                    _SettingsDivider(
                      colors: colors,
                    ),

                    _SettingsRow(
                      icon:
                          CupertinoIcons.phone,
                      title:
                          'Teléfono',
                      value: _maskPhone(
                        profile.phone,
                      ),
                      onTap: () {
                        _changePhone(
                          profile,
                        );
                      },
                    ),
                  ],
                ),

                if (!usesPassword) ...[
                  const SizedBox(
                    height: 10,
                  ),
                  _InformationNotice(
                    icon: CupertinoIcons
                        .info_circle_fill,
                    message:
                        'Esta cuenta utiliza un proveedor externo para iniciar sesión. Algunos cambios de seguridad deben realizarse con ese proveedor.',
                  ),
                ],

                const SizedBox(
                  height: 28,
                ),

                const _SettingsSectionTitle(
                  title: 'SEGURIDAD',
                ),

                const SizedBox(
                  height: 12,
                ),

                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon:
                          CupertinoIcons.lock,
                      title:
                          'Contraseña',
                      value:
                          '••••••••••',
                      subtitle: usesPassword
                          ? 'Cambiar contraseña'
                          : 'Administrada por tu proveedor',
                      onTap: usesPassword
                          ? _changePassword
                          : null,
                    ),

                    if (usesPassword) ...[
                      _SettingsDivider(
                        colors: colors,
                      ),
                      _SettingsRow(
                        icon: CupertinoIcons
                            .lock_rotation,
                        title:
                            'Recuperar contraseña',
                        value:
                            'Enviar enlace',
                        subtitle:
                            'Al correo actual',
                        onTap:
                            _sendPasswordReset,
                      ),
                    ],
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                const _InformationNotice(
                  icon:
                      CupertinoIcons.shield_fill,
                  message:
                      'CanchaYA nunca guarda tu contraseña en Firestore. Las operaciones sensibles son verificadas directamente por Firebase Authentication.',
                ),

                const SizedBox(
                  height: 28,
                ),

                const _SettingsSectionTitle(
                  title: 'APARIENCIA',
                ),

                const SizedBox(
                  height: 12,
                ),

                AnimatedBuilder(
                  animation:
                      widget.themeController,
                  builder: (
                    context,
                    _,
                  ) {
                    return _AppearanceCard(
                      isDark: widget
                          .themeController
                          .isDarkMode,
                      onLight: () {
                        widget
                            .themeController
                            .setLightMode();
                      },
                      onDark: () {
                        widget
                            .themeController
                            .setDarkMode();
                      },
                    );
                  },
                ),

                const SizedBox(
                  height: 28,
                ),

                const _SettingsSectionTitle(
                  title: 'SESIÓN',
                ),

                const SizedBox(
                  height: 12,
                ),

                OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(
                      52,
                    ),
                    foregroundColor:
                        colors.error,
                    side: BorderSide(
                      color: colors.error
                          .withValues(
                        alpha: 0.42,
                      ),
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  onPressed: _signOut,
                  icon: const Icon(
                    CupertinoIcons
                        .square_arrow_right,
                    size: 19,
                  ),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SecurityHeader
    extends StatelessWidget {
  const _SecurityHeader({
    required this.emailVerified,
  });

  final bool emailVerified;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color:
              colors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color: _settingsGreen
                  .withValues(
                alpha: 0.11,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: const Icon(
              CupertinoIcons
                  .shield_lefthalf_fill,
              color:
                  _settingsGreen,
              size: 24,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta y seguridad',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  'Administra tus datos privados y credenciales de acceso.',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Row(
                  children: [
                    Icon(
                      emailVerified
                          ? CupertinoIcons
                              .check_mark_circled_solid
                          : CupertinoIcons
                              .exclamationmark_circle,
                      color: emailVerified
                          ? _settingsGreen
                          : colors
                              .onSurfaceVariant,
                      size: 16,
                    ),

                    const SizedBox(
                      width: 6,
                    ),

                    Flexible(
                      child: Text(
                        emailVerified
                            ? 'Correo verificado'
                            : 'Correo pendiente de verificación',
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .w700,
                              color: emailVerified
                                  ? _settingsGreen
                                  : colors
                                      .onSurfaceVariant,
                            ),
                      ),
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

class _SettingsSectionTitle
    extends StatelessWidget {
  const _SettingsSectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration:
              BoxDecoration(
            color:
                _settingsGreen,
            borderRadius:
                BorderRadius.circular(
              2,
            ),
          ),
        ),

        const SizedBox(
          width: 9,
        ),

        Expanded(
          child: Text(
            title,
            style:
                TextStyle(
              color: colors
                  .onSurfaceVariant,
              fontSize: 11.5,
              fontWeight:
                  FontWeight.w900,
              letterSpacing:
                  1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsCard
    extends StatelessWidget {
  const _SettingsCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      decoration:
          BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
              colors.outlineVariant,
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsDivider
    extends StatelessWidget {
  const _SettingsDivider({
    required this.colors,
  });

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 62,
      color:
          colors.outlineVariant,
    );
  }
}

class _SettingsRow
    extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;

  final String? subtitle;
  final String? badge;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color: _settingsGreen
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color:
                      _settingsGreen,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                          ),
                        ),

                        if (badge !=
                            null)
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  7,
                              vertical:
                                  3,
                            ),
                            decoration:
                                BoxDecoration(
                              color: _settingsGreen
                                  .withValues(
                                alpha:
                                    0.09,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                100,
                              ),
                            ),
                            child:
                                Text(
                              badge!,
                              style:
                                  const TextStyle(
                                color:
                                    _settingsGreen,
                                fontSize:
                                    9.5,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      value,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: colors
                                .onSurfaceVariant,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                    ),

                    if (subtitle !=
                        null) ...[
                      const SizedBox(
                        height: 2,
                      ),
                      Text(
                        subtitle!,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: colors
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),

              if (onTap != null) ...[
                const SizedBox(
                  width: 8,
                ),
                Icon(
                  CupertinoIcons
                      .chevron_right,
                  size: 17,
                  color: colors
                      .onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InformationNotice
    extends StatelessWidget {
  const _InformationNotice({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        13,
      ),
      decoration:
          BoxDecoration(
        color: _settingsGreen
            .withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color:
                _settingsGreen,
            size: 18,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              message,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard
    extends StatelessWidget {
  const _AppearanceCard({
    required this.isDark,
    required this.onLight,
    required this.onDark,
  });

  final bool isDark;

  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(
        8,
      ),
      decoration:
          BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
              colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                _AppearanceOption(
              icon:
                  CupertinoIcons.sun_max,
              label: 'Claro',
              selected: !isDark,
              onTap: onLight,
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child:
                _AppearanceOption(
              icon:
                  CupertinoIcons.moon,
              label: 'Oscuro',
              selected: isDark,
              onTap: onDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceOption
    extends StatelessWidget {
  const _AppearanceOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color:
          Colors.transparent,
      borderRadius:
          BorderRadius.circular(
        14,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          decoration:
              BoxDecoration(
            color: selected
                ? _settingsGreen
                    .withValues(
                    alpha: 0.09,
                  )
                : Colors
                    .transparent,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color: selected
                  ? _settingsGreen
                      .withValues(
                      alpha: 0.45,
                    )
                  : Colors
                      .transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? _settingsGreen
                    : colors
                        .onSurfaceVariant,
              ),

              const SizedBox(
                width: 8,
              ),

              Flexible(
                child: Text(
                  label,
                  style:
                      TextStyle(
                    color: selected
                        ? _settingsGreen
                        : colors
                            .onSurface,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
              ),

              if (selected) ...[
                const SizedBox(
                  width: 7,
                ),
                const Icon(
                  CupertinoIcons
                      .check_mark_circled_solid,
                  color:
                      _settingsGreen,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeEmailDialog
    extends StatefulWidget {
  const _ChangeEmailDialog();

  @override
  State<_ChangeEmailDialog>
      createState() =>
          _ChangeEmailDialogState();
}

class _ChangeEmailDialogState
    extends State<_ChangeEmailDialog> {
  final _formKey =
      GlobalKey<FormState>();

  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();

    _passwordController.clear();
    _passwordController.dispose();

    super.dispose();
  }

  void _submit() {
    final valid =
        _formKey.currentState
                ?.validate() ??
            false;

    if (!valid) {
      return;
    }

    final result =
        _EmailChangeInput(
      newEmail:
          _emailController.text
              .trim(),
      currentPassword:
          _passwordController.text,
    );

    _passwordController.clear();

    Navigator.of(context).pop(
      result,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        CupertinoIcons.envelope,
        color:
            _settingsGreen,
        size: 32,
      ),
      title: const Text(
        'Cambiar correo',
        textAlign:
            TextAlign.center,
      ),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 420,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Text(
                'Por seguridad debes verificar tu identidad antes de solicitar el cambio.',
                textAlign:
                    TextAlign.center,
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
                autocorrect: false,
                enableSuggestions:
                    false,
                autofillHints:
                    const [
                  AutofillHints
                      .newUsername,
                ],
                decoration:
                    const InputDecoration(
                  labelText:
                      'Nuevo correo',
                  prefixIcon:
                      Icon(
                    CupertinoIcons.mail,
                  ),
                ),
                validator: (
                  value,
                ) {
                  final email =
                      value
                              ?.trim() ??
                          '';

                  if (email.isEmpty) {
                    return 'Escribe el nuevo correo.';
                  }

                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(email)) {
                    return 'Escribe un correo válido.';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                    _passwordController,
                obscureText:
                    !_showPassword,
                autocorrect: false,
                enableSuggestions:
                    false,
                autofillHints:
                    const [
                  AutofillHints
                      .password,
                ],
                decoration:
                    InputDecoration(
                  labelText:
                      'Contraseña actual',
                  prefixIcon:
                      const Icon(
                    CupertinoIcons
                        .lock,
                  ),
                  suffixIcon:
                      IconButton(
                    onPressed: () {
                      setState(() {
                        _showPassword =
                            !_showPassword;
                      });
                    },
                    icon: Icon(
                      _showPassword
                          ? CupertinoIcons
                              .eye_slash
                          : CupertinoIcons
                              .eye,
                    ),
                  ),
                ),
                validator: (
                  value,
                ) {
                  if (value == null ||
                      value.isEmpty) {
                    return 'Escribe tu contraseña actual.';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _passwordController
                .clear();

            Navigator.of(context)
                .pop();
          },
          child: const Text(
            'Cancelar',
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(
            'Continuar',
          ),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog
    extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog>
      createState() =>
          _ChangePasswordDialogState();
}

class _ChangePasswordDialogState
    extends State<_ChangePasswordDialog> {
  final _formKey =
      GlobalKey<FormState>();

  final _currentController =
      TextEditingController();

  final _newController =
      TextEditingController();

  final _confirmController =
      TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.clear();
    _newController.clear();
    _confirmController.clear();

    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();

    super.dispose();
  }

  bool _hasValidStrength(
    String value,
  ) {
    return value.length >= 10 &&
        RegExp(r'[A-Z]')
            .hasMatch(value) &&
        RegExp(r'[a-z]')
            .hasMatch(value) &&
        RegExp(r'[0-9]')
            .hasMatch(value) &&
        RegExp(
          r'[!@#$%^&*(),.?":{}|<>_\-+=;:/\\\[\]~`]',
        ).hasMatch(value);
  }

  void _submit() {
    final valid =
        _formKey.currentState
                ?.validate() ??
            false;

    if (!valid) {
      return;
    }

    final result =
        _PasswordChangeInput(
      currentPassword:
          _currentController.text,
      newPassword:
          _newController.text,
    );

    _currentController.clear();
    _newController.clear();
    _confirmController.clear();

    Navigator.of(context).pop(
      result,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        CupertinoIcons.lock_shield,
        color:
            _settingsGreen,
        size: 32,
      ),
      title: const Text(
        'Cambiar contraseña',
        textAlign:
            TextAlign.center,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 420,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Text(
                  'Para proteger tu cuenta necesitamos verificar primero tu contraseña actual.',
                  textAlign:
                      TextAlign.center,
                ),

                const SizedBox(
                  height: 18,
                ),

                _PasswordField(
                  controller:
                      _currentController,
                  label:
                      'Contraseña actual',
                  visible:
                      _showCurrent,
                  onToggle: () {
                    setState(() {
                      _showCurrent =
                          !_showCurrent;
                    });
                  },
                  validator: (
                    value,
                  ) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Escribe tu contraseña actual.';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 14,
                ),

                _PasswordField(
                  controller:
                      _newController,
                  label:
                      'Nueva contraseña',
                  visible:
                      _showNew,
                  onToggle: () {
                    setState(() {
                      _showNew =
                          !_showNew;
                    });
                  },
                  validator: (
                    value,
                  ) {
                    final password =
                        value ?? '';

                    if (!_hasValidStrength(
                      password,
                    )) {
                      return 'No cumple los requisitos de seguridad.';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 8,
                ),

                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    '10+ caracteres, mayúscula, minúscula, número y símbolo.',
                    style: TextStyle(
                      fontSize: 11,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                _PasswordField(
                  controller:
                      _confirmController,
                  label:
                      'Confirmar contraseña',
                  visible:
                      _showConfirm,
                  onToggle: () {
                    setState(() {
                      _showConfirm =
                          !_showConfirm;
                    });
                  },
                  validator: (
                    value,
                  ) {
                    if (value !=
                        _newController
                            .text) {
                      return 'Las contraseñas no coinciden.';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _currentController
                .clear();

            _newController
                .clear();

            _confirmController
                .clear();

            Navigator.of(context)
                .pop();
          },
          child: const Text(
            'Cancelar',
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(
            'Cambiar',
          ),
        ),
      ],
    );
  }
}

class _PasswordField
    extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;

  final bool visible;

  final VoidCallback onToggle;

  final String? Function(String?)
      validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [
        AutofillHints.password,
      ],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(
          CupertinoIcons.lock,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            visible
                ? CupertinoIcons.eye_slash
                : CupertinoIcons.eye,
          ),
        ),
      ),
    );
  }
}

class _ChangePhoneDialog
    extends StatefulWidget {
  const _ChangePhoneDialog({
    required this.currentPhone,
  });

  final String currentPhone;

  @override
  State<_ChangePhoneDialog>
      createState() =>
          _ChangePhoneDialogState();
}

class _ChangePhoneDialogState
    extends State<_ChangePhoneDialog> {
  late final TextEditingController
      _controller;

  final _formKey =
      GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _controller =
        TextEditingController(
      text: widget.currentPhone,
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  void _submit() {
    final valid =
        _formKey.currentState
                ?.validate() ??
            false;

    if (!valid) {
      return;
    }

    Navigator.of(context).pop(
      _controller.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        CupertinoIcons.phone,
        color:
            _settingsGreen,
        size: 32,
      ),
      title: const Text(
        'Actualizar teléfono',
        textAlign:
            TextAlign.center,
      ),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 420,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Text(
                'Este número se usa únicamente como información de contacto dentro de tu perfil.',
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height: 18,
              ),

              TextFormField(
                controller:
                    _controller,
                keyboardType:
                    TextInputType.phone,
                autofillHints:
                    const [
                  AutofillHints
                      .telephoneNumber,
                ],
                decoration:
                    const InputDecoration(
                  labelText:
                      'Número de teléfono',
                  prefixIcon:
                      Icon(
                    CupertinoIcons.phone,
                  ),
                  helperText:
                      'Puedes dejarlo vacío para eliminarlo.',
                ),
                validator: (
                  value,
                ) {
                  final phone =
                      value
                              ?.trim() ??
                          '';

                  if (phone.isEmpty) {
                    return null;
                  }

                  if (!RegExp(
                    r'^[0-9+()\-\s]{7,24}$',
                  ).hasMatch(phone)) {
                    return 'Escribe un número válido.';
                  }

                  final digits =
                      phone.replaceAll(
                    RegExp(r'\D'),
                    '',
                  );

                  if (digits.length < 7 ||
                      digits.length >
                          15) {
                    return 'El número debe contener entre 7 y 15 dígitos.';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context)
                .pop();
          },
          child: const Text(
            'Cancelar',
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(
            'Guardar',
          ),
        ),
      ],
    );
  }
}

class _SettingsError
    extends StatelessWidget {
  const _SettingsError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 520,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(
            20,
          ),
          child: Container(
            padding:
                const EdgeInsets.all(
              18,
            ),
            decoration:
                BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              border: Border.all(
                color: Theme.of(
                  context,
                )
                      .colorScheme
                      .outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons
                      .exclamationmark_triangle,
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Text(
                    message,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailChangeInput {
  const _EmailChangeInput({
    required this.newEmail,
    required this.currentPassword,
  });

  final String newEmail;
  final String currentPassword;
}

class _PasswordChangeInput {
  const _PasswordChangeInput({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;
}