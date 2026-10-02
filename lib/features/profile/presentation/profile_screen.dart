import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/register_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada correctamente.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cerrar la sesión. Código: ${e.code}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (user == null) {
          return _buildLoggedOutProfile(context);
        }

        return _buildLoggedInProfile(
          context,
          user,
        );
      },
    );
  }

  Widget _buildLoggedOutProfile(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Perfil',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Inicia sesión para administrar tu cuenta, equipo y actividad.',
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
                  radius: 42,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    size: 46,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Tu cuenta CanchaYA',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accede para ver tu perfil, equipos, torneos y próximos partidos.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
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

  Widget _buildLoggedInProfile(
    BuildContext context,
    User user,
  ) {
    final displayName = user.displayName?.trim();

    final name = displayName != null && displayName.isNotEmpty
        ? displayName
        : 'Jugador CanchaYA';

    final email = user.email ?? 'Correo no disponible';

    final initial = name.isNotEmpty
        ? name.substring(0, 1).toUpperCase()
        : 'J';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Mi perfil',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tu identidad dentro de CanchaYA.',
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
                  radius: 46,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary,
                  child: Text(
                    initial,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Chip(
                  avatar: const Icon(
                    Icons.sports_soccer,
                    size: 18,
                  ),
                  label: const Text('Jugador'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                ),
                title: const Text('Editar perfil'),
                subtitle: const Text(
                  'Nombre, teléfono y fotografía',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'La edición del perfil se conectará en el siguiente paso.',
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.groups_outlined,
                ),
                title: const Text('Mi equipo'),
                subtitle: const Text(
                  'Todavía no perteneces a un equipo',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.emoji_events_outlined,
                ),
                title: const Text('Mis torneos'),
                subtitle: const Text(
                  'Consulta tus competencias',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _signOut(context);
            },
            icon: const Icon(
              Icons.logout,
            ),
            label: const Text(
              'Cerrar sesión',
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}