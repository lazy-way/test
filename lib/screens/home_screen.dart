import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(decoration: const BoxDecoration(gradient: AppTheme.homeGradient)),
          // Floating shapes
          ...List.generate(8, (i) => _FloatingShape(
            controller: _floatController,
            index: i,
          )),
          // Content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Title numbers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.w700,
                          fontSize: 56,
                          color: AppTheme.playerColors[i],
                          shadows: [
                            Shadow(
                              color: AppTheme.playerColors[i].withValues(alpha: 0.5),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MINI GAMES',
                    style: GoogleFonts.fredoka(fontWeight: FontWeight.w700,
                      fontSize: 28,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Play with friends on the same device!',
                    style: AppTheme.bodyStyle.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Play button
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: GestureDetector(
                      onTap: () => context.push('/players'),
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF4757)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4757).withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'PLAY',
                            style: GoogleFonts.fredoka(fontWeight: FontWeight.w700,
                              fontSize: 32,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Settings button
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_rounded, color: Colors.white54, size: 32),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingShape extends StatelessWidget {
  final AnimationController controller;
  final int index;

  const _FloatingShape({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    final random = Random(index * 42);
    final size = 20.0 + random.nextDouble() * 60;
    final startX = random.nextDouble();
    final startY = random.nextDouble();
    final speed = 0.3 + random.nextDouble() * 0.7;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final screenSize = MediaQuery.of(context).size;
        final progress = (controller.value * speed + index * 0.1) % 1.0;
        final x = startX * screenSize.width + sin(progress * 2 * pi) * 30;
        final y = startY * screenSize.height + cos(progress * 2 * pi) * 20;

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: 0.1 + random.nextDouble() * 0.1,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: index % 2 == 0 ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: index % 2 != 0 ? BorderRadius.circular(size * 0.2) : null,
                color: AppTheme.playerColors[index % 4],
              ),
            ),
          ),
        );
      },
    );
  }
}
