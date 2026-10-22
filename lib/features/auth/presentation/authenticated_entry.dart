import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profile/data/profile_repository.dart';

/// Wait for the Firestore profile before exposing authenticated features.
class AuthenticatedEntry extends StatefulWidget {
  const AuthenticatedEntry({super.key, required this.child});

  final Widget child;

  @override
  State<AuthenticatedEntry> createState() => _AuthenticatedEntryState();
}

class _AuthenticatedEntryState extends State<AuthenticatedEntry> {
  late Future<void> _profile;

  @override
  void initState() {
    super.initState();
    _profile = ProfileRepository().ensureCurrentProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Tu sesión está iniciada, pero no pudimos cargar tu perfil. '
                        'Revisa tu conexión e inténtalo nuevamente.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {
                          _profile = ProfileRepository().ensureCurrentProfile();
                        }),
                        child: const Text('Reintentar'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await FirebaseAuth.instance.signOut();
                          } catch (_) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo cerrar la sesión. Inténtalo nuevamente.',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return widget.child;
      },
    );
  }
}
