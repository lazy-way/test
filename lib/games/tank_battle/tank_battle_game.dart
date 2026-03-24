import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class TankBattleGame extends FlameGame with MultiTouchTapDetector, MultiTouchDragDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  late List<_Tank> tanks;
  final List<_Bullet> bullets = [];
  final List<_Wall> walls = [];
  bool _gameOver = false;
  final Map<int, int> _dragToPlayer = {};

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
    _createWalls();

    final positions = [
      Vector2(size.x / 2, size.y - 80),
      Vector2(size.x / 2, 80),
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

    add(_LivesDisplay(tanks: tanks, screenSize: size, players: players));
  }

  void _createWalls() {
    final rng = Random(42);
    final bt = 4.0;
    walls.add(_Wall(Rect.fromLTWH(0, 0, size.x, bt)));
    walls.add(_Wall(Rect.fromLTWH(0, size.y - bt, size.x, bt)));
    walls.add(_Wall(Rect.fromLTWH(0, 0, bt, size.y)));
    walls.add(_Wall(Rect.fromLTWH(size.x - bt, 0, bt, size.y)));

    for (int i = 0; i < 6; i++) {
      final w = 20.0 + rng.nextDouble() * 50;
      final h = 20.0 + rng.nextDouble() * 50;
      final x = 60 + rng.nextDouble() * (size.x - 120);
      final y = 60 + rng.nextDouble() * (size.y - 120);
      walls.add(_Wall(Rect.fromLTWH(x, y, w, h)));
    }

    for (final wall in walls) {
      add(wall);
    }
  }

  bool _collidesWithWall(Vector2 pos, double radius) {
    for (final wall in walls) {
      final closest = Offset(
        pos.x.clamp(wall.rect.left, wall.rect.right),
        pos.y.clamp(wall.rect.top, wall.rect.bottom),
      );
      final dist = (Vector2(closest.dx, closest.dy) - pos).length;
      if (dist < radius) return true;
    }
    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    for (final bullet in List.from(bullets)) {
      bullet.position += bullet.velocity * dt;
      bullet.lifetime -= dt;

      // Wall bounce
      bool hitWall = false;
      for (final wall in walls) {
        if (wall.rect.contains(Offset(bullet.position.x, bullet.position.y))) {
          bullet.bounces++;
          if (bullet.bounces > 2) {
            bullet.lifetime = 0;
          } else {
            // Determine bounce axis
            final bx = bullet.position.x;
            final by = bullet.position.y;
            final distL = (bx - wall.rect.left).abs();
            final distR = (bx - wall.rect.right).abs();
            final distT = (by - wall.rect.top).abs();
            final distB = (by - wall.rect.bottom).abs();
            final minDist = [distL, distR, distT, distB].reduce((a, b) => a < b ? a : b);
            if (minDist == distL || minDist == distR) {
              bullet.velocity.x = -bullet.velocity.x;
            } else {
              bullet.velocity.y = -bullet.velocity.y;
            }
            bullet.position += bullet.velocity * dt * 2;
          }
          hitWall = true;
          break;
        }
      }

      // Hit tank (skip owner for first 0.3s)
      if (!hitWall) {
        for (final tank in tanks) {
          if (!tank.alive) continue;
          if (tank.playerId == bullet.ownerId && bullet.lifetime > 2.7) continue;
          final dist = tank.position.distanceTo(bullet.position);
          if (dist < 18) {
            tank.lives--;
            bullet.lifetime = 0;
            if (tank.lives <= 0) {
              tank.alive = false;
              _checkWin();
            }
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

  // Drag = move tank
  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;
    for (int i = 0; i < tanks.length; i++) {
      if (!tanks[i].alive) continue;
      final zone = _getPlayerZone(i);
      if (zone.contains(Offset(pos.x, pos.y))) {
        _dragToPlayer[pointerId] = i;
        break;
      }
    }
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    if (_gameOver) return;
    final playerIdx = _dragToPlayer[pointerId];
    if (playerIdx == null) return;
    final tank = tanks[playerIdx];
    if (!tank.alive) return;

    final newPos = tank.position + info.delta.global;
    // Clamp to arena
    newPos.x = newPos.x.clamp(15, size.x - 15);
    newPos.y = newPos.y.clamp(15, size.y - 15);

    if (!_collidesWithWall(newPos, 14)) {
      // Update angle to face movement direction
      final delta = info.delta.global;
      if (delta.length > 1) {
        tank.angle = atan2(delta.y, delta.x);
      }
      tank.position = newPos;
    }
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    _dragToPlayer.remove(pointerId);
  }

  // Tap = shoot toward tap position
  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;

    for (int i = 0; i < tanks.length; i++) {
      if (!tanks[i].alive) continue;
      final zone = _getPlayerZone(i);
      if (zone.contains(Offset(pos.x, pos.y))) {
        final tank = tanks[i];
        final dir = (pos - tank.position).normalized();
        tank.angle = atan2(dir.y, dir.x);

        if (tank.canShoot) {
          final bullet = _Bullet(
            position: tank.position + dir * 22,
            velocity: dir * 450,
            ownerId: i,
            color: tank.color,
          );
          bullets.add(bullet);
          add(bullet);
          tank.lastShotTime = 0;
        }
        break;
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Zone divider
    canvas.drawLine(
      Offset(0, size.y / 2),
      Offset(size.x, size.y / 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 1,
    );

    // Drag hint text
    for (int i = 0; i < tanks.length; i++) {
      if (!tanks[i].alive) continue;
      final zone = _getPlayerZone(i);
      final tp = TextPainter(
        text: TextSpan(
          text: 'Drag to move • Tap to shoot',
          style: TextStyle(color: players[i].color.withValues(alpha: 0.2), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      if (i == 0) {
        tp.paint(canvas, Offset(zone.center.dx - tp.width / 2, zone.bottom - 16));
      } else {
        tp.paint(canvas, Offset(zone.center.dx - tp.width / 2, zone.top + 4));
      }
    }
  }
}

class _Tank extends PositionComponent {
  final Color color;
  final int playerId;
  int lives;
  bool alive = true;
  double lastShotTime = 0.5;
  bool get canShoot => lastShotTime >= 0.4;

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
  double lifetime = 3.0;
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
      final y = i == 0 ? screenSize.y - 30.0 : 10.0;
      final text = TextPainter(
        text: TextSpan(
          text: 'P${i + 1}: ${'♥' * tanks[i].lives}',
          style: TextStyle(color: players[i].color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      text.layout();
      text.paint(canvas, Offset(16, y));
    }
  }
}
