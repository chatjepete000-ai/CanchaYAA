import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/user_role.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/register_screen.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                if (snapshot.connectionState == ConnectionState.waiting) {
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Tu cuenta personal dentro de CanchaYA.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    CupertinoIcons.person_fill,
                    size: 42,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Tu cuenta CanchaYA',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Inicia sesión para consultar tu perfil, posición e invitaciones.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: firebaseAvailable
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const LoginScreen(),
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: firebaseAvailable
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegisterScreen(),
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

class _AuthenticatedProfileState extends State<_AuthenticatedProfile> {
  final ProfileRepository _repository = ProfileRepository();

  late final Future<void> _ensureProfileFuture;

  @override
  void initState() {
    super.initState();

    _ensureProfileFuture = _repository.ensureCurrentProfile();
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
      builder: (context, ensureSnapshot) {
        if (ensureSnapshot.connectionState == ConnectionState.waiting) {
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
          stream: _repository.watchCurrentProfile(),
          builder: (context, profileSnapshot) {
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

            final profile = profileSnapshot.data;

            if (profile == null) {
              return const _ProfileError(
                message:
                    'No encontramos la información de tu perfil.',
              );
            }

            return _ProfileContent(
              profile: profile,
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
    required this.onSignOut,
  });

  final UserProfile profile;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final name = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'Jugador CanchaYA';

    final email = profile.email.trim().isNotEmpty
        ? profile.email.trim()
        : 'Correo no disponible';

    final initial = name.substring(0, 1).toUpperCase();

    final photoUrl = profile.photoUrl.trim();

    final hasPhoto = photoUrl.isNotEmpty;

    final roleLabel = _getRoleLabel(profile);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        32,
      ),
      children: [
        Text(
          'Tu identidad y actividad dentro de CanchaYA.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        const SizedBox(height: 22),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary,
                colors.primary.withValues(
                  alpha: 0.76,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: 0.60,
                    ),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 47,
                  backgroundColor: colors.onPrimary.withValues(
                    alpha: 0.16,
                  ),
                  foregroundImage: hasPhoto
                      ? NetworkImage(
                          photoUrl,
                        )
                      : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          initial,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),

              const SizedBox(height: 5),

              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onPrimary.withValues(
                    alpha: 0.88,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _ProfileBadge(
                    icon: CupertinoIcons.shield_fill,
                    label: roleLabel,
                  ),
                  _ProfileBadge(
                    icon: CupertinoIcons.sportscourt_fill,
                    label: profile.position.label,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        Text(
          'Información personal',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                CupertinoIcons.person_crop_circle,
                color: colors.primary,
              ),
            ),
            title: const Text(
              'Editar perfil',
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Foto, nombre, teléfono y posición',
            ),
            trailing: const Icon(
              CupertinoIcons.chevron_right,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EditProfileScreen(
                    profile: profile,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: Text(
                'Invitaciones',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Icon(
              CupertinoIcons.envelope,
              color: colors.primary,
            ),
          ],
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    CupertinoIcons.envelope_open,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sin invitaciones pendientes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Cuando un encargado te invite a formar parte de un equipo, aparecerá aquí.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.shield,
                color: colors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getPermissionDescription(
                    profile,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              onSignOut();
            },
            icon: const Icon(
              CupertinoIcons.arrow_right_square,
            ),
            label: const Text(
              'Cerrar sesión',
            ),
          ),
        ),
      ],
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

  String _getPermissionDescription(
    UserProfile profile,
  ) {
    if (profile.isPlatformAdmin) {
      return 'Tienes permisos globales de administración de CanchaYA.';
    }

    if (profile.isLeagueAdmin) {
      return 'Administras las ligas que te hayan sido asignadas. No puedes suspender ni eliminar cuentas globales.';
    }

    if (profile.isCaptain) {
      return 'Como encargado podrás administrar tu equipo e invitar jugadores.';
    }

    return 'Como jugador puedes editar tu información y aceptar o rechazar invitaciones de equipos.';
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: colors.onPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle,
                ),
                const SizedBox(width: 12),
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
    );
  }
}