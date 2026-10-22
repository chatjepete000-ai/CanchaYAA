import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/authenticated_entry.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/onboarding/presentation/intro_screen.dart';

class CanchaYaApp extends StatefulWidget {
  const CanchaYaApp({super.key});

  @override
  State<CanchaYaApp> createState() =>
      _CanchaYaAppState();
}

class _CanchaYaAppState
    extends State<CanchaYaApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();

    _themeController = ThemeController(
      initialMode: ThemeMode.light,
    );
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'CanchaYA',
          debugShowCheckedModeBanner: false,

          theme: AppTheme.light(),

          darkTheme: AppTheme.dark(),

          themeMode:
              _themeController.themeMode,

          home: _AppEntry(
            themeController:
                _themeController,
          ),
        );
      },
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry({
    required this.themeController,
  });

  final ThemeController themeController;

  @override
  State<_AppEntry> createState() =>
      _AppEntryState();
}

class _AppEntryState
    extends State<_AppEntry> {
  bool _introFinished = false;

  void _finishIntro() {
    if (!mounted) {
      return;
    }

    setState(() {
      _introFinished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_introFinished) {
      return IntroScreen(
        onFinished: _finishIntro,
      );
    }

    return StreamBuilder<User?>(
      stream:
          FirebaseAuth.instance
              .authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        if (user.providerData.any((provider) => provider.providerId == 'google.com')) {
          return AuthenticatedEntry(
            key: ValueKey(user.uid),
            child: HomeShell(themeController: widget.themeController),
          );
        }

        return HomeShell(
          themeController:
              widget.themeController,
        );
      },
    );
  }
}

class _LoadingScreen
    extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child:
            CircularProgressIndicator(
          color: Theme.of(context)
              .colorScheme
              .primary,
        ),
      ),
    );
  }
}