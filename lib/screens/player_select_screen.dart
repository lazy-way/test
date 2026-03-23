import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';
import '../core/providers/player_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class PlayerSelectScreen extends ConsumerStatefulWidget {
  const PlayerSelectScreen({super.key});

  @override
  ConsumerState<PlayerSelectScreen> createState() => _PlayerSelectScreenState();
}

class _PlayerSelectScreenState extends ConsumerState<PlayerSelectScreen>
    with TickerProviderStateMixin {
  late AnimationController _enterController;
  late List<Animation<double>> _slotAnimations;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slotAnimations = List.generate(4, (i) {
      final start = i * 0.15;
      final end = start + 0.4;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _enterController,
          curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.elasticOut),
        ),
      );
    });
    _enterController.forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(playerProvider);
    final activeIds = players.map((p) => p.id).toSet();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.homeGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Back button and title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                    ),
                    Expanded(
                      child: Text(
                        'SELECT PLAYERS',
                        textAlign: TextAlign.center,
                        style: AppTheme.titleStyle.copyWith(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap to add or remove players',
                style: AppTheme.bodyStyle.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              // Player slots
              AnimatedBuilder(
                animation: _enterController,
                builder: (context, child) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (i) {
                        final isActive = activeIds.contains(i);
                        return Transform.scale(
                          scale: _slotAnimations[i].value,
                          child: GestureDetector(
                            onTap: () {
                              ref.read(playerProvider.notifier).togglePlayer(i);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              width: 75,
                              height: 75,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? AppTheme.playerColors[i]
                                    : Colors.white.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: isActive
                                      ? AppTheme.playerColors[i]
                                      : Colors.white.withValues(alpha: 0.3),
                                  width: 3,
                                ),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.playerColors[i].withValues(alpha: 0.4),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: isActive
                                    ? Text(
                                        'P${i + 1}',
                                        style: GoogleFonts.fredoka(fontWeight: FontWeight.w700,
                                          fontSize: 24,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        Icons.add_rounded,
                                        color: Colors.white.withValues(alpha: 0.4),
                                        size: 32,
                                      ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              // Player count text
              Text(
                '${players.length} Player${players.length > 1 ? 's' : ''} Selected',
                style: AppTheme.headingStyle.copyWith(fontSize: 20),
              ),
              const Spacer(),
              // Continue button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(playerProvider.notifier).resetScores();
                      context.push('/games');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4757),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFFFF4757).withValues(alpha: 0.4),
                    ),
                    child: Text('CONTINUE', style: AppTheme.buttonStyle),
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
