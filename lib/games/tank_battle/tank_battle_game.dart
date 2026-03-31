import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class TankBattleGame extends FlameGame with MultiTouchDragDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  late List<_Tank> tanks;
  final List<_Projectile> projectiles = [];
  bool _gameOver = false;

  // Turn-based
  int currentPlayer = 0;
  bool _waitingForProjectile = false;

  // Aiming state
  int? _aimingPointerId;
  Vector2? _aimStart;
  Vector2? _aimCurrent;
  double _aimAngle = 0;
  double _aimPower = 0;

  // Terrain
  late List<double> terrain;
  static const double gravity = 400;
  static const double maxPower = 600;

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

    // Generate terrain (simple hilly ground)
    final rng = Random(42);
    final segments = (size.x / 4).ceil();
    terrain = List.generate(segments + 1, (i) {
      final x = i / segments;
      // Base height + some hills
      return size.y * 0.65 +
          sin(x * pi * 2) * 30 +
          sin(x * pi * 5) * 15 +
          rng.nextDouble() * 10;
    });

    // Place tanks on terrain
    final p1x = size.x * 0.2;
    final p2x = size.x * 0.8;
    tanks = [
      _Tank(
        position: Vector2(p1x, _getTerrainY(p1x) - 12),
        color: players[0].color,
        playerId: 0,
        lives: 3,
        facingRight: true,
      ),
      if (players.length > 1)
        _Tank(
          position: Vector2(p2x, _getTerrainY(p2x) - 12),
          color: players[1].color,
          playerId: 1,
          lives: 3,
          facingRight: false,
        ),
    ];

    for (final t in tanks) {
      add(t);
    }
  }

  double _getTerrainY(double x) {
    final segments = terrain.length - 1;
    final idx = (x / size.x * segments).clamp(0, segments - 1);
    final i = idx.floor();
    final frac = idx - i;
    return terrain[i] * (1 - frac) + terrain[min(i + 1, segments)] * frac;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    // Update projectiles
    for (final proj in List.from(projectiles)) {
      proj.velocity.y += gravity * dt;
      proj.position += proj.velocity * dt;
      proj.trail.add(proj.position.clone());
      if (proj.trail.length > 50) proj.trail.removeAt(0);

      // Hit terrain
      final terrainY = _getTerrainY(proj.position.x);
      if (proj.position.y >= terrainY) {
        _onProjectileHit(proj);
        continue;
      }

      // Off screen
      if (proj.position.x < -50 || proj.position.x > size.x + 50 || proj.position.y > size.y + 50) {
        projectiles.remove(proj);
        remove(proj);
        _endTurn();
      }
    }
  }

  void _onProjectileHit(_Projectile proj) {
    // Check damage to tanks
    for (final tank in tanks) {
      if (!tank.alive) continue;
      final dist = tank.position.distanceTo(proj.position);
      if (dist < 40) {
        // Direct hit or splash
        final damage = dist < 20 ? 2 : 1;
        tank.lives -= damage;
        if (tank.lives <= 0) {
          tank.alive = false;
        }
      }
    }

    // Deform terrain (crater)
    final craterX = proj.position.x;
    final craterRadius = 25.0;
    final segments = terrain.length - 1;
    for (int i = 0; i <= segments; i++) {
      final tx = i / segments * size.x;
      final dist = (tx - craterX).abs();
      if (dist < craterRadius) {
        final depth = (1 - dist / craterRadius) * 12;
        terrain[i] += depth;
      }
    }

    projectiles.remove(proj);
    remove(proj);

    // Check win
    final alive = tanks.where((t) => t.alive).toList();
    if (alive.length <= 1) {
      _gameOver = true;
      for (int i = 0; i < players.length; i++) {
        players[i].score = tanks[i].alive ? 1 : 0;
      }
      onGameEnd();
      return;
    }

    _endTurn();
  }

  void _endTurn() {
    _waitingForProjectile = false;
    // Switch to next alive player
    do {
      currentPlayer = (currentPlayer + 1) % players.length;
    } while (!tanks[currentPlayer].alive && tanks.any((t) => t.alive));
  }

  void _fire() {
    if (_waitingForProjectile || _gameOver) return;
    final tank = tanks[currentPlayer];
    if (!tank.alive) return;

    final dir = Vector2(cos(_aimAngle), sin(_aimAngle));
    final proj = _Projectile(
      position: tank.position + dir * 25,
      velocity: dir * _aimPower,
      ownerId: currentPlayer,
      color: tank.color,
    );
    projectiles.add(proj);
    add(proj);
    _waitingForProjectile = true;

    // Update turret angle
    tank.turretAngle = _aimAngle;
  }

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    if (_gameOver || _waitingForProjectile) return;
    if (_aimingPointerId != null) return;

    final pos = info.eventPosition.global;
    final zone = _getPlayerZone(currentPlayer);
    if (zone.contains(Offset(pos.x, pos.y))) {
      _aimingPointerId = pointerId;
      _aimStart = pos.clone();
      _aimCurrent = pos.clone();
    }
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    if (pointerId != _aimingPointerId) return;
    _aimCurrent = info.eventPosition.global;

    final tank = tanks[currentPlayer];
    final dragVec = _aimStart! - _aimCurrent!;

    // Angle from tank to drag direction (pull back like slingshot)
    _aimAngle = atan2(dragVec.y, dragVec.x);
    // Power from drag distance
    _aimPower = (dragVec.length * 3).clamp(50, maxPower);

    tank.turretAngle = _aimAngle;
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    if (pointerId != _aimingPointerId) return;
    _aimingPointerId = null;

    if (_aimPower > 60) {
      _fire();
    }
    _aimStart = null;
    _aimCurrent = null;
    _aimPower = 0;
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

    // Sky gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0a1520), Color(0xFF1a3a2a)],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );

    // Terrain
    final terrainPath = Path();
    final segments = terrain.length - 1;
    terrainPath.moveTo(0, size.y);
    for (int i = 0; i <= segments; i++) {
      terrainPath.lineTo(i / segments * size.x, terrain[i]);
    }
    terrainPath.lineTo(size.x, size.y);
    terrainPath.close();

    canvas.drawPath(
      terrainPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2d5a27), Color(0xFF1a3a15)],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );

    // Terrain edge line
    final edgePath = Path();
    edgePath.moveTo(0, terrain[0]);
    for (int i = 1; i <= segments; i++) {
      edgePath.lineTo(i / segments * size.x, terrain[i]);
    }
    canvas.drawPath(
      edgePath,
      Paint()
        ..color = const Color(0xFF4a8a3a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Projectile trails
    for (final proj in projectiles) {
      if (proj.trail.length > 1) {
        final trailPath = Path();
        trailPath.moveTo(proj.trail.first.x, proj.trail.first.y);
        for (int i = 1; i < proj.trail.length; i++) {
          trailPath.lineTo(proj.trail[i].x, proj.trail[i].y);
        }
        canvas.drawPath(
          trailPath,
          Paint()
            ..color = proj.color.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Aim trajectory preview (dotted arc)
    if (_aimingPointerId != null && _aimPower > 60) {
      final tank = tanks[currentPlayer];
      final dir = Vector2(cos(_aimAngle), sin(_aimAngle));
      var px = tank.position.x + dir.x * 25;
      var py = tank.position.y + dir.y * 25;
      var vx = dir.x * _aimPower;
      var vy = dir.y * _aimPower;
      final dotPaint = Paint()
        ..color = tank.color.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;

      for (int step = 0; step < 30; step++) {
        vy += gravity * 0.03;
        px += vx * 0.03;
        py += vy * 0.03;
        if (py > _getTerrainY(px) || px < 0 || px > size.x) break;
        if (step % 2 == 0) {
          canvas.drawCircle(Offset(px, py), 2, dotPaint);
        }
      }

      // Power bar
      final zone = _getPlayerZone(currentPlayer);
      final barWidth = (_aimPower / maxPower) * 100;
      final barY = currentPlayer == 0 ? zone.bottom - 30 : zone.top + 10;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.x / 2 - 52, barY, 104, 14),
          const Radius.circular(7),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.1),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.x / 2 - 50, barY + 2, barWidth, 10),
          const Radius.circular(5),
        ),
        Paint()..color = tank.color.withValues(alpha: 0.7),
      );
    }

    // Turn indicator
    if (!_gameOver) {
      final turnColor = players[currentPlayer].color;
      final turnY = currentPlayer == 0 ? size.y - 50.0 : 30.0;
      final tp = TextPainter(
        text: TextSpan(
          text: _waitingForProjectile
              ? '...'
              : 'P${currentPlayer + 1} — Drag to aim & fire!',
          style: TextStyle(
            color: turnColor.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(size.x / 2 - tp.width / 2, turnY));
    }

    // Lives
    for (int i = 0; i < tanks.length; i++) {
      final y = i == 0 ? size.y - 16.0 : 8.0;
      final x = i == 0 ? 12.0 : size.x - 80.0;
      final tp = TextPainter(
        text: TextSpan(
          text: 'P${i + 1}: ${'♥' * max(0, tanks[i].lives)}',
          style: TextStyle(
            color: players[i].color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x, y));
    }

    // Zone divider
    canvas.drawLine(
      Offset(0, size.y / 2),
      Offset(size.x, size.y / 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..strokeWidth = 1,
    );
  }
}

class _Tank extends PositionComponent {
  final Color color;
  final int playerId;
  int lives;
  bool alive = true;
  bool facingRight;
  double turretAngle;

  _Tank({
    required Vector2 position,
    required this.color,
    required this.playerId,
    required this.lives,
    required this.facingRight,
  }) : turretAngle = facingRight ? -0.5 : pi + 0.5,
       super(position: position, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    if (!alive) return;

    // Tank body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-16, -6, 32, 14),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );

    // Tracks
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, 6, 36, 6),
        const Radius.circular(3),
      ),
      Paint()..color = color.withValues(alpha: 0.6),
    );

    // Turret dome
    canvas.drawCircle(
      const Offset(0, -4),
      8,
      Paint()..color = color.withValues(alpha: 0.9),
    );

    // Turret barrel (follows aim angle)
    canvas.save();
    canvas.translate(0, -4);
    canvas.rotate(turretAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, -2.5, 20, 5),
        const Radius.circular(2),
      ),
      Paint()..color = color.withValues(alpha: 0.7),
    );
    canvas.restore();

    // Glow
    canvas.drawCircle(
      Offset.zero,
      20,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }
}

class _Projectile extends PositionComponent {
  Vector2 velocity;
  final int ownerId;
  final Color color;
  final List<Vector2> trail = [];

  _Projectile({
    required Vector2 position,
    required this.velocity,
    required this.ownerId,
    required this.color,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 5, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero, 5,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Fire trail
    canvas.drawCircle(
      Offset.zero, 3,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }
}
