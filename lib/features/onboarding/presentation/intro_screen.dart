import 'package:flutter/material.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1100,
      ),
    );

    _scale = Tween<double>(
      begin: 1.04,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.45,
          curve: Curves.easeOut,
        ),
      ),
    );

    _controller.forward();

    Future.delayed(
        const Duration(
        milliseconds: 1850,
      ),
      () {
        if (mounted) {
          widget.onFinished();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF05271D,
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: _scale.value,
                child: Image.asset(
                  'assets/images/auth/login_background.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),

              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x18000000),
                      Color(0x25000000),
                      Color(0xAA031F17),
                    ],
                    stops: [
                      0.0,
                      0.55,
                      1.0,
                    ],
                  ),
                ),
              ),

              SafeArea(
                child: FadeTransition(
                  opacity: _opacity,
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 54,
                      ),

                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight:
                                FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                          children: [
                            TextSpan(
                              text: 'Cancha',
                              style: TextStyle(
                                color:
                                    Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: 'YA',
                              style: TextStyle(
                                color: Color(
                                  0xFF55E27D,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 9,
                      ),

                      Text(
                        'Tu fútbol en un solo lugar.',
                        style: TextStyle(
                          color: Colors.white
                              .withValues(
                            alpha: 0.86,
                          ),
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),

                      const Spacer(),

                      Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 36,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              padding:
                                  const EdgeInsets
                                      .all(7),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.white
                                        .withValues(
                                  alpha: 0.12,
                                ),
                                shape:
                                    BoxShape.circle,
                              ),
                              child:
                                  const CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Color(
                                  0xFF55E27D,
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            Text(
                              'Preparando tu cancha...',
                              style:
                                  TextStyle(
                                color: Colors
                                    .white
                                    .withValues(
                                  alpha: 0.75,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}