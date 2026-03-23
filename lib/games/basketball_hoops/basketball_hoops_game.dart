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

class _BasketballAreaState extends State<_BasketballArea> with TickerProviderStateMixin {
  late List<int> scores;
  late List<_BallState?> balls;
  double _timeLeft = 45;
  Timer? _gameTimer;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    scores = List.filled(widget.players.length, 0);
    balls = List.filled(widget.players.length, null);

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_gameOver) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _endGame();
      });
    });

    // Animate balls
    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_gameOver) { timer.cancel(); return; }
      setState(() {
        for (int i = 0; i < balls.length; i++) {
          final ball = balls[i];
          if (ball == null || !ball.launched) continue;
          ball.x += ball.vx * 0.016;
          ball.y += ball.vy * 0.016;
          ball.vy += 500 * 0.016; // gravity

          // Check score (ball reaches hoop area)
          if (ball.y < ball.hoopY + 10 && ball.y > ball.hoopY - 10 &&
              (ball.x - ball.hoopX).abs() < 25) {
            scores[i]++;
            balls[i] = null;
          }

          // Ball off screen
          if (ball.y > ball.startY + 50 && ball.vy > 0) {
            balls[i] = null;
          }
        }
      });
    });
  }

  void _endGame() {
    _gameOver = true;
    _gameTimer?.cancel();
    for (int i = 0; i < widget.players.length; i++) {
      widget.players[i].score = scores[i];
    }
    widget.onGameEnd();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1a0a0a),
      child: SafeArea(
        child: Column(
          children: [
            // Timer and scores
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_timeLeft.ceil()}s',
                    style: TextStyle(
                      color: _timeLeft < 10 ? Colors.red : Colors.white70,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 20),
                  ...List.generate(widget.players.length, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.players[i].color),
                        ),
                        const SizedBox(width: 4),
                        Text('${scores[i]}', style: TextStyle(color: widget.players[i].color, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            // Play area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final playerCount = widget.players.length;
                  if (playerCount <= 2) {
                    return Row(
                      children: List.generate(playerCount, (i) => Expanded(
                        child: _PlayerCourt(
                          playerIndex: i,
                          playerColor: widget.players[i].color,
                          ball: balls[i],
                          score: scores[i],
                          onSwipe: (dx, dy) => _shoot(i, dx, dy, constraints.maxWidth / playerCount, constraints.maxHeight),
                        ),
                      )),
                    );
                  } else {
                    return Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: List.generate(min(2, playerCount), (i) => Expanded(
                              child: _PlayerCourt(
                                playerIndex: i,
                                playerColor: widget.players[i].color,
                                ball: balls[i],
                                score: scores[i],
                                onSwipe: (dx, dy) => _shoot(i, dx, dy, constraints.maxWidth / 2, constraints.maxHeight / 2),
                              ),
                            )),
                          ),
                        ),
                        if (playerCount > 2)
                          Expanded(
                            child: Row(
                              children: List.generate(playerCount - 2, (i) => Expanded(
                                child: _PlayerCourt(
                                  playerIndex: i + 2,
                                  playerColor: widget.players[i + 2].color,
                                  ball: balls[i + 2],
                                  score: scores[i + 2],
                                  onSwipe: (dx, dy) => _shoot(i + 2, dx, dy, constraints.maxWidth / 2, constraints.maxHeight / 2),
                                ),
                              )),
                            ),
                          ),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shoot(int playerIndex, double dx, double dy, double courtW, double courtH) {
    if (_gameOver || balls[playerIndex] != null) return;

    setState(() {
      balls[playerIndex] = _BallState(
        x: courtW / 2,
        y: courtH * 0.8,
        vx: dx * 2,
        vy: dy * 2,
        hoopX: courtW / 2,
        hoopY: courtH * 0.15,
        startY: courtH * 0.8,
        launched: true,
      );
    });
  }
}

class _BallState {
  double x, y, vx, vy;
  double hoopX, hoopY, startY;
  bool launched;

  _BallState({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.hoopX, required this.hoopY,
    required this.startY, required this.launched,
  });
}

class _PlayerCourt extends StatefulWidget {
  final int playerIndex;
  final Color playerColor;
  final _BallState? ball;
  final int score;
  final void Function(double dx, double dy) onSwipe;

  const _PlayerCourt({
    required this.playerIndex,
    required this.playerColor,
    required this.ball,
    required this.score,
    required this.onSwipe,
  });

  @override
  State<_PlayerCourt> createState() => _PlayerCourtState();
}

class _PlayerCourtState extends State<_PlayerCourt> {
  Offset? _dragStart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _dragStart = d.localPosition,
      onPanEnd: (d) {
        if (_dragStart != null) {
          final velocity = d.velocity.pixelsPerSecond;
          widget.onSwipe(velocity.dx * 0.15, velocity.dy * 0.15);
          _dragStart = null;
        }
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: widget.playerColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: _CourtPainter(
            playerColor: widget.playerColor,
            ball: widget.ball,
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

  _CourtPainter({required this.playerColor, required this.ball});

  @override
  void paint(Canvas canvas, Size size) {
    // Hoop
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
    } else {
      // Show ball at starting position
      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.8),
        12,
        Paint()..color = Colors.orange.withValues(alpha: 0.5),
      );
      // Swipe hint
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Swipe up!',
          style: TextStyle(color: playerColor.withValues(alpha: 0.4), fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height * 0.9));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
