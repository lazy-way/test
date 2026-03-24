import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class TankBattleGame extends FlameGame with MultiTouchTapDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  late List<_Tank> tanks;
  final List<_Bullet> bullets = [];
  final List<_Wall> walls = [];
  bool _gameOver = false;

  TankBattleGame({required this.players, required this.onGameEnd});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Tank Battle',
      players: players,
      gameBuilder: (onEnd) => GameWidget(
        game: TankBattleGame(players: players, onGameEnd: onEnd),
        backgroundBuilder: (context) => Container(color: const Color(0xFF1a2a1a)),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Create walls
    _createWalls();

    // Create tanks at corners
    final positions = [
      Vector2(60, size.y - 60),
      Vector2(size.x - 60, 60),
      Vector2(60, 60),
      Vector2(size.x - 60, size.y - 60),
    ];

    tanks = List.generate(players.length, (i) {
      final tank = _Tank(
        position: positions[i],
        color: players[i].color,
        playerId: i,
        lives: 3,
      );
      add(tank);
      return tank;
    });

    // Lives display
    add(_LivesDisplay(tanks: tanks, screenSize: size, players: players));
  }

  void _createWalls() {
    final rng = Random(42);
    // Border walls
    final borderThickness = 4.0;
    walls.add(_Wall(Rect.fromLTWH(0, 0, size.x, borderThickness)));
    walls.add(_Wall(Rect.fromLTWH(0, size.y - borderThickness, size.x, borderThickness)));
    walls.add(_Wall(Rect.fromLTWH(0, 0, borderThickness, size.y)));
    walls.add(_Wall(Rect.fromLTWH(size.x - borderThickness, 0, borderThickness, size.y)));

    // Internal walls
    for (int i = 0; i < 6; i++) {
      final w = 20.0 + rng.nextDouble() * 60;
      final h = 20.0 + rng.nextDouble() * 60;
      final x = 80 + rng.nextDouble() * (size.x - 160);
      final y = 80 + rng.nextDouble() * (size.y - 160);
      walls.add(_Wall(Rect.fromLTWH(x, y, w, h)));
    }

    for (final wall in walls) {
      add(wall);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    // Update bullets
    for (final bullet in List.from(bullets)) {
      bullet.position += bullet.velocity * dt;
      bullet.lifetime -= dt;

      // Wall bounce
      for (final wall in walls) {
        if (wall.rect.contains(Offset(bullet.position.x, bullet.position.y))) {
          bullet.bounces++;
          if (bullet.bounces > 1) {
            bullet.lifetime = 0;
          } else {
            // Simple bounce
            bullet.velocity = -bullet.velocity;
            bullet.position += bullet.velocity * dt * 2;
          }
        }
      }

      // Hit tank
      for (final tank in tanks) {
        if (!tank.alive) continue;
        if (tank.playerId == bullet.ownerId && bullet.lifetime > 1.5) continue;
        final dist = tank.position.distanceTo(bullet.position);
        if (dist < 20) {
          tank.lives--;
          bullet.lifetime = 0;
          if (tank.lives <= 0) {
            tank.alive = false;
            _checkWin();
          }
        }
      }

      if (bullet.lifetime <= 0) {
        bullets.remove(bullet);
        remove(bullet);
      }
    }
  }

  void _checkWin() {
    final alive = tanks.where((t) => t.alive).toList();
    if (alive.length <= 1) {
      _gameOver = true;
      for (int i = 0; i < players.length; i++) {
        players[i].score = tanks[i].alive ? 1 : 0;
      }
      onGameEnd();
    }
  }

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;

    // Find nearest alive tank to determine which player tapped
    int? nearestPlayer;
    double nearestDist = double.infinity;

    for (int i = 0; i < tanks.length; i++) {
      if (!tanks[i].alive) continue;
      // Each player taps in their zone (simplified: use screen quadrants for multi-player)
      final zone = _getPlayerZone(i);
      if (zone.contains(Offset(pos.x, pos.y))) {
        nearestPlayer = i;
        break;
      }
    }

    if (nearestPlayer != null) {
      final tank = tanks[nearestPlayer];
      if (!tank.alive) return;

      // Aim toward tap position
      final dir = (pos - tank.position).normalized();
      tank.angle = atan2(dir.y, dir.x);

      // Shoot
      if (tank.canShoot) {
        final bullet = _Bullet(
          position: tank.position + dir * 20,
          velocity: dir * 400,
          ownerId: nearestPlayer,
          color: tank.color,
        );
        bullets.add(bullet);
        add(bullet);
        tank.lastShotTime = 0;
      }
    }
  }

  Rect _getPlayerZone(int index) {
    switch (players.length) {
      case 1: return Rect.fromLTWH(0, 0, size.x, size.y);
      case 2:
        if (index == 0) return Rect.fromLTWH(0, size.y / 2, size.x, size.y / 2);
        return Rect.fromLTWH(0, 0, size.x, size.y / 2);
      default: return Rect.fromLTWH(0, 0, size.x, size.y);
    }
  }
}

class _Tank extends PositionComponent {
  final Color color;
  final int playerId;
  int lives;
  bool alive = true;
  double lastShotTime = 0.5;
  bool get canShoot => lastShotTime >= 0.5;

  _Tank({
    required Vector2 position,
    required this.color,
    required this.playerId,
    required this.lives,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    lastShotTime += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!alive) return;

    canvas.save();
    canvas.rotate(angle);

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -12, 30, 24),
        const Radius.circular(4),
      ),
      Paint()..color = color,
    );

    // Turret
    canvas.drawRect(
      const Rect.fromLTWH(5, -3, 18, 6),
      Paint()..color = color.withValues(alpha: 0.8),
    );

    // Glow
    canvas.drawCircle(
      Offset.zero,
      18,
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.restore();
  }
}

class _Bullet extends PositionComponent {
  Vector2 velocity;
  final int ownerId;
  final Color color;
  double lifetime = 2.0;
  int bounces = 0;

  _Bullet({
    required Vector2 position,
    required this.velocity,
    required this.ownerId,
    required this.color,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 4, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero, 4,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}

class _Wall extends PositionComponent {
  final Rect rect;

  _Wall(this.rect) : super(
    position: Vector2(rect.left, rect.top),
    size: Vector2(rect.width, rect.height),
  );

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(3)),
      Paint()..color = const Color(0xFF3a4a3a),
    );
  }
}

class _LivesDisplay extends PositionComponent {
  final List<_Tank> tanks;
  final Vector2 screenSize;
  final List<Player> players;

  _LivesDisplay({required this.tanks, required this.screenSize, required this.players});

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < tanks.length; i++) {
      final x = 16.0 + i * 80;
      final y = screenSize.y - 30.0;
      final text = TextPainter(
        text: TextSpan(
          text: 'P${i + 1}: ${'♥' * tanks[i].lives}',
          style: TextStyle(color: players[i].color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      text.layout();
      text.paint(canvas, Offset(x, y));
    }
  }
}
