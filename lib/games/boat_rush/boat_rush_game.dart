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

    final halfH = size.y / 2;
    boats = List.generate(players.length, (i) {
      final zoneTop = i == 0 ? halfH : 0.0;
      final isTop = i == 1;
      return _Boat(
        position: Vector2(size.x / 2, isTop ? zoneTop + halfH * 0.2 : zoneTop + halfH * 0.8),
        color: players[i].color,
        playerId: i,
        laneWidth: size.x,
        laneX: 0,
        isTop: isTop,
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
      final halfH = size.y / 2;
      final halfIdx = _rng.nextInt(players.length); // 0 = bottom half, 1 = top half
      final isTopZone = halfIdx == 1;
      final spawnY = isTopZone
          ? halfH + 30  // Top zone: spawn from bottom of zone (center of screen), move up
          : halfH - 30; // Bottom zone: spawn from top of zone (center of screen), move down
      obstacles.add(_Obstacle(
        position: Vector2(20 + _rng.nextDouble() * (size.x - 40), spawnY),
        width: 30 + _rng.nextDouble() * 20,
        height: 15 + _rng.nextDouble() * 10,
        movesUp: isTopZone,
      ));
    }

    // Update obstacles
    for (final obs in List.from(obstacles)) {
      if (obs.movesUp) {
        obs.position.y -= _scrollSpeed * dt;
      } else {
        obs.position.y += _scrollSpeed * dt;
      }
      if (obs.position.y > size.y + 50 || obs.position.y < -50) {
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

    // Bottom half = player 0, top half = player 1
    int playerIdx;
    if (pos.y > size.y / 2) {
      playerIdx = 0;
    } else {
      playerIdx = players.length > 1 ? 1 : 0;
    }

    if (playerIdx < boats.length && boats[playerIdx].alive) {
      // Move left or right based on tap position
      if (pos.x < size.x / 2) {
        boats[playerIdx].position.x = max(15, boats[playerIdx].position.x - 25);
      } else {
        boats[playerIdx].position.x = min(size.x - 15, boats[playerIdx].position.x + 25);
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

    // Half divider (horizontal line at y/2)
    final divPaint = Paint()..color = Colors.white.withValues(alpha: 0.1)..strokeWidth = 1;
    if (players.length > 1) {
      canvas.drawLine(Offset(0, size.y / 2), Offset(size.x, size.y / 2), divPaint);
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

      // Rotate 180° for top player so boat faces down
      if (boat.isTop) {
        canvas.rotate(pi);
      }

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
  bool isTop;

  _Boat({
    required this.position,
    required this.color,
    required this.playerId,
    required this.laneWidth,
    required this.laneX,
    this.isTop = false,
  });
}

class _Obstacle {
  Vector2 position;
  double width;
  double height;
  bool movesUp;

  _Obstacle({required this.position, required this.width, required this.height, this.movesUp = false});
}
