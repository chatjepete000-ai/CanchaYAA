import '../../courts/presentation/courts_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/theme_controller.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/domain/app_notification.dart';
import '../../notifications/presentation/notification_center_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../settings/presentation/account_settings_screen.dart';

const Color _green = Color(0xFF0E9F57);
const Color _greenLight = Color(0xFF47E582);
const Color _gold = Color(0xFFE9B72B);

const Color _darkBackground = Color(0xFF03100C);
const Color _darkCard = Color(0xFF071B14);
const Color _darkCardSoft = Color(0xFF0B261B);

const Color _lightBackground = Color(0xFFF4F8F5);

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.themeController,
  });

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return _HomeContent(
        user: null,
        themeController: themeController,
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        return _HomeContent(
          user: snapshot.data,
          themeController: themeController,
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.user,
    required this.themeController,
  });

  final User? user;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark =
        theme.brightness == Brightness.dark;

    final displayName =
        user?.displayName?.trim();

    final completeName =
        displayName != null &&
                displayName.isNotEmpty
            ? displayName
            : 'Jugador';

    final firstName =
        completeName.split(' ').first;

    return Container(
      color: isDark
          ? _darkBackground
          : _lightBackground,
      child: CustomScrollView(
        physics:
            const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              14,
              18,
              34,
            ),
            sliver: SliverList(
              delegate:
                  SliverChildListDelegate(
                [
                  _buildHeader(
                    context,
                    name: firstName,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 18),

                  _buildSearchBar(
                    context,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),

                  _buildMatchHero(
                    context,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 22),

                  _buildQuickActions(
                    context,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 26),

                  _buildNearbyCourts(
                    context,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'Tu actividad',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontSize: 21,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Un vistazo rápido a tu cuenta',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),

                  const SizedBox(height: 15),

                  _buildInvitationsWallet(
                    context,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 11),

                  _buildTournamentWallet(
                    context,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 11),

                  _buildTeamWallet(
                    context,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 18),

                  _buildSeasonMessage(
                    context,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'CanchaYA',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                              .withValues(
                              alpha: 0.20,
                            )
                          : Colors.black
                              .withValues(
                              alpha: 0.18,
                            ),
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String name,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -1.2,
                    height: 1,
                    color: isDark
                        ? Colors.white
                        : const Color(
                            0xFF0A3323,
                          ),
                  ),
                  children: const [
                    TextSpan(
                      text: 'Cancha',
                    ),
                    TextSpan(
                      text: 'YA',
                      style: TextStyle(
                        color:
                            _greenLight,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(
                    CupertinoIcons
                        .location_fill,
                    size: 15,
                    color: _green,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Montemorelos, N.L.',
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w600,
                        fontSize: 13,
                        color: isDark
                            ? const Color(
                                0xFFA6BAAF,
                              )
                            : const Color(
                                0xFF607067,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons
                        .chevron_down,
                    size: 11,
                    color: isDark
                        ? const Color(
                            0xFF82968B,
                          )
                        : const Color(
                            0xFF6C786F,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),

        _NotificationBellButton(
          key: ValueKey<String?>(
            user?.uid,
          ),
          isDark: isDark,
        ),

        const SizedBox(width: 7),

        _ProfileButton(
          user: user,
          name: name,
          isDark: isDark,
          onTap: () =>
              _showAccountMenu(context),
        ),
      ],
    );
  }

  // ============================================================
  // MENÚ DE CUENTA
  // ============================================================

  void _showAccountMenu(BuildContext context) {
    final account = Firebase.apps.isEmpty
        ? user
        : (FirebaseAuth.instance
                .currentUser ??
            user);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _AccountSheet(
          user: account,
          themeController:
              themeController,
          onOpenProfile: () {
            Navigator.of(sheetContext)
                .pop();
            _openProfile(context);
          },
          onOpenAppearance: () {
            Navigator.of(sheetContext)
                .pop();
            _showAppearanceSheet(
              context,
            );
          },
          onOpenSettings: () {
            Navigator.of(sheetContext)
                .pop();
            _openSettings(context);
          },
        );
      },
    );
  }

  void _openProfile(
    BuildContext context,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ProfileScreen(),
      ),
    );
  }

  void _showAppearanceSheet(
    BuildContext context,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return _AppearanceSheet(
          themeController:
              themeController,
        );
      },
    );
  }

  void _openSettings(
    BuildContext context,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AccountSettingsScreen(
          themeController:
              themeController,
        ),
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context, {
    required bool isDark,
  }) {
    return Container(
      height: 56,
      padding:
          const EdgeInsets.only(
        left: 17,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? _darkCardSoft
            : Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(
                  0xFF174531,
                )
              : const Color(
                  0xFFDDE9E1,
                ),
        ),
        boxShadow: isDark
            ? const []
            : const [
                BoxShadow(
                  color:
                      Color(0x0C000000),
                  blurRadius: 20,
                  offset:
                      Offset(0, 7),
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            size: 21,
            color: isDark
                ? const Color(
                    0xFF9AADA2,
                  )
                : const Color(
                    0xFF6D7B73,
                  ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              'Buscar canchas, equipos o torneos...',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark
                    ? const Color(
                        0xFF9AADA2,
                      )
                    : const Color(
                        0xFF707C75,
                      ),
                fontSize: 14,
              ),
            ),
          ),

          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _green.withValues(
                alpha:
                    isDark ? 0.17 : 0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: const Icon(
              CupertinoIcons
                  .slider_horizontal_3,
              color: _green,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchHero(
    BuildContext context, {
    required bool isDark,
  }) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(25),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/home/hero_match.jpg',
              fit: BoxFit.cover,
              alignment:
                  Alignment.center,
            ),

            DecoratedBox(
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.centerLeft,
                  end:
                      Alignment.centerRight,
                  colors: [
                    const Color(
                      0xEE032A1B,
                    ),
                    const Color(
                      0xC906432A,
                    ),
                    Colors.black
                        .withValues(
                      alpha: 0.17,
                    ),
                  ],
                  stops: const [
                    0,
                    0.57,
                    1,
                  ],
                ),
              ),
            ),

            Positioned(
              left: 18,
              right: 18,
              top: 17,
              bottom: 17,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              _greenLight,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            100,
                          ),
                        ),
                        child:
                            const Text(
                          'PRÓXIMO PARTIDO',
                          style:
                              TextStyle(
                            color:
                                Color(
                              0xFF04341F,
                            ),
                            fontSize: 10,
                            fontWeight:
                                FontWeight
                                    .w900,
                            letterSpacing:
                                0.5,
                          ),
                        ),
                      ),

                      const Spacer(),

                      Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(
                          color: Colors
                              .black
                              .withValues(
                            alpha: 0.25,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            13,
                          ),
                          border:
                              Border.all(
                            color: Colors
                                .white
                                .withValues(
                              alpha:
                                  0.20,
                            ),
                          ),
                        ),
                        child:
                            const Icon(
                          CupertinoIcons
                              .calendar,
                          color:
                              Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  const Text(
                    'Aún no tienes\npartidos programados',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      height: 1.06,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 9),

                  Text(
                    'Cuando tu equipo tenga un encuentro aparecerá aquí.',
                    style: TextStyle(
                      color: Colors.white
                          .withValues(
                        alpha: 0.87,
                      ),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context, {
    required bool isDark,
  }) {
    return Row(
      children: [
        Expanded(
          child: _QuickCard(
            icon:
                CupertinoIcons
                    .person_2_fill,
            title: 'Mi equipo',
            subtitle:
                'Plantilla y actividad',
            accent: _green,
            isDark: isDark,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _QuickCard(
            icon:
                CupertinoIcons
                    .star_fill,
            title: 'Torneos',
            subtitle:
                'Competencias',
            accent: _gold,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyCourts(BuildContext context, {required bool isDark}) {
    void explore() => Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/canchas'),
        builder: (_) => const CourtsScreen(),
      ),
    );
    return Column(
      children: [
        _SectionTitle(
          icon: CupertinoIcons.location_fill,
          title: 'Canchas',
          action: 'Ver mapa',
          isDark: isDark,
          onTap: explore,
        ),
        const SizedBox(height: 13),
        Semantics(
          button: true,
          label: 'Explorar canchas en Montemorelos',
          child: InkWell(
            onTap: explore,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 210,
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                image: const DecorationImage(
                  image: AssetImage('assets/images/home/map_preview.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? _darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.map_outlined, color: _green),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Explorar canchas en Montemorelos',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Icon(Icons.arrow_forward, color: _green),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationsWallet(
    BuildContext context, {
    required bool isDark,
  }) {
    return _ActivityWallet(
      isDark: isDark,
      accent: const Color(
        0xFF34C97A,
      ),
      icon:
          CupertinoIcons.envelope_fill,
      title: 'Invitaciones',
      value: '0 pendientes',
      subtitle:
          'Revisa invitaciones de equipos',
      action: 'Ver todas',
      onTap: () {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Después conectaremos esta tarjeta con tus invitaciones reales.',
            ),
          ),
        );
      },
    );
  }

  Widget _buildTournamentWallet(
    BuildContext context, {
    required bool isDark,
  }) {
    return _ActivityWallet(
      isDark: isDark,
      accent: _gold,
      icon:
          CupertinoIcons.star_fill,
      title: 'Torneos',
      value: 'Sin torneo activo',
      subtitle:
          'Jornadas, resultados y clasificación',
      action: 'Ver torneos',
      thumbnail:
          'assets/images/home/trofeo_dorado_estadio.png',
    );
  }

  Widget _buildTeamWallet(
    BuildContext context, {
    required bool isDark,
  }) {
    return _ActivityWallet(
      isDark: isDark,
      accent: _green,
      icon:
          CupertinoIcons.person_2_fill,
      title: 'Tu equipo',
      value: 'Sin equipo activo',
      subtitle:
          'Plantilla, actividad e información',
      action: 'Ver equipo',
      thumbnail:
          'assets/images/home/escuadra_acero_luces_verdes.png',
    );
  }

  Widget _buildSeasonMessage(
    BuildContext context, {
    required bool isDark,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  Color(0xFF0D291E),
                  Color(0xFF081B14),
                ],
              )
            : const LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F7ED),
                  Color(0xFFF6FBF8),
                ],
              ),
        borderRadius:
            BorderRadius.circular(21),
        border: Border.all(
          color: _green.withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  _greenLight,
                  _green,
                ],
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                14,
              ),
            ),
            child: const Icon(
              CupertinoIcons.sparkles,
              color: Colors.white,
              size: 21,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Tu temporada empieza aquí',
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                ),

                const SizedBox(height: 4),

                Text(
                  'CanchaYA irá mostrando tu actividad conforme participes.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityWallet
    extends StatelessWidget {
  const _ActivityWallet({
    required this.isDark,
    required this.accent,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.action,
    this.thumbnail,
    this.onTap,
  });

  final bool isDark;

  final Color accent;
  final IconData icon;

  final String title;
  final String value;
  final String subtitle;
  final String action;

  final String? thumbnail;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 105,
          padding:
              const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: isDark
                ? _darkCard
                : Colors.white,
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color: isDark
                  ? const Color(
                      0xFF163F2D,
                    )
                  : const Color(
                      0xFFE0EAE4,
                    ),
            ),
            boxShadow: isDark
                ? const []
                : const [
                    BoxShadow(
                      color: Color(
                        0x0B000000,
                      ),
                      blurRadius: 17,
                      offset:
                          Offset(0, 7),
                    ),
                  ],
          ),
          child: Row(
            children: [
              if (thumbnail != null)
                ClipRRect(
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                  child: Stack(
                    alignment:
                        Alignment.center,
                    children: [
                      SizedBox(
                        width: 77,
                        height: 77,
                        child:
                            Image.asset(
                          thumbnail!,
                          fit: BoxFit.cover,
                        ),
                      ),

                      Container(
                        width: 77,
                        height: 77,
                        color: Colors.black
                            .withValues(
                          alpha: 0.20,
                        ),
                      ),

                      Container(
                        width: 35,
                        height: 35,
                        decoration:
                            BoxDecoration(
                          color: accent
                              .withValues(
                            alpha: 0.86,
                          ),
                          shape:
                              BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color:
                              Colors.white,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration:
                      BoxDecoration(
                    color: accent
                        .withValues(
                      alpha: 0.13,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      17,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: accent,
                    size: 25,
                  ),
                ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ),

                        Text(
                          action,
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),

                        const SizedBox(
                          width: 3,
                        ),

                        Icon(
                          CupertinoIcons
                              .chevron_right,
                          color: accent,
                          size: 12,
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      value,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontSize: 16,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.isDark,
  });

  final IconData icon;

  final String title;
  final String subtitle;

  final Color accent;

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 126,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: isDark
              ? [
                  accent.withValues(
                    alpha: 0.20,
                  ),
                  _darkCard,
                ]
              : [
                  accent.withValues(
                    alpha: 0.13,
                  ),
                  Colors.white,
                ],
        ),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(
            alpha: 0.22,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color: accent.withValues(
                alpha: 0.15,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 20,
            ),
          ),

          const Spacer(),

          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
          ),

          const SizedBox(height: 2),

          Text(
            subtitle,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle
    extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.action,
    required this.isDark,
    this.onTap,
  });

  final IconData icon;

  final String title;
  final String action;

  final bool isDark;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration:
              const BoxDecoration(
            gradient:
                LinearGradient(
              colors: [
                _greenLight,
                _green,
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: -0.4,
                ),
          ),
        ),

        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: _green,
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 4,
            ),
          ),
          child: Row(
            children: [
              Text(
                action,
                style:
                    const TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(width: 3),

              const Icon(
                CupertinoIcons
                    .chevron_right,
                size: 13,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderButton
    extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;

  final bool isDark;
  final bool showBadge;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color:
              Colors.transparent,
          child: InkWell(
            customBorder:
                const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 39,
              height: 39,
              decoration:
                  BoxDecoration(
                color: isDark
                    ? const Color(
                        0xFF0B241A,
                      )
                    : Colors.white,
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color: isDark
                      ? const Color(
                          0xFF17432F,
                        )
                      : const Color(
                          0xFFDCE7E0,
                        ),
                ),
              ),
              child: Icon(
                icon,
                size: 19,
              ),
            ),
          ),
        ),

        if (showBadge)
          Positioned(
            right: 1,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration:
                  const BoxDecoration(
                color: Color(
                  0xFFFF4A4A,
                ),
                shape:
                    BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.user,
    required this.name,
    required this.isDark,
    required this.onTap,
  });

  final User? user;

  final String name;

  final bool isDark;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoUrl =
        user?.photoURL?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(100),
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(
            3,
            3,
            7,
            3,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(
                    0xFF0A2118,
                  )
                : Colors.white,
            borderRadius:
                BorderRadius.circular(
              100,
            ),
            border: Border.all(
              color: isDark
                  ? const Color(
                      0xFF17422F,
                    )
                  : const Color(
                      0xFFDCE7E0,
                    ),
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    const Color(
                  0xFFD9F2E2,
                ),
                foregroundImage:
                    photoUrl != null &&
                            photoUrl.isNotEmpty
                        ? NetworkImage(
                            photoUrl,
                          )
                        : null,
                child:
                    photoUrl == null ||
                            photoUrl.isEmpty
                        ? const Icon(
                            CupertinoIcons
                                .person_fill,
                            size: 15,
                            color: _green,
                          )
                        : null,
              ),

              const SizedBox(width: 5),

              ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 45,
                ),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                    color: isDark
                        ? Colors.white
                        : const Color(
                            0xFF21352A,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSurface
    extends StatelessWidget {
  const _SheetSurface({
    required this.isDark,
    required this.child,
  });

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark
          ? _darkCard
          : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius:
            const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF17432F)
              : const Color(0xFFDCE7E0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            10,
            18,
            14,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color: isDark
                        ? Colors.white
                            .withValues(
                            alpha: 0.18,
                          )
                        : Colors.black
                            .withValues(
                            alpha: 0.14,
                          ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      100,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetDivider
    extends StatelessWidget {
  const _SheetDivider({
    required this.isDark,
  });

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark
          ? Colors.white.withValues(
              alpha: 0.08,
            )
          : Colors.black.withValues(
              alpha: 0.07,
            ),
    );
  }
}

class _AccountSheet
    extends StatelessWidget {
  const _AccountSheet({
    required this.user,
    required this.themeController,
    required this.onOpenProfile,
    required this.onOpenAppearance,
    required this.onOpenSettings,
  });

  final User? user;
  final ThemeController
      themeController;

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenAppearance;
  final VoidCallback onOpenSettings;

  String _maskEmail(String email) {
    final clean =
        email.trim().toLowerCase();

    if (clean.isEmpty ||
        !clean.contains('@')) {
      return 'Correo protegido';
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

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final displayName =
        user?.displayName?.trim();

    final name = displayName != null &&
            displayName.isNotEmpty
        ? displayName
        : 'Jugador';

    final emailValue =
        user?.email?.trim();

    final email = emailValue != null &&
            emailValue.isNotEmpty
        ? _maskEmail(emailValue)
        : 'Sin correo registrado';

    final photoUrl =
        user?.photoURL?.trim();

    final primary = isDark
        ? Colors.white
        : const Color(0xFF0A3323);

    final secondary = isDark
        ? const Color(0xFFA6BAAF)
        : const Color(0xFF607067);

    final placeholder = Container(
      width: 54,
      height: 54,
      color: isDark
          ? _darkCardSoft
          : const Color(0xFFD9F2E2),
      child: const Icon(
        CupertinoIcons.person_fill,
        size: 26,
        color: _green,
      ),
    );

    return _SheetSurface(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(14),
                child: photoUrl != null &&
                        photoUrl
                            .isNotEmpty
                    ? Image.network(
                        photoUrl,
                        width: 54,
                        height: 54,
                        fit: BoxFit
                            .cover,
                        errorBuilder:
                            (
                          context,
                          error,
                          stackTrace,
                        ) =>
                                placeholder,
                      )
                    : placeholder,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight
                                .w800,
                        letterSpacing:
                            -0.3,
                        color: primary,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      email,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight
                                .w500,
                        color:
                            secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SheetDivider(isDark: isDark),

          _AccountMenuRow(
            leading: const Icon(
              CupertinoIcons
                  .person_crop_circle,
              size: 21,
              color: _green,
            ),
            label: 'Mi perfil',
            isDark: isDark,
            onTap: onOpenProfile,
          ),

          _AccountMenuRow(
            leading:
                const _AppearanceMenuIcon(),
            label: 'Apariencia',
            trailingText:
                themeController
                        .isDarkMode
                    ? 'Oscuro'
                    : 'Claro',
            isDark: isDark,
            onTap: onOpenAppearance,
          ),

          _AccountMenuRow(
            leading: const Icon(
              CupertinoIcons.gear,
              size: 21,
              color: _green,
            ),
            label: 'Configuración',
            isDark: isDark,
            onTap: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _AccountMenuRow
    extends StatelessWidget {
  const _AccountMenuRow({
    required this.leading,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.trailingText,
  });

  final Widget leading;
  final String label;
  final String? trailingText;

  final bool isDark;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? Colors.white
        : const Color(0xFF0A3323);

    final mutedColor = isDark
        ? const Color(0xFF82968B)
        : const Color(0xFF6C786F);

    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 15,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Center(
                child: leading,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight:
                      FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),

            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w500,
                  color: mutedColor,
                ),
              ),

              const SizedBox(width: 6),
            ],

            Icon(
              CupertinoIcons
                  .chevron_right,
              size: 15,
              color: mutedColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceMenuIcon
    extends StatelessWidget {
  const _AppearanceMenuIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 24,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 1,
            child: Icon(
              CupertinoIcons
                  .sun_max_fill,
              size: 16,
              color: _gold,
            ),
          ),

          Positioned(
            right: 0,
            bottom: 1,
            child: Icon(
              CupertinoIcons.moon_fill,
              size: 15,
              color: _green,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSheet
    extends StatefulWidget {
  const _AppearanceSheet({
    required this.themeController,
  });

  final ThemeController
      themeController;

  @override
  State<_AppearanceSheet>
      createState() =>
          _AppearanceSheetState();
}

class _AppearanceSheetState
    extends State<_AppearanceSheet> {
  void _select({
    required bool dark,
  }) {
    if (dark) {
      widget.themeController
          .setDarkMode();
    } else {
      widget.themeController
          .setLightMode();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final selectedDark =
        widget.themeController
            .isDarkMode;

    final primary = isDark
        ? Colors.white
        : const Color(0xFF0A3323);

    final secondary = isDark
        ? const Color(0xFFA6BAAF)
        : const Color(0xFF607067);

    return _SheetSurface(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Text(
            'Apariencia',
            style: TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -0.3,
              color: primary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Elige cómo quieres ver CanchaYA.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight:
                  FontWeight.w500,
              color: secondary,
            ),
          ),

          const SizedBox(height: 14),

          _SheetDivider(isDark: isDark),

          _AppearanceOption(
            icon:
                CupertinoIcons.sun_max,
            label: 'Claro',
            selected: !selectedDark,
            isDark: isDark,
            onTap: () =>
                _select(dark: false),
          ),

          _AppearanceOption(
            icon: CupertinoIcons.moon,
            label: 'Oscuro',
            selected: selectedDark,
            isDark: isDark,
            onTap: () =>
                _select(dark: true),
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
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  final bool selected;
  final bool isDark;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? Colors.white
        : const Color(0xFF0A3323);

    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 15,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: _green,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight:
                      FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),

            Icon(
              selected
                  ? CupertinoIcons
                      .largecircle_fill_circle
                  : CupertinoIcons
                      .circle,
              size: 22,
              color: selected
                  ? _green
                  : (isDark
                      ? const Color(
                          0xFF4F6459,
                        )
                      : const Color(
                          0xFFB3C0B8,
                        )),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CAMPANA DE NOTIFICACIONES + PANEL DESPLEGABLE
// ============================================================

class _NotificationBellButton
    extends StatefulWidget {
  const _NotificationBellButton({
    super.key,
    required this.isDark,
  });

  final bool isDark;

  @override
  State<_NotificationBellButton>
      createState() =>
          _NotificationBellButtonState();
}

class _NotificationBellButtonState
    extends State<_NotificationBellButton> {
  final LayerLink _layerLink =
      LayerLink();

  final GlobalKey _bellKey =
      GlobalKey();

  NotificationRepository? _repository;

  Stream<int>? _unreadStream;

  Stream<List<AppNotification>>?
      _notificationsStream;

  OverlayEntry? _overlayEntry;

  bool get _isOpen =>
      _overlayEntry != null;

  @override
  void initState() {
    super.initState();

    if (Firebase.apps.isNotEmpty &&
        FirebaseAuth.instance
                .currentUser !=
            null) {
      final repository =
          NotificationRepository();

      _repository = repository;
      _unreadStream =
          repository.watchUnreadCount();
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;

    super.dispose();
  }

  void _toggleNotifications() {
    if (_isOpen) {
      _closeNotifications();
    } else {
      _openNotifications();
    }
  }

  void _openNotifications() {
    final overlay = Overlay.maybeOf(
      context,
      rootOverlay: true,
    );

    if (overlay == null) return;

    _notificationsStream =
        _repository
            ?.watchCurrentUserNotifications(
      maxItems: 5,
    );

    final entry = OverlayEntry(
      builder: _buildOverlay,
    );

    _overlayEntry = entry;

    overlay.insert(entry);

    setState(() {});
  }

  void _closeNotifications() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    _notificationsStream = null;

    if (mounted) {
      setState(() {});
    }
  }

  void _openAllNotifications() {
    _closeNotifications();

    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const NotificationCenterScreen(),
      ),
    );
  }

  Future<void> _openNotification(
    AppNotification notification,
  ) async {
    final repository = _repository;
    final messenger =
        ScaffoldMessenger.maybeOf(
      context,
    );

    if (notification.unread &&
        repository != null) {
      try {
        await repository.markAsRead(
          notification.id,
        );
      } catch (_) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo marcar la notificación como leída.',
            ),
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }

    _closeNotifications();

    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const NotificationCenterScreen(),
      ),
    );
  }

  Widget _buildOverlay(
    BuildContext overlayContext,
  ) {
    final isDark =
        Theme.of(overlayContext)
                .brightness ==
            Brightness.dark;

    final screenSize =
        MediaQuery.sizeOf(
      overlayContext,
    );

    final screenWidth =
        screenSize.width;

    final panelWidth =
        screenWidth < 390
            ? screenWidth - 24
            : 360.0;

    final maxPanelHeight =
        screenSize.height * 0.65 < 440
            ? screenSize.height * 0.65
            : 440.0;

    var offsetX = 0.0;
    var offsetY = 49.0;

    final renderObject = _bellKey
        .currentContext
        ?.findRenderObject();

    if (renderObject is RenderBox &&
        renderObject.attached &&
        renderObject.hasSize) {
      final origin =
          renderObject.localToGlobal(
        Offset.zero,
      );

      final maxLeft =
          screenWidth - panelWidth - 12;

      final left = (origin.dx +
              renderObject.size.width -
              panelWidth)
          .clamp(
            12.0,
            maxLeft < 12.0
                ? 12.0
                : maxLeft,
          )
          .toDouble();

      offsetX = left - origin.dx;
      offsetY =
          renderObject.size.height + 10;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior:
                HitTestBehavior.opaque,
            onTap: _closeNotifications,
            child:
                const SizedBox.expand(),
          ),
        ),

        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor:
              Alignment.topLeft,
          followerAnchor:
              Alignment.topLeft,
          offset: Offset(
            offsetX,
            offsetY,
          ),
          child: SizedBox(
            width: panelWidth,
            child: _buildPanel(
              isDark: isDark,
              maxHeight: maxPanelHeight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel({
    required bool isDark,
    required double maxHeight,
  }) {
    final primary = isDark
        ? Colors.white
        : const Color(0xFF0A3323);

    return Material(
      color: isDark
          ? _darkCard
          : Colors.white,
      elevation: isDark ? 0 : 10,
      shadowColor: Colors.black
          .withValues(alpha: 0.22),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF17432F)
              : const Color(0xFFDCE7E0),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                16,
                8,
                8,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notificaciones',
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w800,
                        letterSpacing:
                            -0.2,
                        color: primary,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed:
                        _openAllNotifications,
                    style: TextButton
                        .styleFrom(
                      foregroundColor:
                          _green,
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize:
                          MainAxisSize
                              .min,
                      children: [
                        Text(
                          'Ver todas',
                          style:
                              TextStyle(
                            fontSize:
                                12.5,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),

                        SizedBox(
                          width: 3,
                        ),

                        Icon(
                          CupertinoIcons
                              .chevron_right,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _SheetDivider(
              isDark: isDark,
            ),

            Flexible(
              child: _buildContent(
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required bool isDark,
  }) {
    const errorText =
        'No se pudieron cargar las notificaciones.';

    final stream =
        _notificationsStream;

    if (stream == null) {
      return _PanelMessage(
        icon: CupertinoIcons
            .exclamationmark_circle,
        text: errorText,
        isDark: isDark,
      );
    }

    return StreamBuilder<
        List<AppNotification>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _PanelMessage(
            icon: CupertinoIcons
                .exclamationmark_circle,
            text: errorText,
            isDark: isDark,
          );
        }

        final items = snapshot.data;

        if (items == null) {
          return const Padding(
            padding:
                EdgeInsets.symmetric(
              vertical: 30,
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _green,
                ),
              ),
            ),
          );
        }

        if (items.isEmpty) {
          return _PanelMessage(
            icon:
                CupertinoIcons.bell,
            text:
                'No tienes notificaciones nuevas.',
            isDark: isDark,
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, _) =>
              _SheetDivider(
            isDark: isDark,
          ),
          itemBuilder: (_, index) {
            final notification =
                items[index];

            return _NotificationTile(
              notification:
                  notification,
              isDark: isDark,
              onTap: () =>
                  _openNotification(
                notification,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: KeyedSubtree(
        key: _bellKey,
        child: StreamBuilder<int>(
          stream: _unreadStream,
          initialData: 0,
          builder: (context, snapshot) {
            final unreadCount =
                snapshot.data ?? 0;

            return _HeaderButton(
              icon: CupertinoIcons.bell,
              isDark: widget.isDark,
              showBadge:
                  unreadCount > 0,
              onTap:
                  _toggleNotifications,
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile
    extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isDark,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread =
        notification.unread;

    final typeLabel = _text(
      notification.type.label,
    );

    final titleText = _text(
      notification.title,
    );

    final title = titleText.isNotEmpty
        ? titleText
        : typeLabel;

    final body = _text(
      notification.body,
    );

    final time = _relativeTime(
      notification.createdAt,
    );

    final meta = time.isEmpty
        ? typeLabel
        : '$typeLabel · $time';

    final typeName =
        notification.type.name;

    final accent = typeName ==
                'tournamentUpdate' ||
            typeName == 'resultPublished'
        ? _gold
        : _green;

    final primary = isDark
        ? Colors.white
        : const Color(0xFF0A3323);

    final secondary = isDark
        ? const Color(0xFFA6BAAF)
        : const Color(0xFF607067);

    final muted = isDark
        ? const Color(0xFF82968B)
        : const Color(0xFF6C786F);

    return Material(
      color: unread
          ? _green.withValues(
              alpha: isDark
                  ? 0.10
                  : 0.07,
            )
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            14,
            12,
            12,
            12,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(
                  color: accent
                      .withValues(
                    alpha: 0.14,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(12),
                ),
                child: Icon(
                  _notificationIcon(
                    typeName,
                  ),
                  size: 18,
                  color: accent,
                ),
              ),

              const SizedBox(width: 12),

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
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              fontSize:
                                  14,
                              fontWeight: unread
                                  ? FontWeight
                                      .w800
                                  : FontWeight
                                      .w600,
                              color:
                                  primary,
                            ),
                          ),
                        ),

                        if (unread) ...[
                          const SizedBox(
                            width: 8,
                          ),

                          Container(
                            width: 8,
                            height: 8,
                            decoration:
                                const BoxDecoration(
                              color:
                                  _green,
                              shape: BoxShape
                                  .circle,
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (body
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 2,
                      ),

                      Text(
                        body,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: unread
                              ? secondary
                              : muted,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      meta,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w600,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              Padding(
                padding:
                    const EdgeInsets
                        .only(top: 10),
                child: Icon(
                  CupertinoIcons
                      .chevron_right,
                  size: 14,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelMessage
    extends StatelessWidget {
  const _PanelMessage({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  final IconData icon;
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final muted = isDark
        ? const Color(0xFF82968B)
        : const Color(0xFF6C786F);

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 26,
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: muted,
          ),

          const SizedBox(height: 10),

          Text(
            text,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight:
                  FontWeight.w500,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

String _text(Object? value) {
  return value?.toString().trim() ??
      '';
}

IconData _notificationIcon(
  String typeName,
) {
  switch (typeName) {
    case 'teamInvitation':
      return CupertinoIcons
          .person_add_solid;
    case 'invitationAccepted':
      return CupertinoIcons
          .check_mark_circled_solid;
    case 'invitationRejected':
      return CupertinoIcons
          .xmark_circle_fill;
    case 'teamUpdate':
      return CupertinoIcons
          .person_2_fill;
    case 'matchCreated':
      return CupertinoIcons
          .sportscourt_fill;
    case 'matchUpdated':
      return CupertinoIcons
          .arrow_2_circlepath;
    case 'matchReminder':
      return CupertinoIcons.clock_fill;
    case 'tournamentUpdate':
      return CupertinoIcons.star_fill;
    case 'resultPublished':
      return CupertinoIcons.flag_fill;
    default:
      return CupertinoIcons.bell_fill;
  }
}

String _relativeTime(
  DateTime? createdAt,
) {
  if (createdAt == null) {
    return '';
  }

  final difference = DateTime.now()
      .difference(createdAt);

  if (difference.inMinutes < 1) {
    return 'Ahora';
  }

  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min';
  }

  if (difference.inHours < 24) {
    return '${difference.inHours} h';
  }

  if (difference.inDays == 1) {
    return 'Ayer';
  }

  if (difference.inDays < 7) {
    return '${difference.inDays} d';
  }

  final day = createdAt.day
      .toString()
      .padLeft(2, '0');

  final month = createdAt.month
      .toString()
      .padLeft(2, '0');

  return '$day/$month/${createdAt.year}';
}