import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class TankBattleGame extends FlameGame with MultiTouchTapDetector {
  TankBattleGame({required this.players, required this.onGameEnd});

  final List<Player> players;
  final VoidCallback onGameEnd;

  static const double gravity = 420;
  static const double minPower = 220;
  static const double maxPower = 620;
  static const double barrelLength = 28;
  static const double hitRadius = 28;
  static const double explosionRadius = 26;
  static const double craterRadius = 36;
  static const double tankGroundOffset = 10;
  static const int targetHitsToWin = 3;

  final Random _random = Random();
  final List<_Projectile> _projectiles = [];
  final List<_Explosion> _explosions = [];

  late List<_Tank> _tanks;
  late List<double> terrain;
  late List<double> _terrainPreset;
  late int _terrainVariantIndex;
  late List<int> _hits;

  int currentPlayer = 0;
  bool _gameOver = false;
  double _phaseTimer = 0;
  double _selectedAngle = 0;
  double _selectedPower = minPower;
  _TurnPhase _turnPhase = _TurnPhase.selectDirection;

  static Widget widget({required List<Player> players}) {
    return _TankBattleLandscapeScope(
      child: GameWrapper(
        gameName: 'Tank Battle',
        players: players,
        gameBuilder: (onEnd) => GameWidget(
          game: TankBattleGame(players: players, onGameEnd: onEnd),
          backgroundBuilder: (context) =>
              Container(color: const Color(0xFF10212f)),
        ),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hits = List<int>.filled(players.length, 0);
    _generateTerrain();
    _spawnTanks();
    _startTurn(resetAngle: true);
  }

  void _generateTerrain() {
    final segments = max(80, (size.x / 10).round());
    _terrainVariantIndex = _random.nextInt(_terrainPresets.length);
    _terrainPreset = _terrainPresets[_terrainVariantIndex];
    terrain = List<double>.filled(segments + 1, 0);

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final presetY = _samplePreset(_terrainPreset, t) * size.y;
      final edgeFalloff = sin(t * pi).clamp(0.0, 1.0);
      final noise = (_random.nextDouble() * 2 - 1) * 10 * edgeFalloff;
      terrain[i] = (presetY + noise).clamp(size.y * 0.36, size.y * 0.82);
    }

    final spawnIndices = [
      max(3, (segments * 0.15).round()),
      min(segments - 3, (segments * 0.85).round()),
    ];
    for (final index in spawnIndices) {
      final from = max(0, index - 4);
      final to = min(segments, index + 4);
      final average =
          terrain.sublist(from, to + 1).reduce((a, b) => a + b) /
          (to - from + 1);
      for (int i = from; i <= to; i++) {
        terrain[i] = average;
      }
    }
  }

  void _spawnTanks() {
    final p1x = size.x * 0.16;
    final p2x = size.x * 0.84;
    _tanks = [
      _Tank(
        position: Vector2(p1x, _tankYForX(p1x)),
        color: players[0].color,
        playerId: 0,
        facingRight: true,
      ),
      _Tank(
        position: Vector2(p2x, _tankYForX(p2x)),
        color: players[1].color,
        playerId: 1,
        facingRight: false,
      ),
    ];

    for (final tank in _tanks) {
      add(tank);
    }
  }

  double _samplePreset(List<double> preset, double t) {
    final scaled = t * (preset.length - 1);
    final index = scaled.floor().clamp(0, preset.length - 2);
    final frac = scaled - index;
    return preset[index] * (1 - frac) + preset[index + 1] * frac;
  }

  double _getTerrainY(double x) {
    final segments = terrain.length - 1;
    final normalized = (x / size.x).clamp(0.0, 1.0);
    final idx = normalized * segments;
    final i = idx.floor().clamp(0, segments - 1);
    final frac = idx - i;
    return terrain[i] * (1 - frac) + terrain[i + 1] * frac;
  }

  double _tankYForX(double x) => _getTerrainY(x) - tankGroundOffset;

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) {
      return;
    }

    _phaseTimer += dt;
    _updateAimSweep();

    for (final explosion in List<_Explosion>.from(_explosions)) {
      explosion.life -= dt;
      if (explosion.life <= 0) {
        _explosions.remove(explosion);
        remove(explosion);
      }
    }

    for (final projectile in List<_Projectile>.from(_projectiles)) {
      projectile.velocity.y += gravity * dt;
      projectile.position += projectile.velocity * dt;
      projectile.trail.add(projectile.position.clone());
      if (projectile.trail.length > 40) {
        projectile.trail.removeAt(0);
      }

      if (projectile.position.x < -50 ||
          projectile.position.x > size.x + 50 ||
          projectile.position.y > size.y + 50) {
        _removeProjectile(projectile);
        _endTurn();
        continue;
      }

      final opponent = _tanks[1 - projectile.ownerId];
      if (projectile.position.distanceTo(opponent.position) <= hitRadius) {
        _resolveImpact(projectile, opponent.position.clone(), targetHit: true);
        continue;
      }

      final terrainY = _getTerrainY(projectile.position.x);
      if (projectile.position.y >= terrainY) {
        _resolveImpact(
          projectile,
          Vector2(projectile.position.x, terrainY),
          targetHit: false,
        );
      }
    }

    for (final tank in _tanks) {
      tank.position.y = _tankYForX(tank.position.x);
    }
  }

  void _updateAimSweep() {
    if (_turnPhase == _TurnPhase.selectDirection) {
      final activeTank = _tanks[currentPlayer];
      final minAngle = activeTank.facingRight ? -pi : 0.0;
      final sweep = pi;
      final cycle = 2.2;
      final progress = (_phaseTimer % cycle) / cycle;
      final pingPong = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
      _selectedAngle = minAngle + sweep * pingPong;
      activeTank.turretAngle = _selectedAngle;
    } else if (_turnPhase == _TurnPhase.selectPower) {
      final cycle = 1.8;
      final progress = (_phaseTimer % cycle) / cycle;
      final pingPong = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
      _selectedPower = minPower + (maxPower - minPower) * pingPong;
    }
  }

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    if (_gameOver) {
      return;
    }

    switch (_turnPhase) {
      case _TurnPhase.selectDirection:
        _turnPhase = _TurnPhase.selectPower;
        _phaseTimer = 0;
        break;
      case _TurnPhase.selectPower:
        _fire();
        break;
      case _TurnPhase.projectileInFlight:
      case _TurnPhase.gameOver:
        break;
    }
  }

  void _fire() {
    final tank = _tanks[currentPlayer];
    final direction = Vector2(cos(_selectedAngle), sin(_selectedAngle));
    final start = tank.position + direction * barrelLength;
    final projectile = _Projectile(
      position: start,
      velocity: direction * _selectedPower,
      ownerId: currentPlayer,
      color: tank.color,
    );
    tank.turretAngle = _selectedAngle;
    _projectiles.add(projectile);
    add(projectile);
    _turnPhase = _TurnPhase.projectileInFlight;
  }

  void _resolveImpact(
    _Projectile projectile,
    Vector2 impact, {
    required bool targetHit,
  }) {
    final ownerId = projectile.ownerId;
    _removeProjectile(projectile);
    _createExplosion(impact, _tanks[ownerId].color);
    _deformTerrain(impact.x);

    if (targetHit) {
      _hits[ownerId] += 1;
      if (_hits[ownerId] >= targetHitsToWin) {
        _gameOver = true;
        _turnPhase = _TurnPhase.gameOver;
        for (int i = 0; i < players.length; i++) {
          players[i].score = i == ownerId ? 1 : 0;
        }
        onGameEnd();
        return;
      }
    }

    _endTurn();
  }

  void _createExplosion(Vector2 position, Color color) {
    final explosion = _Explosion(position: position, color: color);
    _explosions.add(explosion);
    add(explosion);
  }

  void _deformTerrain(double impactX) {
    final segments = terrain.length - 1;
    for (int i = 0; i <= segments; i++) {
      final tx = i / segments * size.x;
      final distance = (tx - impactX).abs();
      if (distance <= craterRadius) {
        final ratio = 1 - distance / craterRadius;
        terrain[i] = (terrain[i] + ratio * 8).clamp(
          size.y * 0.34,
          size.y * 0.85,
        );
      }
    }
  }

  void _removeProjectile(_Projectile projectile) {
    _projectiles.remove(projectile);
    remove(projectile);
  }

  void _endTurn() {
    currentPlayer = (currentPlayer + 1) % players.length;
    _startTurn(resetAngle: true);
  }

  void _startTurn({required bool resetAngle}) {
    _turnPhase = _TurnPhase.selectDirection;
    _phaseTimer = 0;
    _selectedPower = minPower;
    if (resetAngle) {
      _selectedAngle = _tanks[currentPlayer].facingRight
          ? -pi / 4
          : -3 * pi / 4;
    }
    _tanks[currentPlayer].turretAngle = _selectedAngle;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderSky(canvas);
    _renderBackdrop(canvas);
    _renderTerrain(canvas);
    _renderTrails(canvas);
    _renderAimPreview(canvas);
    _renderHud(canvas);
  }

  void _renderSky(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF86C8FF), Color(0xFFD7F1FF)],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );
  }

  void _renderBackdrop(Canvas canvas) {
    final hillPaint = Paint()..color = const Color(0x4438674d);
    final ridgePath = Path()
      ..moveTo(0, size.y)
      ..quadraticBezierTo(
        size.x * 0.18,
        size.y * 0.5,
        size.x * 0.42,
        size.y * 0.62,
      )
      ..quadraticBezierTo(size.x * 0.66, size.y * 0.48, size.x, size.y * 0.68)
      ..lineTo(size.x, size.y)
      ..close();
    canvas.drawPath(ridgePath, hillPaint);
  }

  void _renderTerrain(Canvas canvas) {
    final terrainPath = Path()..moveTo(0, size.y);
    final edgePath = Path()..moveTo(0, terrain.first);
    final segments = terrain.length - 1;

    for (int i = 0; i <= segments; i++) {
      final x = i / segments * size.x;
      terrainPath.lineTo(x, terrain[i]);
      if (i > 0) {
        edgePath.lineTo(x, terrain[i]);
      }
    }

    terrainPath
      ..lineTo(size.x, size.y)
      ..close();

    canvas.drawPath(
      terrainPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8E6A3D), Color(0xFF5A4021)],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );

    final grassPath = Path()..moveTo(0, terrain.first);
    for (int i = 1; i <= segments; i++) {
      final x = i / segments * size.x;
      grassPath.lineTo(x, terrain[i]);
    }
    canvas.drawPath(
      grassPath,
      Paint()
        ..color = const Color(0xFF78C850)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(
      edgePath,
      Paint()
        ..color = const Color(0x995C4324)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  void _renderTrails(Canvas canvas) {
    for (final projectile in _projectiles) {
      if (projectile.trail.length < 2) {
        continue;
      }
      final path = Path()
        ..moveTo(projectile.trail.first.x, projectile.trail.first.y);
      for (int i = 1; i < projectile.trail.length; i++) {
        path.lineTo(projectile.trail[i].x, projectile.trail[i].y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = projectile.color.withValues(alpha: 0.35)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _renderAimPreview(Canvas canvas) {
    if (_turnPhase != _TurnPhase.selectPower) {
      return;
    }

    final tank = _tanks[currentPlayer];
    final direction = Vector2(cos(_selectedAngle), sin(_selectedAngle));
    double px = tank.position.x + direction.x * barrelLength;
    double py = tank.position.y + direction.y * barrelLength;
    double vx = direction.x * _selectedPower;
    double vy = direction.y * _selectedPower;
    final dotPaint = Paint()..color = tank.color.withValues(alpha: 0.45);

    for (int step = 0; step < 28; step++) {
      vy += gravity * 0.03;
      px += vx * 0.03;
      py += vy * 0.03;
      if (px < 0 || px > size.x || py > size.y || py >= _getTerrainY(px)) {
        break;
      }
      if (step.isEven) {
        canvas.drawCircle(Offset(px, py), 2.2, dotPaint);
      }
    }
  }

  void _renderHud(Canvas canvas) {
    final banner = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.x / 2 - 200, 16, 400, 64),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      banner,
      Paint()..color = Colors.black.withValues(alpha: 0.24),
    );

    _paintText(
      canvas,
      'Terrain ${_terrainVariantIndex + 1}  |  First to $targetHitsToWin hits',
      Offset(size.x / 2, 24),
      const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      centered: true,
    );

    final activeColor = players[currentPlayer].color;
    final turnText = switch (_turnPhase) {
      _TurnPhase.selectDirection =>
        'P${currentPlayer + 1}: tap to lock direction',
      _TurnPhase.selectPower => 'P${currentPlayer + 1}: tap to lock power',
      _TurnPhase.projectileInFlight => 'P${currentPlayer + 1}: shot in flight',
      _TurnPhase.gameOver => 'Game Over',
    };
    _paintText(
      canvas,
      turnText,
      Offset(size.x / 2, 44),
      TextStyle(color: activeColor, fontSize: 16, fontWeight: FontWeight.bold),
      centered: true,
    );

    final leftLabel = 'P1 ${_hits[0]}/$targetHitsToWin';
    final rightLabel = 'P2 ${_hits[1]}/$targetHitsToWin';
    _paintText(
      canvas,
      leftLabel,
      const Offset(24, 24),
      TextStyle(
        color: players[0].color,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    _paintText(
      canvas,
      rightLabel,
      Offset(size.x - 24, 24),
      TextStyle(
        color: players[1].color,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      centered: false,
      alignRight: true,
    );

    if (_turnPhase == _TurnPhase.selectPower) {
      final width = 180.0;
      final left = size.x / 2 - width / 2;
      final progress = (_selectedPower - minPower) / (maxPower - minPower);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 90, width, 12),
          const Radius.circular(8),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.14),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 90, width * progress, 12),
          const Radius.circular(8),
        ),
        Paint()..color = activeColor,
      );
      _paintText(
        canvas,
        'Power ${(progress * 100).round()}%',
        Offset(size.x / 2, 108),
        const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        centered: true,
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    bool centered = false,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    double dx = offset.dx;
    if (centered) {
      dx -= painter.width / 2;
    } else if (alignRight) {
      dx -= painter.width;
    }
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  static const List<List<double>> _terrainPresets = [
    [0.72, 0.68, 0.64, 0.61, 0.59, 0.58, 0.6, 0.64, 0.67, 0.7, 0.73],
    [0.69, 0.65, 0.6, 0.55, 0.56, 0.61, 0.66, 0.68, 0.65, 0.61, 0.58],
    [0.63, 0.61, 0.58, 0.55, 0.57, 0.63, 0.69, 0.71, 0.68, 0.63, 0.6],
    [0.7, 0.69, 0.67, 0.64, 0.59, 0.53, 0.56, 0.62, 0.67, 0.71, 0.74],
    [0.6, 0.57, 0.55, 0.58, 0.63, 0.69, 0.67, 0.62, 0.58, 0.56, 0.59],
    [0.73, 0.69, 0.63, 0.58, 0.55, 0.57, 0.61, 0.66, 0.7, 0.72, 0.7],
  ];
}

class _TankBattleLandscapeScope extends StatefulWidget {
  const _TankBattleLandscapeScope({required this.child});

  final Widget child;

  @override
  State<_TankBattleLandscapeScope> createState() =>
      _TankBattleLandscapeScopeState();
}

class _TankBattleLandscapeScopeState extends State<_TankBattleLandscapeScope> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _TurnPhase { selectDirection, selectPower, projectileInFlight, gameOver }

class _Tank extends PositionComponent {
  _Tank({
    required Vector2 position,
    required this.color,
    required this.playerId,
    required this.facingRight,
  }) : turretAngle = facingRight ? -pi / 4 : -3 * pi / 4,
       super(position: position, anchor: Anchor.center);

  final Color color;
  final int playerId;
  final bool facingRight;
  double turretAngle;

  @override
  void render(Canvas canvas) {
    canvas.save();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, -12, 40, 16),
        const Radius.circular(4),
      ),
      Paint()..color = color,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-24, 2, 48, 10),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF30343F),
    );

    for (double x = -18; x <= 18; x += 9) {
      canvas.drawCircle(Offset(x, 7), 3.4, Paint()..color = Colors.black54);
    }

    canvas.drawCircle(
      const Offset(0, -4),
      9,
      Paint()..color = color.withValues(alpha: 0.95),
    );

    canvas.save();
    canvas.translate(0, -4);
    canvas.rotate(turretAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, -3, 26, 6),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF28323C),
    );
    canvas.restore();

    canvas.drawCircle(
      Offset.zero,
      24,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.restore();
  }
}

