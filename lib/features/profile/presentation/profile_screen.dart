import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/user_role.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/register_screen.dart';
import '../../teams/data/team_repository.dart';
import '../../teams/domain/team_models.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';
import 'edit_profile_screen.dart';

const Color _canchaGreen = Color(0xFF0E9F57);

const double _profileMaxWidth = 720;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi perfil',
        ),
      ),
      body: Firebase.apps.isEmpty
          ? _buildLoggedOutProfile(
              context,
              firebaseAvailable: false,
            )
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final user = snapshot.data;

                if (user == null) {
                  return _buildLoggedOutProfile(
                    context,
                    firebaseAvailable: true,
                  );
                }

                return _AuthenticatedProfile(
                  user: user,
                );
              },
            ),
    );
  }

  Widget _buildLoggedOutProfile(
    BuildContext context, {
    required bool firebaseAvailable,
  }) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final contentWidth =
            constraints.maxWidth > _profileMaxWidth
                ? _profileMaxWidth
                : constraints.maxWidth;

        return Center(
          child: SizedBox(
            width: contentWidth,
            child: ListView(
              padding: const EdgeInsets.all(
                20,
              ),
              children: [
                Text(
                  'Tu identidad deportiva dentro de CanchaYA.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(
                  height: 24,
                ),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(
                      24,
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor:
                              colors.primaryContainer,
                          child: Icon(
                            CupertinoIcons.person_fill,
                            size: 42,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(
                          height: 18,
                        ),
                        Text(
                          'Tu perfil CanchaYA',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        const Text(
                          'Inicia sesión para consultar tu perfil deportivo.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(
                          height: 24,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: firebaseAvailable
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const LoginScreen(),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(
                              CupertinoIcons.arrow_right_circle,
                            ),
                            label: const Text(
                              'Iniciar sesión',
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: firebaseAvailable
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const RegisterScreen(),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(
                              CupertinoIcons.person_add,
                            ),
                            label: const Text(
                              'Crear cuenta',
                            ),
                          ),
                        ),
                      ],
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

class _AuthenticatedProfile extends StatefulWidget {
  const _AuthenticatedProfile({
    required this.user,
  });

  final User user;

  @override
  State<_AuthenticatedProfile> createState() =>
      _AuthenticatedProfileState();
}

class _AuthenticatedProfileState
    extends State<_AuthenticatedProfile> {
  final ProfileRepository _profileRepository =
      ProfileRepository();

  final TeamRepository _teamRepository =
      TeamRepository();

  late final Future<void> _ensureProfileFuture;

  @override
  void initState() {
    super.initState();

    _ensureProfileFuture =
        _profileRepository.ensureCurrentProfile();
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sesión cerrada correctamente.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cerrar la sesión. Código: ${error.code}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ensureProfileFuture,
      builder: (
        context,
        ensureSnapshot,
      ) {
        if (ensureSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (ensureSnapshot.hasError) {
          return _ProfileError(
            message:
                'No se pudo sincronizar el perfil con Firestore.\n${ensureSnapshot.error}',
          );
        }

        return StreamBuilder<UserProfile?>(
          stream:
              _profileRepository.watchCurrentProfile(),
          builder: (
            context,
            profileSnapshot,
          ) {
            if (profileSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !profileSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (profileSnapshot.hasError) {
              return _ProfileError(
                message:
                    'No se pudo cargar tu perfil.\n${profileSnapshot.error}',
              );
            }

            final profile =
                profileSnapshot.data;

            if (profile == null) {
              return const _ProfileError(
                message:
                    'No encontramos la información de tu perfil.',
              );
            }

            return _ProfileContent(
              profile: profile,
              teamRepository: _teamRepository,
              onSignOut: _signOut,
            );
          },
        );
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.teamRepository,
    required this.onSignOut,
  });

  final UserProfile profile;
  final TeamRepository teamRepository;

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final name =
        profile.displayName.trim().isNotEmpty
            ? profile.displayName.trim()
            : 'Jugador CanchaYA';

    final initial =
        name.substring(0, 1).toUpperCase();

    final photoUrl =
        profile.photoUrl.trim();

    final positionLabel =
        profile.position.label;

    final roleLabel =
        _getRoleLabel(profile);

    final isActive =
        profile.status == AccountStatus.active;

    final statusLabel = isActive
        ? 'Cuenta activa'
        : 'Cuenta suspendida';

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final contentWidth =
            constraints.maxWidth > _profileMaxWidth
                ? _profileMaxWidth
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
            child: CustomScrollView(
              physics:
                  const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    0,
                  ),
                  sliver: SliverList(
                    delegate:
                        SliverChildListDelegate(
                      [
                        _SportsIdentityCard(
                          name: name,
                          position: positionLabel,
                          statusLabel:
                              statusLabel,
                          isActive: isActive,
                          photoUrl: photoUrl,
                          initial: initial,
                          onOpenPhoto: () {
                            _showProfilePhoto(
                              context,
                              photoUrl: photoUrl,
                              initial: initial,
                            );
                          },
                          onChangePhoto: () {
                            _openEditProfile(
                              context,
                            );
                          },
                          onEditProfile: () {
                            _openEditProfile(
                              context,
                            );
                          },
                          onCoverPressed: () {
                            _showCoverPreview(
                              context,
                            );
                          },
                          onChangeCover: () {
                            _showCoverUnavailable(
                              context,
                            );
                          },
                        ),

                        const SizedBox(
                          height: 26,
                        ),

                        const _SectionLabel(
                          label:
                              'PERFIL DEPORTIVO',
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Container(
                          decoration:
                              BoxDecoration(
                            color:
                                colors.surface,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              18,
                            ),
                            border:
                                Border.all(
                              color: colors
                                  .outlineVariant,
                            ),
                          ),
                          child: Column(
                            children: [
                              _ProfileInfoRow(
                                icon:
                                    CupertinoIcons
                                        .sportscourt,
                                label:
                                    'Posición',
                                value:
                                    positionLabel,
                              ),
                              Divider(
                                height: 1,
                                indent: 64,
                                color: colors
                                    .outlineVariant,
                              ),
                              _ProfileInfoRow(
                                icon:
                                    CupertinoIcons
                                        .shield,
                                label: 'Rol',
                                value:
                                    roleLabel,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 24,
                        ),

                        const _SectionLabel(
                          label:
                              'EQUIPOS ACTUALES',
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        _CurrentTeamsCard(
                          repository:
                              teamRepository,
                        ),

                        const SizedBox(
                          height: 24,
                        ),
                      ],
                    ),
                  ),
                ),

                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      32,
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.end,
                      children: [
                        Divider(
                          height: 1,
                          color: colors
                              .outlineVariant,
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        SizedBox(
                          width:
                              double.infinity,
                          child:
                              OutlinedButton
                                  .icon(
                            style:
                                OutlinedButton
                                    .styleFrom(
                              minimumSize:
                                  const Size
                                      .fromHeight(
                                50,
                              ),
                              foregroundColor:
                                  colors.error,
                              side:
                                  BorderSide(
                                color: colors
                                    .error
                                    .withValues(
                                  alpha:
                                      0.42,
                                ),
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  16,
                                ),
                              ),
                            ),
                            onPressed: () {
                              onSignOut();
                            },
                            icon:
                                const Icon(
                              CupertinoIcons
                                  .square_arrow_right,
                              size: 19,
                            ),
                            label:
                                const Text(
                              'Cerrar sesión',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  void _openEditProfile(
    BuildContext context,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EditProfileScreen(
          profile: profile,
        ),
      ),
    );
  }

  Future<void> _showProfilePhoto(
    BuildContext context, {
    required String photoUrl,
    required String initial,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          Colors.transparent,
      builder: (
        sheetContext,
      ) {
        return _ProfilePhotoViewer(
          photoUrl: photoUrl,
          initial: initial,
          onEdit: () {
            Navigator.of(
              sheetContext,
            ).pop();

            if (!context.mounted) {
              return;
            }

            _openEditProfile(
              context,
            );
          },
        );
      },
    );
  }

  Future<void> _showCoverPreview(
    BuildContext context,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          Colors.transparent,
      builder: (
        sheetContext,
      ) {
        return _CoverViewer(
          onChangeCover: () {
            Navigator.of(
              sheetContext,
            ).pop();

            if (!context.mounted) {
              return;
            }

            _showCoverUnavailable(
              context,
            );
          },
        );
      },
    );
  }

  void _showCoverUnavailable(
    BuildContext context,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'La portada personalizada se conectará después al perfil.',
        ),
      ),
    );
  }

  String _getRoleLabel(
    UserProfile profile,
  ) {
    if (profile.isPlatformAdmin) {
      return 'Admin de plataforma';
    }

    if (profile.isLeagueAdmin) {
      return 'Admin de liga';
    }

    if (profile.isCaptain) {
      return 'Capitán / Encargado';
    }

    return 'Jugador';
  }
}

class _SportsIdentityCard
    extends StatelessWidget {
  const _SportsIdentityCard({
    required this.name,
    required this.position,
    required this.statusLabel,
    required this.isActive,
    required this.photoUrl,
    required this.initial,
    required this.onOpenPhoto,
    required this.onChangePhoto,
    required this.onEditProfile,
    required this.onCoverPressed,
    required this.onChangeCover,
  });

  final String name;
  final String position;
  final String statusLabel;

  final bool isActive;

  final String photoUrl;
  final String initial;

  final VoidCallback onOpenPhoto;
  final VoidCallback onChangePhoto;
  final VoidCallback onEditProfile;
  final VoidCallback onCoverPressed;
  final VoidCallback onChangeCover;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final isDark =
        theme.brightness ==
            Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color:
              colors.outlineVariant,
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final coverHeight =
                  constraints.maxWidth <
                          350
                      ? 135.0
                      : constraints
                                  .maxWidth <
                              500
                          ? 155.0
                          : 185.0;

              return GestureDetector(
                onTap:
                    onCoverPressed,
                child: SizedBox(
                  height:
                      coverHeight,
                  child: Stack(
                    fit:
                        StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/home/hero_match.jpg',
                        fit:
                            BoxFit.cover,
                        alignment:
                            Alignment.center,
                        errorBuilder: (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return Container(
                            color: isDark
                                ? const Color(
                                    0xFF071B14,
                                  )
                                : const Color(
                                    0xFF183A2C,
                                  ),
                          );
                        },
                      ),

                      Container(
                        decoration:
                            BoxDecoration(
                          gradient:
                              LinearGradient(
                            begin: Alignment
                                .topCenter,
                            end: Alignment
                                .bottomCenter,
                            colors: [
                              Colors.black
                                  .withValues(
                                alpha:
                                    0.02,
                              ),
                              Colors.black
                                  .withValues(
                                alpha:
                                    0.40,
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        left: 12,
                        bottom: 12,
                        child:
                            Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                9,
                            vertical:
                                5,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors
                                .black
                                .withValues(
                              alpha:
                                  0.46,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              100,
                            ),
                          ),
                          child:
                              const Row(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children: [
                              Icon(
                                CupertinoIcons
                                    .sportscourt_fill,
                                color: Colors
                                    .white,
                                size: 12,
                              ),
                              SizedBox(
                                width: 5,
                              ),
                              Text(
                                'CANCHAYA',
                                style:
                                    TextStyle(
                                  color: Colors
                                      .white,
                                  fontSize:
                                      9,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                  letterSpacing:
                                      0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        right: 12,
                        top: 12,
                        child:
                            _CoverCameraButton(
                          onTap:
                              onChangeCover,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          Container(
            height: 3,
            color:
                _canchaGreen,
          ),

          Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child: LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final compact =
                    constraints.maxWidth <
                        330;

                if (compact) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      Row(
                        children: [
                          _ProfilePhoto(
                            photoUrl:
                                photoUrl,
                            initial:
                                initial,
                            size: 82,
                            onTap:
                                onOpenPhoto,
                            onEdit:
                                onChangePhoto,
                          ),

                          const Spacer(),

                          _EditProfileButton(
                            onTap:
                                onEditProfile,
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      _IdentityText(
                        name: name,
                        position:
                            position,
                        statusLabel:
                            statusLabel,
                        isActive:
                            isActive,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .center,
                  children: [
                    _ProfilePhoto(
                      photoUrl:
                          photoUrl,
                      initial:
                          initial,
                      size: constraints
                                  .maxWidth <
                              420
                          ? 82
                          : 94,
                      onTap:
                          onOpenPhoto,
                      onEdit:
                          onChangePhoto,
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    Expanded(
                      child:
                          _IdentityText(
                        name: name,
                        position:
                            position,
                        statusLabel:
                            statusLabel,
                        isActive:
                            isActive,
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    _EditProfileButton(
                      onTap:
                          onEditProfile,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityText
    extends StatelessWidget {
  const _IdentityText({
    required this.name,
    required this.position,
    required this.statusLabel,
    required this.isActive,
  });

  final String name;
  final String position;
  final String statusLabel;

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: theme
              .textTheme
              .titleLarge
              ?.copyWith(
                fontSize: 22,
                height: 1.05,
                fontWeight:
                    FontWeight.w900,
                letterSpacing:
                    -0.5,
              ),
        ),

        const SizedBox(
          height: 7,
        ),

        Row(
          children: [
            const Icon(
              CupertinoIcons
                  .sportscourt_fill,
              size: 13,
              color:
                  _canchaGreen,
            ),

            const SizedBox(
              width: 6,
            ),

            Expanded(
              child: Text(
                position
                    .toUpperCase(),
                maxLines: 1,
                overflow:
                    TextOverflow
                        .ellipsis,
                style:
                    const TextStyle(
                  color:
                      _canchaGreen,
                  fontSize: 11.5,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing:
                      1.15,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 8,
        ),

        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(
                color: isActive
                    ? _canchaGreen
                    : colors.error,
                shape:
                    BoxShape.circle,
              ),
            ),

            const SizedBox(
              width: 6,
            ),

            Expanded(
              child: Text(
                statusLabel,
                maxLines: 1,
                overflow:
                    TextOverflow
                        .ellipsis,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: colors
                          .onSurfaceVariant,
                      fontWeight:
                          FontWeight
                              .w600,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfilePhoto
    extends StatelessWidget {
  const _ProfilePhoto({
    required this.photoUrl,
    required this.initial,
    required this.size,
    required this.onTap,
    required this.onEdit,
  });

  final String photoUrl;
  final String initial;

  final double size;

  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final fallback =
        Container(
      color:
          colors.primaryContainer,
      alignment:
          Alignment.center,
      child: Text(
        initial,
        style: theme
            .textTheme
            .headlineLarge
            ?.copyWith(
              color: colors
                  .onPrimaryContainer,
              fontWeight:
                  FontWeight.w900,
            ),
      ),
    );

    final cameraSize =
        size < 90 ? 29.0 : 32.0;

    return Stack(
      clipBehavior:
          Clip.none,
      children: [
        Material(
          color:
              Colors.transparent,
          shape:
              const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder:
                const CircleBorder(),
            child: Container(
              width: size,
              height: size,
              padding:
                  const EdgeInsets.all(
                3,
              ),
              decoration:
                  BoxDecoration(
                color: colors.surface,
                shape:
                    BoxShape.circle,
                border: Border.all(
                  color:
                      _canchaGreen,
                  width: 2.5,
                ),
              ),
              child: ClipOval(
                child: photoUrl
                        .isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit:
                            BoxFit.cover,
                        errorBuilder: (
                          context,
                          error,
                          stackTrace,
                        ) =>
                            fallback,
                      )
                    : fallback,
              ),
            ),
          ),
        ),

        Positioned(
          right: -1,
          bottom: 1,
          child: Material(
            color:
                _canchaGreen,
            shape:
                const CircleBorder(),
            elevation: 2,
            child: InkWell(
              onTap: onEdit,
              customBorder:
                  const CircleBorder(),
              child: SizedBox(
                width:
                    cameraSize,
                height:
                    cameraSize,
                child:
                    const Icon(
                  CupertinoIcons
                      .camera_fill,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverCameraButton
    extends StatelessWidget {
  const _CoverCameraButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black
          .withValues(
        alpha: 0.50,
      ),
      borderRadius:
          BorderRadius.circular(
        12,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        child:
            const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            CupertinoIcons
                .camera_fill,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _EditProfileButton
    extends StatelessWidget {
  const _EditProfileButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Tooltip(
      message:
          'Editar perfil deportivo',
      child: Material(
        color: colors
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color: colors
                    .outlineVariant,
              ),
            ),
            child: Icon(
              CupertinoIcons.pencil,
              size: 18,
              color:
                  colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel
    extends StatelessWidget {
  const _SectionLabel({
    required this.label,
  });

  final String label;

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
                _canchaGreen,
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
            label,
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

class _ProfileInfoRow
    extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: _canchaGreen
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
                  _canchaGreen,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
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
                ),

                const SizedBox(
                  width: 12,
                ),

                Flexible(
                  child: Text(
                    value,
                    textAlign:
                        TextAlign.right,
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 14.5,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentTeamsCard
    extends StatelessWidget {
  const _CurrentTeamsCard({
    required this.repository,
  });

  final TeamRepository repository;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return StreamBuilder<
        List<TeamAssignment>>(
      stream: repository
          .watchActiveAssignmentsForCurrentUser(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _TeamsStatusBox(
            icon:
                CupertinoIcons.clock,
            message:
                'Sincronizando tus equipos...',
            loading: true,
          );
        }

        if (snapshot.hasError) {
          return const _TeamsStatusBox(
            icon:
                CupertinoIcons
                    .exclamationmark_triangle,
            message:
                'No se pudieron sincronizar tus equipos.',
          );
        }

        final assignments =
            snapshot.data ??
                const <TeamAssignment>[];

        final assignmentsByTeam =
            <String, TeamAssignment>{};

        for (final assignment
            in assignments) {
          final teamId =
              assignment.teamId.trim();

          if (teamId.isEmpty) {
            continue;
          }

          final existing =
              assignmentsByTeam[
                  teamId];

          if (existing == null) {
            assignmentsByTeam[
                teamId] = assignment;
            continue;
          }

          if (assignment.isManager &&
              !existing.isManager) {
            assignmentsByTeam[
                teamId] = assignment;
          }
        }

        if (assignmentsByTeam
            .isEmpty) {
          return const _TeamsStatusBox(
            icon:
                CupertinoIcons.person_2,
            message:
                'No perteneces a ningún equipo activo.',
          );
        }

        final entries =
            assignmentsByTeam.entries
                .toList();

        return Container(
          decoration:
              BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: colors
                  .outlineVariant,
            ),
          ),
          child: Column(
            children: [
              for (var index = 0;
                  index <
                      entries.length;
                  index++) ...[
                _LiveTeamRow(
                  repository:
                      repository,
                  teamId:
                      entries[index].key,
                  assignment:
                      entries[index].value,
                ),
                if (index !=
                    entries.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: colors
                        .outlineVariant,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LiveTeamRow
    extends StatelessWidget {
  const _LiveTeamRow({
    required this.repository,
    required this.teamId,
    required this.assignment,
  });

  final TeamRepository repository;
  final String teamId;
  final TeamAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Team?>(
      stream:
          repository.watchTeamById(
        teamId,
      ),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding:
                EdgeInsets.all(
              16,
            ),
            child:
                LinearProgressIndicator(
              minHeight: 2,
            ),
          );
        }

        if (snapshot.hasError) {
          return _TeamRowContent(
            teamName:
                'Equipo no disponible',
            subtitle:
                assignment.role.label,
            muted: true,
          );
        }

        final team =
            snapshot.data;

        if (team == null) {
          return _TeamRowContent(
            teamName:
                'Equipo no disponible',
            subtitle:
                assignment.role.label,
            muted: true,
          );
        }

        final teamName =
            team.name.trim().isNotEmpty
                ? team.name.trim()
                : 'Equipo CanchaYA';

        final subtitle =
            team.status == TeamStatus.active
                ? assignment.role.label
                : '${assignment.role.label} · ${team.status.label}';

        return _TeamRowContent(
          teamName: teamName,
          subtitle: subtitle,
          muted:
              team.status != TeamStatus.active,
        );
      },
    );
  }
}

class _TeamRowContent
    extends StatelessWidget {
  const _TeamRowContent({
    required this.teamName,
    required this.subtitle,
    this.muted = false,
  });

  final String teamName;
  final String subtitle;

  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: _canchaGreen
                  .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: const Icon(
              CupertinoIcons.person_2_fill,
              size: 18,
              color: _canchaGreen,
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
                  teamName,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight:
                        FontWeight.w800,
                    color: muted
                        ? colors
                            .onSurfaceVariant
                        : colors.onSurface,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  subtitle,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamsStatusBox
    extends StatelessWidget {
  const _TeamsStatusBox({
    required this.icon,
    required this.message,
    this.loading = false,
  });

  final IconData icon;
  final String message;

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        16,
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
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: _canchaGreen
                  .withValues(
                alpha: 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: loading
                ? const Padding(
                    padding:
                        EdgeInsets.all(
                      10,
                    ),
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    icon,
                    size: 18,
                    color:
                        _canchaGreen,
                  ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Text(
              message,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                    fontWeight:
                        FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePhotoViewer
    extends StatelessWidget {
  const _ProfilePhotoViewer({
    required this.photoUrl,
    required this.initial,
    required this.onEdit,
  });

  final String photoUrl;
  final String initial;

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final fallback =
        Container(
      color:
          colors.primaryContainer,
      alignment:
          Alignment.center,
      child: Text(
        initial,
        style: theme
            .textTheme
            .displayLarge
            ?.copyWith(
              color: colors
                  .onPrimaryContainer,
              fontWeight:
                  FontWeight.w900,
            ),
      ),
    );

    return Container(
      decoration:
          BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(
          top: Radius.circular(
            28,
          ),
        ),
      ),
      padding:
          const EdgeInsets.fromLTRB(
        18,
        10,
        18,
        26,
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration:
                BoxDecoration(
              color: colors
                  .onSurfaceVariant
                  .withValues(
                alpha: 0.28,
              ),
              borderRadius:
                  BorderRadius.circular(
                100,
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Foto de perfil',
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                ),
              ),

              IconButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop();
                },
                icon: const Icon(
                  CupertinoIcons.xmark,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 360,
              maxHeight: 430,
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
                child: photoUrl
                        .isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (
                          context,
                          error,
                          stackTrace,
                        ) =>
                            fallback,
                      )
                    : fallback,
              ),
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(
                CupertinoIcons.camera_fill,
              ),
              label: const Text(
                'Cambiar foto',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverViewer
    extends StatelessWidget {
  const _CoverViewer({
    required this.onChangeCover,
  });

  final VoidCallback onChangeCover;

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    return Container(
      decoration:
          BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(
          top: Radius.circular(
            28,
          ),
        ),
      ),
      padding:
          const EdgeInsets.fromLTRB(
        18,
        10,
        18,
        26,
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration:
                BoxDecoration(
              color: colors
                  .onSurfaceVariant
                  .withValues(
                alpha: 0.28,
              ),
              borderRadius:
                  BorderRadius.circular(
                100,
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Foto de portada',
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                ),
              ),

              IconButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop();
                },
                icon: const Icon(
                  CupertinoIcons.xmark,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              22,
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/home/hero_match.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return Container(
                        color:
                            const Color(
                          0xFF123326,
                        ),
                      );
                    },
                  ),

                  Container(
                    color: Colors.black
                        .withValues(
                      alpha: 0.22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  onChangeCover,
              icon: const Icon(
                CupertinoIcons.camera_fill,
              ),
              label: const Text(
                'Cambiar portada',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            'La portada personalizada se conectará después al perfil.',
            textAlign:
                TextAlign.center,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: colors
                      .onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProfileError
    extends StatelessWidget {
  const _ProfileError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final contentWidth =
            constraints.maxWidth >
                    _profileMaxWidth
                ? _profileMaxWidth
                : constraints.maxWidth;

        return Center(
          child: SizedBox(
            width: contentWidth,
            child: ListView(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              children: [
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      20,
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
              ],
            ),
          ),
        );
      },
    );
  }
}