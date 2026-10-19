import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/theme_controller.dart';
import '../../profile/presentation/profile_screen.dart';

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

        _ThemeToggle(
          isDark: isDark,
          onTap:
              themeController.toggleTheme,
        ),

        const SizedBox(width: 7),

        _HeaderButton(
          icon: CupertinoIcons.bell,
          isDark: isDark,
          showBadge: true,
          onTap: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  'Aquí aparecerán tus notificaciones.',
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 7),

        _ProfileButton(
          user: user,
          name: name,
          isDark: isDark,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const ProfileScreen(),
              ),
            );
          },
        ),
      ],
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

  Widget _buildNearbyCourts(
    BuildContext context, {
    required bool isDark,
  }) {
    return Column(
      children: [
        _SectionTitle(
          icon:
              CupertinoIcons.location_fill,
          title: 'Canchas cercanas',
          action: 'Ver mapa',
          isDark: isDark,
          onTap: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  'Aquí conectaremos Google Maps más adelante.',
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 13),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(22),
          child: SizedBox(
            height: 210,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/home/map_preview.jpg',
                  fit: BoxFit.cover,
                ),

                DecoratedBox(
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment
                              .bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black
                            .withValues(
                          alpha: 0.25,
                        ),
                      ],
                    ),
                  ),
                ),

                const Positioned(
                  left: 25,
                  top: 27,
                  child: _MapPin(
                    label:
                        'Unidad Deportiva',
                  ),
                ),

                const Positioned(
                  right: 42,
                  top: 55,
                  child: _MapPin(
                    label: 'Cancha',
                  ),
                ),

                Positioned(
                  left: 118,
                  bottom: 64,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration:
                        BoxDecoration(
                      color: const Color(
                        0xFF318AFF,
                      ),
                      shape:
                          BoxShape.circle,
                      border:
                          Border.all(
                        color:
                            Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(
                            0xFF318AFF,
                          ).withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 13,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 11,
                  child: Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration:
                        BoxDecoration(
                      color: isDark
                          ? const Color(
                              0xE6071912,
                            )
                          : const Color(
                              0xEEFFFFFF,
                            ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons
                              .location_fill,
                          color: _green,
                          size: 16,
                        ),

                        const SizedBox(
                          width: 7,
                        ),

                        const Expanded(
                          child: Text(
                            'Explorar canchas en Montemorelos',
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w800,
                              fontSize:
                                  12,
                            ),
                          ),
                        ),

                        const Icon(
                          CupertinoIcons
                              .chevron_right,
                          color: _green,
                          size: 15,
                        ),
                      ],
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

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width: 31,
          height: 31,
          decoration:
              BoxDecoration(
            color: _green,
            shape:
                BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.25,
                ),
                blurRadius: 6,
                offset:
                    const Offset(
                  0,
                  3,
                ),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons
                .sportscourt_fill,
            size: 14,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 2),

        Container(
          constraints:
              const BoxConstraints(
            maxWidth: 95,
          ),
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 6,
            vertical: 3,
          ),
          decoration:
              BoxDecoration(
            color: const Color(
              0xEFFFFFFF,
            ),
            borderRadius:
                BorderRadius.circular(
              6,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              color: Color(
                0xFF23362B,
              ),
              fontSize: 8,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeToggle
    extends StatelessWidget {
  const _ThemeToggle({
    required this.isDark,
    required this.onTap,
  });

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(100),
        onTap: onTap,
        child: Container(
          width: 64,
          height: 38,
          padding:
              const EdgeInsets.all(4),
          decoration:
              BoxDecoration(
            color: isDark
                ? const Color(
                    0xFF0A2419,
                  )
                : const Color(
                    0xFFEAF5EE,
                  ),
            borderRadius:
                BorderRadius.circular(
              100,
            ),
            border: Border.all(
              color: isDark
                  ? const Color(
                      0xFF1A4934,
                    )
                  : const Color(
                      0xFFD6E9DD,
                    ),
            ),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration:
                    const Duration(
                  milliseconds: 220,
                ),
                curve:
                    Curves.easeOutCubic,
                alignment: isDark
                    ? Alignment
                        .centerRight
                    : Alignment
                        .centerLeft,
                child: Container(
                  width: 27,
                  height: 27,
                  decoration:
                      BoxDecoration(
                    color: isDark
                        ? const Color(
                            0xFF173D2C,
                          )
                        : Colors.white,
                    shape:
                        BoxShape.circle,
                  ),
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Icon(
                        CupertinoIcons
                            .sun_max_fill,
                        size: 14,
                        color: isDark
                            ? const Color(
                                0xFF657A6F,
                              )
                            : const Color(
                                0xFFE2A919,
                              ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: Icon(
                        CupertinoIcons
                            .moon_fill,
                        size: 14,
                        color: isDark
                            ? _greenLight
                            : const Color(
                                0xFF7A8A81,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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