class _Projectile extends PositionComponent {
  _Projectile({
    required Vector2 position,
    required this.velocity,
    required this.ownerId,
    required this.color,
  }) : super(position: position, anchor: Anchor.center);

  Vector2 velocity;
  final int ownerId;
  final Color color;
  final List<Vector2> trail = [];

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 5, Paint()..color = const Color(0xFF2F3640));
    canvas.drawCircle(
      Offset.zero,
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      Offset.zero,
      8,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}

class _Explosion extends PositionComponent {
  _Explosion({required Vector2 position, required this.color})
    : life = 0.32,
      super(position: position, anchor: Anchor.center);

  final Color color;
  double life;

  @override
  void render(Canvas canvas) {
    final progress = (1 - (life / 0.32)).clamp(0.0, 1.0);
    final outerRadius = TankBattleGame.explosionRadius * (0.6 + progress * 0.7);
    final innerRadius = outerRadius * 0.45;

    canvas.drawCircle(
      Offset.zero,
      outerRadius,
      Paint()..color = Colors.orange.withValues(alpha: 0.32 * (1 - progress)),
    );
    canvas.drawCircle(
      Offset.zero,
      innerRadius,
      Paint()..color = color.withValues(alpha: 0.85 * (1 - progress * 0.5)),
    );
  }
}
