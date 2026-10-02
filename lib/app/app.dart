import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/domain/user_role.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/domain/user_profile.dart';

class CanchaYaApp extends StatelessWidget {
  const CanchaYaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CanchaYA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _AccountGate(),
    );
  }
}

class _AccountGate extends StatelessWidget {
  const _AccountGate();

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const HomeShell();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          return const HomeShell();
        }

        return StreamBuilder<UserProfile?>(
          stream: ProfileRepository().watchCurrentProfile(),
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data;

            if (profile == null) {
              return const HomeShell();
            }

            if (profile.status == AccountStatus.suspended) {
              return const _SuspendedAccountScreen();
            }

            return const HomeShell();
          },
        );
      },
    );
  }
}

class _SuspendedAccountScreen extends StatelessWidget {
  const _SuspendedAccountScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: colors.errorContainer,
                        child: Icon(
                          Icons.block_outlined,
                          color: colors.onErrorContainer,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Cuenta suspendida',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tu cuenta no puede utilizar las funciones de CanchaYA mientras permanezca suspendida. Una baja de un torneo o liga no provoca este estado; solo Administración CanchaYA puede aplicar una suspensión global.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
