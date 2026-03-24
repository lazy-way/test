import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class PingPongGame extends FlameGame with MultiTouchDragDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  late List<_Paddle> paddles;
  late _Ball ball;
  late List<int> scores;
  final int winScore = 5;
  bool _gameOver = false;
  final Map<int, int> _dragToPlayer = {};

  PingPongGame({required this.players, required this.onGameEnd});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Ping Pong',
      players: players,
      gameBuilder: (onEnd) => GameWidget(
        game: PingPongGame(players: players, onGameEnd: onEnd),
        backgroundBuilder: (context) => Container(color: const Color(0xFF0a0a2e)),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    scores = List.filled(players.length, 0);

    final paddleWidth = size.x * 0.25;
    final paddleHeight = 12.0;

    paddles = [];

    // Player 1 - bottom (horizontal paddle)
    paddles.add(_Paddle(
      position: Vector2(size.x / 2 - paddleWidth / 2, size.y - 40),
      size: Vector2(paddleWidth, paddleHeight),
      color: players[0].color,
      isHorizontal: true,
      minPos: 0,
      maxPos: size.x - paddleWidth,
    ));

    if (players.length >= 2) {
      // Player 2 - top (horizontal paddle)
      paddles.add(_Paddle(
        position: Vector2(size.x / 2 - paddleWidth / 2, 28),
        size: Vector2(paddleWidth, paddleHeight),
        color: players[1].color,
        isHorizontal: true,
        minPos: 0,
        maxPos: size.x - paddleWidth,
      ));
    } else {
      // AI - top
      paddles.add(_Paddle(
        position: Vector2(size.x / 2 - paddleWidth / 2, 28),
        size: Vector2(paddleWidth, paddleHeight),
        color: Colors.grey,
        isHorizontal: true,
        isAI: true,
        minPos: 0,
        maxPos: size.x - paddleWidth,
      ));
    }

    for (final p in paddles) {
      add(p);
    }

    ball = _Ball(screenSize: size);
    add(ball);

    // Center line
    add(_CenterLine(screenSize: size));

    // Score displays
    add(_ScoreDisplay(
      position: Vector2(size.x - 50, size.y * 0.75),
      scoreGetter: () => scores.isNotEmpty ? scores[0] : 0,
      color: players[0].color,
    ));
    add(_ScoreDisplay(
      position: Vector2(size.x - 50, size.y * 0.25 - 30),
      scoreGetter: () => scores.length > 1 ? scores[1] : 0,
      color: players.length > 1 ? players[1].color : Colors.grey,
    ));

    _resetBall();
  }

  void _resetBall() {
    ball.position = Vector2(size.x / 2, size.y / 2);
    final angle = (Random().nextDouble() - 0.5) * 0.8;
    final dir = Random().nextBool() ? 1.0 : -1.0;
    ball.velocity = Vector2(300 * sin(angle), dir * 300 * cos(angle));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    // AI paddle
    for (final p in paddles) {
      if (p.isAI) {
        final target = ball.position.x - p.size.x / 2;
        final diff = target - p.position.x;
        p.position.x += diff.clamp(-250 * dt, 250 * dt);
        p.position.x = p.position.x.clamp(p.minPos, p.maxPos);
      }
    }

    // Ball movement
    ball.position += ball.velocity * dt;

    // Left/right wall bounce
    if (ball.position.x <= 0 || ball.position.x >= size.x - ball.radius * 2) {
      ball.velocity.x = -ball.velocity.x;
      ball.position.x = ball.position.x.clamp(0, size.x - ball.radius * 2);
    }

    // Paddle collision
    for (int i = 0; i < paddles.length; i++) {
      final paddle = paddles[i];
      if (ball.toRect().overlaps(paddle.toRect())) {
        ball.velocity.y = -ball.velocity.y;
        // Speed up
        ball.velocity *= 1.05;
        // Offset based on where ball hits paddle
        final hitPos = (ball.position.x - paddle.position.x) / paddle.size.x;
        ball.velocity.x += (hitPos - 0.5) * 200;
        // Push ball out of paddle
        if (i == 0) {
          // Bottom paddle - push ball up
          ball.position.y = paddle.position.y - ball.radius * 2 - 1;
        } else {
          // Top paddle - push ball down
          ball.position.y = paddle.position.y + paddle.size.y + 1;
        }
      }
    }

    // Scoring
    if (ball.position.y > size.y) {
      // Top player (player 2) scores
      if (scores.length > 1) scores[1]++;
      _checkWin();
      _resetBall();
    } else if (ball.position.y < 0) {
      // Bottom player (player 1) scores
      scores[0]++;
      _checkWin();
      _resetBall();
    }
  }

  void _checkWin() {
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] >= winScore) {
        _gameOver = true;
        for (int j = 0; j < players.length; j++) {
          players[j].score = scores[j];
        }
        onGameEnd();
        return;
      }
    }
  }

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;

    // Bottom half = player 0, top half = player 1
    if (pos.y > size.y / 2 && !paddles[0].isAI) {
      _dragToPlayer[pointerId] = 0;
    } else if (pos.y <= size.y / 2 && paddles.length > 1 && !paddles[1].isAI) {
      _dragToPlayer[pointerId] = 1;
    }
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    if (_gameOver) return;
    final playerIdx = _dragToPlayer[pointerId];
    if (playerIdx == null) return;

    paddles[playerIdx].position.x += info.delta.global.x;
    paddles[playerIdx].position.x = paddles[playerIdx].position.x.clamp(
      paddles[playerIdx].minPos, paddles[playerIdx].maxPos,
    );
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    _dragToPlayer.remove(pointerId);
  }
}

class _Paddle extends PositionComponent {
  final Color color;
  final bool isHorizontal;
  final bool isAI;
  final double minPos;
  final double maxPos;

  _Paddle({
    required Vector2 position,
    required Vector2 size,
    required this.color,
    required this.isHorizontal,
    this.isAI = false,
    required this.minPos,
    required this.maxPos,
  }) : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(6)),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(6)),
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  Rect toRect() => Rect.fromLTWH(position.x, position.y, size.x, size.y);
}

class _Ball extends PositionComponent {
  final double radius = 8;
  Vector2 velocity = Vector2.zero();
  final Vector2 screenSize;

  _Ball({required this.screenSize}) : super(size: Vector2.all(16));

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset(radius, radius),
      radius,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(radius, radius),
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  Rect toRect() => Rect.fromLTWH(position.x, position.y, radius * 2, radius * 2);
}

class _CenterLine extends PositionComponent {
  final Vector2 screenSize;
  _CenterLine({required this.screenSize});

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (double x = 0; x < screenSize.x; x += 20) {
      canvas.drawLine(
        Offset(x, screenSize.y / 2),
        Offset(x + 10, screenSize.y / 2),
        paint,
      );
    }
  }
}

class _ScoreDisplay extends PositionComponent {
  final int Function() scoreGetter;
  final Color color;

  _ScoreDisplay({
    required Vector2 position,
    required this.scoreGetter,
    required this.color,
  }) : super(position: position);

  @override
  void render(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${scoreGetter()}',
        style: TextStyle(
          color: color.withValues(alpha: 0.5),
          fontSize: 64,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
  }
}
