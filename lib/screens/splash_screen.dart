import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _numberController;
  late AnimationController _titleController;
  late List<Animation<double>> _numberScales;
  late List<Animation<double>> _numberOpacities;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleOpacity;

  @override
  void initState() {
    super.initState();
    _numberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _numberScales = List.generate(4, (i) {
      final start = i * 0.2;
      final end = start + 0.3;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _numberController,
          curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.elasticOut),
        ),
      );
    });

    _numberOpacities = List.generate(4, (i) {
      final start = i * 0.2;
      final end = start + 0.15;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _numberController,
          curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeIn),
        ),
      );
    });

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.elasticOut,
    ));

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _numberController.forward();
    await Future.delayed(const Duration(milliseconds: 1200));
    _titleController.forward();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.splashGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _numberController,
                builder: (context, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      return Opacity(
                        opacity: _numberOpacities[i].value,
                        child: Transform.scale(
                          scale: _numberScales[i].value,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.fredoka(fontWeight: FontWeight.w700,
                                fontSize: 64,
                                color: AppTheme.playerColors[i],
                                shadows: [
                                  Shadow(
                                    color: AppTheme.playerColors[i].withValues(alpha: 0.6),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleOpacity,
                  child: Text(
                    'MINI GAMES',
                    style: GoogleFonts.fredoka(fontWeight: FontWeight.w700,
                      fontSize: 36,
                      color: Colors.white,
                      letterSpacing: 4,
                      shadows: [
                        const Shadow(
                          color: Color(0x80FFFFFF),
                          blurRadius: 20,
                        ),
                      ],
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
