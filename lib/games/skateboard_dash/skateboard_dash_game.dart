import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class SkateboardDashGame extends FlameGame with MultiTouchTapDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  late List<_Skater> skaters;
  final List<_DashObstacle> obstacles = [];
  double _spawnTimer = 0;
  double _speed = 250;
  double _distance = 0;
  bool _gameOver = false;
  final Random _rng = Random();

  SkateboardDashGame({required this.players, required this.onGameEnd});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Skateboard Dash',
      players: players,
      gameBuilder: (onEnd) => GameWidget(
        game: SkateboardDashGame(players: players, onGameEnd: onEnd),
        backgroundBuilder: (context) => Container(color: const Color(0xFF1a1a2e)),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final stripHeight = size.y / players.length;
    skaters = List.generate(players.length, (i) {
      return _Skater(
        position: Vector2(60, stripHeight * i + stripHeight * 0.7),
        color: players[i].color,
        playerId: i,
        groundY: stripHeight * i + stripHeight * 0.7,
        stripTop: stripHeight * i,
        stripHeight: stripHeight,
      );
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    _distance += _speed * dt;
    _speed += dt * 5; // Accelerate

    // Spawn obstacles
    _spawnTimer += dt;
    if (_spawnTimer > 0.8) {
      _spawnTimer = 0;
      final stripHeight = size.y / players.length;
      for (int i = 0; i < players.length; i++) {
        if (_rng.nextDouble() < 0.5) {
          obstacles.add(_DashObstacle(
            position: Vector2(size.x + 20, stripHeight * i + stripHeight * 0.7 - 10),
            width: 15 + _rng.nextDouble() * 15,
            height: 10 + _rng.nextDouble() * 20,
            lane: i,
          ));
        }
      }
    }

    // Update obstacles
    for (final obs in List.from(obstacles)) {
      obs.position.x -= _speed * dt;
      if (obs.position.x < -50) obstacles.remove(obs);
    }

    // Update skaters
    for (final skater in skaters) {
      if (!skater.alive) continue;

      // Gravity
      if (skater.position.y < skater.groundY) {
        skater.velocityY += 800 * dt;
        skater.position.y += skater.velocityY * dt;
        if (skater.position.y >= skater.groundY) {
          skater.position.y = skater.groundY;
          skater.velocityY = 0;
          skater.isJumping = false;
        }
      }

      // Collision
      for (final obs in obstacles) {
        if (obs.lane != skater.playerId) continue;
        if ((skater.position.x + 10 > obs.position.x) &&
            (skater.position.x - 10 < obs.position.x + obs.width) &&
            (skater.position.y + 5 > obs.position.y) &&
            (skater.position.y - 15 < obs.position.y + obs.height)) {
          skater.alive = false;
          skater.distance = _distance;
          _checkWin();
          break;
        }
      }
    }
  }

  void _checkWin() {
    final alive = skaters.where((s) => s.alive).toList();
    if (alive.length <= 1) {
      _gameOver = true;
      for (final s in skaters) {
        if (s.alive) s.distance = _distance;
      }
      for (int i = 0; i < players.length; i++) {
        players[i].score = (skaters[i].distance / 100).round();
      }
      onGameEnd();
    }
  }

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;
    final stripHeight = size.y / players.length;

    for (int i = 0; i < skaters.length; i++) {
      if (!skaters[i].alive) continue;
      if (pos.y >= stripHeight * i && pos.y < stripHeight * (i + 1)) {
        if (!skaters[i].isJumping) {
          skaters[i].velocityY = -350;
          skaters[i].isJumping = true;
        }
        break;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final stripHeight = size.y / players.length;

    for (int i = 0; i < players.length; i++) {
      final top = stripHeight * i;
      final isTopPlayer = i == 1 && players.length > 1;

      // For top player, rotate the entire strip 180° around its center
      if (isTopPlayer) {
        canvas.save();
        canvas.translate(size.x / 2, top + stripHeight / 2);
        canvas.rotate(pi);
        canvas.translate(-size.x / 2, -(top + stripHeight / 2));
      }

      // Strip background
      if (i % 2 == 1) {
        canvas.drawRect(
          Rect.fromLTWH(0, top, size.x, stripHeight),
          Paint()..color = Colors.white.withValues(alpha: 0.03),
        );
      }

      // Ground line
      canvas.drawLine(
        Offset(0, top + stripHeight * 0.7 + 5),
        Offset(size.x, top + stripHeight * 0.7 + 5),
        Paint()..color = Colors.white.withValues(alpha: 0.2)..strokeWidth = 2,
      );

      // Moving ground dots
      for (double x = -(_distance % 30); x < size.x; x += 30) {
        canvas.drawCircle(
          Offset(x, top + stripHeight * 0.7 + 8),
          1.5,
          Paint()..color = Colors.white.withValues(alpha: 0.1),
        );
      }

      // Obstacles for this strip
      for (final obs in obstacles) {
        if (obs.lane != i) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(obs.position.x, obs.position.y, obs.width, obs.height),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xFFFF6B6B),
        );
      }

      // Skater for this strip
      final skater = skaters[i];
      if (skater.alive) {
        canvas.save();
        canvas.translate(skater.position.x, skater.position.y);

        // Body
        canvas.drawCircle(const Offset(0, -10), 8, Paint()..color = skater.color);
        // Board
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-10, 0, 20, 5),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.white70,
        );
        // Wheels
        canvas.drawCircle(const Offset(-6, 5), 2.5, Paint()..color = Colors.grey);
        canvas.drawCircle(const Offset(6, 5), 2.5, Paint()..color = Colors.grey);

        canvas.restore();
      }

      if (isTopPlayer) {
        canvas.restore();
      }
    }

    // Distance
    final distText = TextPainter(
      text: TextSpan(
        text: '${(_distance / 100).toStringAsFixed(0)}m',
        style: const TextStyle(color: Colors.white54, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    distText.layout();
    distText.paint(canvas, Offset(size.x - distText.width - 10, 10));
  }
}

class _Skater {
  Vector2 position;
  Color color;
  int playerId;
  double groundY;
  double stripTop;
  double stripHeight;
  double velocityY = 0;
  bool isJumping = false;
  bool alive = true;
  double distance = 0;

  _Skater({
    required this.position,
    required this.color,
    required this.playerId,
    required this.groundY,
    required this.stripTop,
    required this.stripHeight,
  });
}

class _DashObstacle {
  Vector2 position;
  double width;
  double height;
  int lane;

  _DashObstacle({required this.position, required this.width, required this.height, required this.lane});
}
