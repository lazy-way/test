import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class PingPongGame extends FlameGame with PanDetector, HasCollisionDetection {
  final List<Player> players;
  final VoidCallback onGameEnd;

  late List<_Paddle> paddles;
  late _Ball ball;
  late List<int> scores;
  final int winScore = 5;
  bool _gameOver = false;

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

    final paddleWidth = 12.0;
    final paddleHeight = size.y * 0.2;

    paddles = [];

    if (players.length >= 2) {
      // Player 1 - left
      paddles.add(_Paddle(
        position: Vector2(30, size.y / 2 - paddleHeight / 2),
        size: Vector2(paddleWidth, paddleHeight),
        color: players[0].color,
        isVertical: true,
        minPos: 0,
        maxPos: size.y - paddleHeight,
      ));
      // Player 2 - right
      paddles.add(_Paddle(
        position: Vector2(size.x - 30 - paddleWidth, size.y / 2 - paddleHeight / 2),
        size: Vector2(paddleWidth, paddleHeight),
        color: players[1].color,
        isVertical: true,
        minPos: 0,
        maxPos: size.y - paddleHeight,
      ));
    } else {
      // 1 player: player on left, AI on right
      paddles.add(_Paddle(
        position: Vector2(30, size.y / 2 - paddleHeight / 2),
        size: Vector2(paddleWidth, paddleHeight),
        color: players[0].color,
        isVertical: true,
        minPos: 0,
        maxPos: size.y - paddleHeight,
      ));
      paddles.add(_Paddle(
        position: Vector2(size.x - 30 - paddleWidth, size.y / 2 - paddleHeight / 2),
        size: Vector2(paddleWidth, paddleHeight),
        color: Colors.grey,
        isVertical: true,
        isAI: true,
        minPos: 0,
        maxPos: size.y - paddleHeight,
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
      position: Vector2(size.x * 0.25, 40),
      scoreGetter: () => scores.isNotEmpty ? scores[0] : 0,
      color: players[0].color,
    ));
    if (players.length >= 2) {
      add(_ScoreDisplay(
        position: Vector2(size.x * 0.75, 40),
        scoreGetter: () => scores.length > 1 ? scores[1] : 0,
        color: players[1].color,
      ));
    }

    _resetBall();
  }

  void _resetBall() {
    ball.position = Vector2(size.x / 2, size.y / 2);
    final angle = (Random().nextDouble() - 0.5) * 0.8;
    final dir = Random().nextBool() ? 1.0 : -1.0;
    ball.velocity = Vector2(dir * 300 * cos(angle), 300 * sin(angle));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    // AI paddle
    for (final p in paddles) {
      if (p.isAI) {
        final target = ball.position.y - p.size.y / 2;
        final diff = target - p.position.y;
        p.position.y += diff.clamp(-250 * dt, 250 * dt);
        p.position.y = p.position.y.clamp(p.minPos, p.maxPos);
      }
    }

    // Ball movement
    ball.position += ball.velocity * dt;

    // Top/bottom bounce
    if (ball.position.y <= 0 || ball.position.y >= size.y - ball.radius * 2) {
      ball.velocity.y = -ball.velocity.y;
      ball.position.y = ball.position.y.clamp(0, size.y - ball.radius * 2);
    }

    // Paddle collision
    for (int i = 0; i < paddles.length; i++) {
      final paddle = paddles[i];
      if (ball.toRect().overlaps(paddle.toRect())) {
        ball.velocity.x = -ball.velocity.x;
        // Speed up
        ball.velocity *= 1.05;
        // Offset based on where ball hits paddle
        final hitPos = (ball.position.y - paddle.position.y) / paddle.size.y;
        ball.velocity.y += (hitPos - 0.5) * 200;
        // Push ball out of paddle
        if (i == 0) {
          ball.position.x = paddle.position.x + paddle.size.x + 1;
        } else {
          ball.position.x = paddle.position.x - ball.radius * 2 - 1;
        }
      }
    }

    // Scoring
    if (ball.position.x < 0) {
      // Right player scores
      if (scores.length > 1) scores[1]++;
      _checkWin();
      _resetBall();
    } else if (ball.position.x > size.x) {
      // Left player scores
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
  void onPanUpdate(DragUpdateInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;

    // Determine which paddle to move based on touch x position
    if (pos.x < size.x / 2 && paddles.isNotEmpty && !paddles[0].isAI) {
      paddles[0].position.y += info.delta.global.y;
      paddles[0].position.y = paddles[0].position.y.clamp(
        paddles[0].minPos, paddles[0].maxPos,
      );
    } else if (pos.x >= size.x / 2 && paddles.length > 1 && !paddles[1].isAI) {
      paddles[1].position.y += info.delta.global.y;
      paddles[1].position.y = paddles[1].position.y.clamp(
        paddles[1].minPos, paddles[1].maxPos,
      );
    }
  }
}

class _Paddle extends PositionComponent {
  final Color color;
  final bool isVertical;
  final bool isAI;
  final double minPos;
  final double maxPos;

  _Paddle({
    required Vector2 position,
    required Vector2 size,
    required this.color,
    required this.isVertical,
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
    // Glow
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

    for (double y = 0; y < screenSize.y; y += 20) {
      canvas.drawLine(
        Offset(screenSize.x / 2, y),
        Offset(screenSize.x / 2, y + 10),
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
