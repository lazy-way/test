import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class BasketballHoopsGame extends StatelessWidget {
  final List<Player> players;
  const BasketballHoopsGame({super.key, required this.players});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Basketball Hoops',
      players: players,
      gameBuilder: (onEnd) => _BasketballArea(players: players, onGameEnd: onEnd),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget(players: players);
  }
}

class _BasketballArea extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onGameEnd;
  const _BasketballArea({required this.players, required this.onGameEnd});

  @override
  State<_BasketballArea> createState() => _BasketballAreaState();
}

class _BasketballAreaState extends State<_BasketballArea> {
  late List<int> scores;
  _BallState? activeBall;
  int currentPlayer = 0;
  int totalShots = 0;
  final int maxShots = 10; // 5 shots per player in 2-player, 10 in 1-player
  bool _gameOver = false;
  Timer? _animTimer;

  @override
  void initState() {
    super.initState();
    scores = List.filled(widget.players.length, 0);

    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_gameOver) { timer.cancel(); return; }
      if (activeBall == null) return;

      setState(() {
        final ball = activeBall!;
        ball.x += ball.vx * 0.016;
        ball.y += ball.vy * 0.016;
        ball.vy += 500 * 0.016; // gravity

        // Check score
        if (ball.y < ball.hoopY + 10 && ball.y > ball.hoopY - 10 &&
            (ball.x - ball.hoopX).abs() < 25) {
          scores[currentPlayer]++;
          _onShotComplete();
          return;
        }

        // Ball missed (fell back down)
        if (ball.y > ball.startY + 50 && ball.vy > 0) {
          _onShotComplete();
        }
      });
    });
  }

  void _onShotComplete() {
    activeBall = null;
    totalShots++;

    final shotsPerPlayer = widget.players.length > 1 ? maxShots ~/ 2 : maxShots;
    final totalMaxShots = widget.players.length > 1 ? maxShots : shotsPerPlayer;

    if (totalShots >= totalMaxShots) {
      _endGame();
      return;
    }

    // Switch turns in 2-player mode
    if (widget.players.length > 1) {
      setState(() {
        currentPlayer = (currentPlayer + 1) % widget.players.length;
      });
    }
  }

  void _shoot(double dx, double dy, double courtW, double courtH) {
    if (_gameOver || activeBall != null) return;

    setState(() {
      activeBall = _BallState(
        x: courtW / 2,
        y: courtH * 0.8,
        vx: dx * 2,
        vy: dy * 2,
        hoopX: courtW / 2,
        hoopY: courtH * 0.15,
        startY: courtH * 0.8,
      );
    });
  }

  void _endGame() {
    _gameOver = true;
    _animTimer?.cancel();
    for (int i = 0; i < widget.players.length; i++) {
      widget.players[i].score = scores[i];
    }
    widget.onGameEnd();
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  int get _shotsRemaining {
    final total = widget.players.length > 1 ? maxShots : maxShots;
    return total - totalShots;
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = widget.players[currentPlayer].color;

    return Container(
      color: const Color(0xFF1a0a0a),
      child: SafeArea(
        child: Column(
          children: [
            // Header: scores + turn indicator
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Shots remaining
                  Text(
                    '$_shotsRemaining left',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  // Scores
                  ...List.generate(widget.players.length, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: i == currentPlayer
                            ? widget.players[i].color.withValues(alpha: 0.3)
                            : Colors.transparent,
                        border: i == currentPlayer
                            ? Border.all(color: widget.players[i].color, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.players[i].color),
                            child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                          ),
                          const SizedBox(width: 4),
                          Text('${scores[i]}', style: TextStyle(color: widget.players[i].color, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
            // Play area — P2 (rotated) at top, P1 at bottom
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final playerCount = widget.players.length;
                  if (playerCount == 1) {
                    // Single player — full court
                    return _PlayerCourt(
                      playerIndex: 0,
                      playerColor: widget.players[0].color,
                      ball: currentPlayer == 0 ? activeBall : null,
                      isActive: currentPlayer == 0,
                      onSwipe: (dx, dy) => _shoot(dx, dy, constraints.maxWidth, constraints.maxHeight),
                    );
                  }
                  // 2 players: P2 at top (rotated), P1 at bottom
                  return Column(
                    children: [
                      // Top: Player 2 (index 1), rotated 180°
                      Expanded(
                        child: Transform.rotate(
                          angle: pi,
                          child: _PlayerCourt(
                            playerIndex: 1,
                            playerColor: widget.players[1].color,
                            ball: currentPlayer == 1 ? activeBall : null,
                            isActive: currentPlayer == 1,
                            onSwipe: (dx, dy) => _shoot(dx, dy, constraints.maxWidth, constraints.maxHeight / 2),
                          ),
                        ),
                      ),
                      // Turn indicator divider
                      Container(
                        height: 32,
                        color: currentColor.withValues(alpha: 0.15),
                        child: Center(
                          child: Text(
                            'P${currentPlayer + 1}\'s Turn',
                            style: TextStyle(
                              color: currentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      // Bottom: Player 1 (index 0), normal orientation
                      Expanded(
                        child: _PlayerCourt(
                          playerIndex: 0,
                          playerColor: widget.players[0].color,
                          ball: currentPlayer == 0 ? activeBall : null,
                          isActive: currentPlayer == 0,
                          onSwipe: (dx, dy) => _shoot(dx, dy, constraints.maxWidth, constraints.maxHeight / 2),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BallState {
  double x, y, vx, vy;
  double hoopX, hoopY, startY;

  _BallState({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.hoopX, required this.hoopY,
    required this.startY,
  });
}

class _PlayerCourt extends StatefulWidget {
  final int playerIndex;
  final Color playerColor;
  final _BallState? ball;
  final bool isActive;
  final void Function(double dx, double dy) onSwipe;

  const _PlayerCourt({
    required this.playerIndex,
    required this.playerColor,
    required this.ball,
    required this.isActive,
    required this.onSwipe,
  });

  @override
  State<_PlayerCourt> createState() => _PlayerCourtState();
}

class _PlayerCourtState extends State<_PlayerCourt> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanEnd: widget.isActive ? (d) {
        final velocity = d.velocity.pixelsPerSecond;
        widget.onSwipe(velocity.dx * 0.15, velocity.dy * 0.15);
      } : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.isActive
                ? widget.playerColor.withValues(alpha: 0.5)
                : widget.playerColor.withValues(alpha: 0.15),
            width: widget.isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: _CourtPainter(
            playerColor: widget.playerColor,
            ball: widget.ball,
            isActive: widget.isActive,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CourtPainter extends CustomPainter {
  final Color playerColor;
  final _BallState? ball;
  final bool isActive;

  _CourtPainter({required this.playerColor, required this.ball, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final hoopX = size.width / 2;
    final hoopY = size.height * 0.15;

    // Backboard
    canvas.drawRect(
      Rect.fromCenter(center: Offset(hoopX, hoopY - 15), width: 40, height: 3),
      Paint()..color = Colors.white54,
    );
    // Rim
    canvas.drawCircle(
      Offset(hoopX, hoopY),
      15,
      Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Net lines
    canvas.drawLine(
      Offset(hoopX - 15, hoopY),
      Offset(hoopX - 10, hoopY + 20),
      Paint()..color = Colors.white24..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(hoopX + 15, hoopY),
      Offset(hoopX + 10, hoopY + 20),
      Paint()..color = Colors.white24..strokeWidth = 1,
    );

    // Ball
    if (ball != null) {
      canvas.drawCircle(
        Offset(ball!.x, ball!.y),
        12,
        Paint()..color = Colors.orange,
      );
      canvas.drawCircle(
        Offset(ball!.x, ball!.y),
        12,
        Paint()
          ..color = Colors.orange.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    } else if (isActive) {
      // Show ball at starting position only for active player
      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.8),
        12,
        Paint()..color = Colors.orange.withValues(alpha: 0.7),
      );
      // Swipe hint
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Swipe up to shoot!',
          style: TextStyle(color: playerColor.withValues(alpha: 0.5), fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height * 0.9));
    } else {
      // Inactive — show waiting text
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Wait for your turn...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
