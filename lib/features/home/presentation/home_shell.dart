import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../leagues/presentation/league_admin_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../teams/presentation/teams_screen.dart';
import '../../tournaments/presentation/tournaments_screen.dart';
import 'overview_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Evita errores en pruebas donde Firebase
    // todavía no fue inicializado.
    if (Firebase.apps.isEmpty) {
      return _buildShell(
        profile: null,
      );
    }

    final repository = ProfileRepository();

    return StreamBuilder<UserProfile?>(
      stream: repository.watchCurrentProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return _buildShell(
          profile: profile,
        );
      },
    );
  }

  Widget _buildShell({
    required UserProfile? profile,
  }) {
    final canManageLeague =
        profile?.isLeagueAdmin == true ||
        profile?.isPlatformAdmin == true;

    final screens = <Widget>[
      const OverviewScreen(),
      const TeamsScreen(),
      const TournamentsScreen(),

      if (canManageLeague)
        const LeagueAdminScreen(),

      const ProfileScreen(),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(
          Icons.home_outlined,
        ),
        selectedIcon: Icon(
          Icons.home,
        ),
        label: 'Inicio',
      ),
      const NavigationDestination(
        icon: Icon(
          Icons.groups_outlined,
        ),
        selectedIcon: Icon(
          Icons.groups,
        ),
        label: 'Equipos',
      ),
      const NavigationDestination(
        icon: Icon(
          Icons.emoji_events_outlined,
        ),
        selectedIcon: Icon(
          Icons.emoji_events,
        ),
        label: 'Torneos',
      ),

      if (canManageLeague)
        const NavigationDestination(
          icon: Icon(
            Icons.admin_panel_settings_outlined,
          ),
          selectedIcon: Icon(
            Icons.admin_panel_settings,
          ),
          label: 'Admin',
        ),

      const NavigationDestination(
        icon: Icon(
          Icons.person_outline,
        ),
        selectedIcon: Icon(
          Icons.person,
        ),
        label: 'Perfil',
      ),
    ];

    final safeIndex =
        _selectedIndex >= screens.length
            ? screens.length - 1
            : _selectedIndex;

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: safeIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: destinations,
      ),
    );
  }
}