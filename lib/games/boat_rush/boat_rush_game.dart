import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class BoatRushGame extends FlameGame with MultiTouchTapDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  late List<_Boat> boats;
  final List<_Obstacle> obstacles = [];
  double _spawnTimer = 0;
  double _scrollSpeed = 200;
  double _gameTime = 0;
  bool _gameOver = false;
  final Random _rng = Random();

  BoatRushGame({required this.players, required this.onGameEnd});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Boat Rush',
      players: players,
      gameBuilder: (onEnd) => GameWidget(
        game: BoatRushGame(players: players, onGameEnd: onEnd),
        backgroundBuilder: (context) => Container(color: const Color(0xFF0a2040)),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final laneWidth = size.x / players.length;
    boats = List.generate(players.length, (i) {
      return _Boat(
        position: Vector2(laneWidth * i + laneWidth / 2, size.y * 0.8),
        color: players[i].color,
        playerId: i,
        laneWidth: laneWidth,
        laneX: laneWidth * i,
      );
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    _gameTime += dt;
    _scrollSpeed = 200 + _gameTime * 3; // Speed up over time

    // Spawn obstacles
    _spawnTimer += dt;
    if (_spawnTimer > 0.6) {
      _spawnTimer = 0;
      final lane = _rng.nextInt(players.length);
      final laneWidth = size.x / players.length;
      obstacles.add(_Obstacle(
        position: Vector2(lane * laneWidth + laneWidth * 0.2 + _rng.nextDouble() * laneWidth * 0.6, -30),
        width: 30 + _rng.nextDouble() * 20,
        height: 15 + _rng.nextDouble() * 10,
      ));
    }

    // Update obstacles
    for (final obs in List.from(obstacles)) {
      obs.position.y += _scrollSpeed * dt;
      if (obs.position.y > size.y + 50) {
        obstacles.remove(obs);
      }

      // Collision with boats
      for (final boat in boats) {
        if (!boat.alive) continue;
        if ((boat.position.x - obs.position.x).abs() < (obs.width / 2 + 12) &&
            (boat.position.y - obs.position.y).abs() < (obs.height / 2 + 15)) {
          boat.alive = false;
          _checkWin();
        }
      }
    }
  }

  void _checkWin() {
    final alive = boats.where((b) => b.alive).toList();
    if (alive.length <= 1) {
      _gameOver = true;
      for (int i = 0; i < players.length; i++) {
        players[i].score = boats[i].alive ? 1 : 0;
      }
      onGameEnd();
    }
  }

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;

    for (int i = 0; i < boats.length; i++) {
      if (!boats[i].alive) continue;
      final laneWidth = size.x / players.length;
      final laneLeft = laneWidth * i;
      if (pos.x >= laneLeft && pos.x < laneLeft + laneWidth) {
        // Move left or right within lane
        if (pos.x < laneLeft + laneWidth / 2) {
          boats[i].position.x = max(laneLeft + 15, boats[i].position.x - 25);
        } else {
          boats[i].position.x = min(laneLeft + laneWidth - 15, boats[i].position.x + 25);
        }
        break;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Water waves
    final wavePaint = Paint()..color = Colors.cyan.withValues(alpha: 0.05);
    for (double y = (_gameTime * 100) % 40; y < size.y; y += 40) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.x, 2), wavePaint);
    }

    // Lane dividers
    final divPaint = Paint()..color = Colors.white.withValues(alpha: 0.1)..strokeWidth = 1;
    final laneWidth = size.x / players.length;
    for (int i = 1; i < players.length; i++) {
      canvas.drawLine(Offset(laneWidth * i, 0), Offset(laneWidth * i, size.y), divPaint);
    }

    // Obstacles (logs)
    for (final obs in obstacles) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(obs.position.x, obs.position.y), width: obs.width, height: obs.height),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF8B4513),
      );
    }

    // Boats
    for (final boat in boats) {
      if (!boat.alive) continue;
      canvas.save();
      canvas.translate(boat.position.x, boat.position.y);

      // Boat body
      final path = Path()
        ..moveTo(0, -18)
        ..lineTo(12, 12)
        ..lineTo(-12, 12)
        ..close();
      canvas.drawPath(path, Paint()..color = boat.color);

      // Glow
      canvas.drawCircle(
        Offset.zero, 15,
        Paint()
          ..color = boat.color.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      canvas.restore();
    }

    // Survival time
    final timeText = TextPainter(
      text: TextSpan(
        text: '${_gameTime.toStringAsFixed(1)}s',
        style: const TextStyle(color: Colors.white54, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    timeText.layout();
    timeText.paint(canvas, Offset(size.x / 2 - timeText.width / 2, 10));
  }
}

class _Boat {
  Vector2 position;
  Color color;
  int playerId;
  double laneWidth;
  double laneX;
  bool alive = true;

  _Boat({
    required this.position,
    required this.color,
    required this.playerId,
    required this.laneWidth,
    required this.laneX,
  });
}

class _Obstacle {
  Vector2 position;
  double width;
  double height;

  _Obstacle({required this.position, required this.width, required this.height});
}
