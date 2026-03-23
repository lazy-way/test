import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_result.dart';
import '../../app/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class GameWrapper extends StatefulWidget {
  final String gameName;
  final List<Player> players;
  final Widget Function(VoidCallback onGameEnd) gameBuilder;

  const GameWrapper({
    super.key,
    required this.gameName,
    required this.players,
    required this.gameBuilder,
  });

  @override
  State<GameWrapper> createState() => _GameWrapperState();
}

class _GameWrapperState extends State<GameWrapper> with TickerProviderStateMixin {
  bool _showCountdown = true;
  bool _showResult = false;
  int _countdownValue = 3;
  GameResult? _result;
  late AnimationController _countdownAnimController;
  late Animation<double> _countdownScale;

  @override
  void initState() {
    super.initState();
    _countdownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _countdownScale = Tween<double>(begin: 2.0, end: 1.0).animate(
      CurvedAnimation(parent: _countdownAnimController, curve: Curves.elasticOut),
    );
    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      _countdownAnimController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 800));
    }
    if (!mounted) return;
    setState(() {
      _countdownValue = 0; // "GO!"
    });
    _countdownAnimController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _showCountdown = false);
  }

  void _onGameEnd() {
    if (mounted) {
      setState(() => _showResult = true);
    }
  }

  @override
  void dispose() {
    _countdownAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Game
          widget.gameBuilder(_onGameEnd),
          // Countdown overlay
          if (_showCountdown)
            Container(
              color: Colors.black87,
              child: Center(
                child: AnimatedBuilder(
                  animation: _countdownAnimController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _countdownScale.value,
                      child: Text(
                        _countdownValue > 0 ? '$_countdownValue' : 'GO!',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.w700,
                          fontSize: 96,
                          color: _countdownValue > 0
                              ? AppTheme.playerColors[3 - _countdownValue]
                              : const Color(0xFF2ED573),
                          shadows: [
                            Shadow(
                              color: (_countdownValue > 0
                                      ? AppTheme.playerColors[3 - _countdownValue]
                                      : const Color(0xFF2ED573))
                                  .withValues(alpha: 0.6),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          // Pause button
          if (!_showCountdown && !_showResult)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                onPressed: () => _showPauseDialog(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pause_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          // Result overlay
          if (_showResult)
            _ResultOverlay(
              players: widget.players,
              onPlayAgain: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => GameWrapper(
                      gameName: widget.gameName,
                      players: widget.players,
                      gameBuilder: widget.gameBuilder,
                    ),
                  ),
                );
              },
              onExit: () {
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  void _showPauseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('PAUSED', style: AppTheme.titleStyle.copyWith(fontSize: 24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('RESUME', style: AppTheme.buttonStyle.copyWith(color: const Color(0xFF2ED573))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text('QUIT', style: AppTheme.buttonStyle.copyWith(color: const Color(0xFFFF4757))),
          ),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  const _ResultOverlay({
    required this.players,
    required this.onPlayAgain,
    required this.onExit,
  });

  @override
  State<_ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<_ResultOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.3)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sort players by score
    final sorted = List<Player>.from(widget.players)
      ..sort((a, b) => b.score.compareTo(a.score));
    final winner = sorted.first;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Container(
            color: Colors.black87,
            child: Center(
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Trophy
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 80,
                      color: winner.color,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${winner.name} Wins!',
                      style: GoogleFonts.fredoka(fontWeight: FontWeight.w700,
                        fontSize: 36,
                        color: winner.color,
                        shadows: [
                          Shadow(
                            color: winner.color.withValues(alpha: 0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Rankings
                    ...sorted.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final player = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$rank ',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: player.color,
                              ),
                              child: Center(
                                child: Text(
                                  '${player.id + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${player.score} pts',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 40),
                    // Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: widget.onPlayAgain,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ED573),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text('PLAY AGAIN', style: AppTheme.buttonStyle),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: widget.onExit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4757),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text('EXIT', style: AppTheme.buttonStyle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
