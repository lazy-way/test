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
  late AnimationController _titleController;
  late Animation<double> _titleScale;
  late Animation<double> _titleOpacity;

  @override
  void initState() {
    super.initState();
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _titleScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.elasticOut),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _titleController.forward();
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.splashGradient),
        child: Center(
          child: AnimatedBuilder(
            animation: _titleController,
            builder: (context, child) {
              return Opacity(
                opacity: _titleOpacity.value,
                child: Transform.scale(
                  scale: _titleScale.value,
                  child: Text(
                    'MINI GAMES',
                    style: GoogleFonts.fredoka(
                      fontWeight: FontWeight.w700,
                      fontSize: 48,
                      color: Colors.white,
                      letterSpacing: 4,
                      shadows: [
                        const Shadow(
                          color: Color(0x80FFFFFF),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
