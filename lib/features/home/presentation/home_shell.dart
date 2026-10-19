import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/theme_controller.dart';
import '../../leagues/presentation/league_admin_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../teams/presentation/teams_screen.dart';
import '../../tournaments/presentation/tournaments_screen.dart';
import 'overview_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.themeController,
  });

  final ThemeController themeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return _buildShell(
        profile: null,
      );
    }

    final repository = ProfileRepository();

    return StreamBuilder<UserProfile?>(
      stream: repository.watchCurrentProfile(),
      builder: (context, snapshot) {
        return _buildShell(
          profile: snapshot.data,
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
      OverviewScreen(
        themeController: widget.themeController,
      ),
      const TeamsScreen(),
      const TournamentsScreen(),
      if (canManageLeague)
        const LeagueAdminScreen(),
    ];

    final navItems = <_NavItemData>[
      const _NavItemData(
        label: 'Inicio',
        icon: CupertinoIcons.house,
        selectedIcon: CupertinoIcons.house_fill,
      ),
      const _NavItemData(
        label: 'Equipos',
        icon: CupertinoIcons.person_2,
        selectedIcon: CupertinoIcons.person_2_fill,
      ),
      const _NavItemData(
        label: 'Torneos',
        icon: CupertinoIcons.star_circle,
        selectedIcon: CupertinoIcons.star_circle_fill,
      ),
      if (canManageLeague)
        const _NavItemData(
          label: 'Admin',
          icon: CupertinoIcons.shield,
          selectedIcon: CupertinoIcons.shield_fill,
        ),
    ];

    final safeIndex =
        _selectedIndex >= screens.length
            ? 0
            : _selectedIndex;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: safeIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: _CanchaYaBottomBar(
        selectedIndex: safeIndex,
        items: navItems,
        onSelected: (index) {
          if (index == safeIndex) {
            return;
          }

          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class _CanchaYaBottomBar extends StatelessWidget {
  const _CanchaYaBottomBar({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_NavItemData> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    const activeGreen =
        Color(0xFF24C96B);

    final barColor = isDark
        ? const Color(0xFF071A13)
        : Colors.white;

    final borderColor = isDark
        ? const Color(0xFF183D2E)
        : const Color(0xFFE0EAE4);

    final inactiveColor = isDark
        ? const Color(0xFF849B90)
        : const Color(0xFF75827B);

    return Container(
      color: isDark
          ? const Color(0xFF04120D)
          : const Color(0xFFF5F8F6),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            12,
            7,
            12,
            9,
          ),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha:
                        isDark ? 0.22 : 0.08,
                  ),
                  blurRadius: 24,
                  offset: const Offset(
                    0,
                    8,
                  ),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: List.generate(
                items.length,
                (index) {
                  final item = items[index];

                  final isSelected =
                      index == selectedIndex;

                  return Expanded(
                    child: _NavigationItem(
                      item: item,
                      isSelected: isSelected,
                      activeColor: activeGreen,
                      inactiveColor: inactiveColor,
                      isDark: isDark,
                      onTap: () {
                        onSelected(index);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.item,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
    required this.onTap,
  });

  final _NavItemData item;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 220,
            ),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(
                      alpha:
                          isDark ? 0.13 : 0.11,
                    )
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 220,
                  ),
                  width:
                      isSelected ? 34 : 30,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(
                            alpha: isDark
                                ? 0.16
                                : 0.12,
                          )
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(
                      11,
                    ),
                  ),
                  child: Icon(
                    isSelected
                        ? item.selectedIcon
                        : item.icon,
                    size:
                        isSelected ? 20 : 19,
                    color: isSelected
                        ? activeColor
                        : inactiveColor,
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: isSelected
                          ? activeColor
                          : inactiveColor,
                      fontSize: 10,
                      height: 1,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 220,
                  ),
                  width:
                      isSelected ? 15 : 0,
                  height: 2,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius:
                        BorderRadius.circular(
                      100,
                    ),
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

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}