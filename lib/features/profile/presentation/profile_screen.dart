import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../admin/presentation/admin_center_screen.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/register_screen.dart';
import '../../teams/data/team_repository.dart';
import '../../teams/domain/team_models.dart';
import '../../teams/presentation/join_team_screen.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return _LoggedOutProfile(
        onLogin: () {},
        onRegister: () {},
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        if (user == null) {
          return _LoggedOutProfile(
            onLogin: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LoginScreen(),
              ),
            ),
            onRegister: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RegisterScreen(),
              ),
            ),
          );
        }

        return _AuthenticatedProfile(user: user);
      },
    );
  }
}

class _AuthenticatedProfile extends StatefulWidget {
  const _AuthenticatedProfile({required this.user});

  final User user;

  @override
  State<_AuthenticatedProfile> createState() => _AuthenticatedProfileState();
}

class _AuthenticatedProfileState extends State<_AuthenticatedProfile> {
  final _profileRepository = ProfileRepository();
  final _teamRepository = TeamRepository();

  late final Future<void> _ensureProfile;

  @override
  void initState() {
    super.initState();
    _ensureProfile = _profileRepository.ensureCurrentProfile();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesión cerrada correctamente.')),
    );
  }

  Future<void> _respond(
    TeamInvitation invitation, {
    required bool accept,
  }) async {
    try {
      await _teamRepository.respondToInvitation(
        invitation: invitation,
        accept: accept,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Invitación aceptada.' : 'Invitación rechazada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo responder: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ensureProfile,
      builder: (context, ensureSnapshot) {
        if (ensureSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (ensureSnapshot.hasError) {
          return const _ProfileError(
            message:
                'No pudimos sincronizar tu perfil con la nube. Revisa Firestore y vuelve a intentarlo.',
          );
        }

        return StreamBuilder<UserProfile?>(
          stream: _profileRepository.watchCurrentProfile(),
          builder: (context, profileSnapshot) {
            if (!profileSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = profileSnapshot.data!;
            return _ProfileContent(
              profile: profile,
              invitationStream: _teamRepository.watchMyPendingInvitations(),
              onSignOut: _signOut,
              onInvitationResponse: _respond,
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
    required this.invitationStream,
    required this.onSignOut,
    required this.onInvitationResponse,
  });

  final UserProfile profile;
  final Stream<List<TeamInvitation>> invitationStream;
  final Future<void> Function() onSignOut;
  final Future<void> Function(
    TeamInvitation invitation, {
    required bool accept,
  }) onInvitationResponse;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name =
        profile.displayName.isEmpty ? 'Jugador CanchaYA' : profile.displayName;
    final initial = name.substring(0, 1).toUpperCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Mi perfil',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tu identidad, posición e invitaciones dentro de CanchaYA.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary,
                colors.primary.withValues(alpha: 0.78),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: colors.onPrimary.withValues(alpha: 0.16),
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.email,
                style: TextStyle(
                  color: colors.onPrimary.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _ProfileBadge(
                    icon: Icons.verified_user_outlined,
                    label: profile.adminScope == AdminScope.none
                        ? profile.role.label
                        : profile.adminScope.label,
                  ),
                  _ProfileBadge(
                    icon: Icons.sports_soccer_outlined,
                    label: profile.position.label,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text(
                  'Editar perfil',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  profile.phone.isEmpty
                      ? 'Nombre, teléfono y posición'
                      : '${profile.phone} · ${profile.position.label}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditProfileScreen(profile: profile),
                  ),
                ),
              ),
              if (profile.adminScope != AdminScope.none) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: Text(
                    profile.adminScope == AdminScope.platform
                        ? 'Administración CanchaYA'
                        : 'Administración de liga',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    profile.adminScope == AdminScope.platform
                        ? 'Control global de plataforma'
                        : 'Torneos, equipos, campos, horarios y árbitros',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminCenterScreen(profile: profile),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
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
            const Icon(Icons.mail_outline),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const JoinTeamScreen(),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Tengo un código o QR'),
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<TeamInvitation>>(
          stream: invitationStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _ProfileError(
                message: 'No fue posible cargar las invitaciones.',
              );
            }

            final invitations = snapshot.data ?? const [];
            if (invitations.isEmpty) {
              return const _InvitationEmpty();
            }

            return Column(
              children: invitations
                  .map(
                    (invitation) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                invitation.teamName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Te invitaron a formar parte de este equipo.',
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => onInvitationResponse(
                                        invitation,
                                        accept: false,
                                      ),
                                      child: const Text('Rechazar'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => onInvitationResponse(
                                        invitation,
                                        accept: true,
                                      ),
                                      child: const Text('Aceptar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: colors.onPrimary),
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

class _InvitationEmpty extends StatelessWidget {
  const _InvitationEmpty();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No tienes invitaciones pendientes. Cuando un encargado te invite a un equipo, aparecerá aquí.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggedOutProfile extends StatelessWidget {
  const _LoggedOutProfile({
    required this.onLogin,
    required this.onRegister,
  });

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Perfil',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.account_circle_outlined, size: 64),
                const SizedBox(height: 14),
                const Text(
                  'Tu cuenta CanchaYA',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Inicia sesión para administrar tu perfil, invitaciones, equipos y torneos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onRegister,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Crear cuenta'),
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

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
