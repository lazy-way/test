import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class SumoPushGame extends FlameGame with MultiTouchDragDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  late List<_SumoPlayer> sumos;
  late Vector2 arenaCenter;
  late double arenaRadius;
  bool _gameOver = false;
  final Map<int, int> _dragToPlayer = {};

  SumoPushGame({required this.players, required this.onGameEnd});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Sumo Push',
      players: players,
      gameBuilder: (onEnd) => GameWidget(
        game: SumoPushGame(players: players, onGameEnd: onEnd),
        backgroundBuilder: (context) => Container(color: const Color(0xFF1a1a2e)),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    arenaCenter = Vector2(size.x / 2, size.y / 2);
    arenaRadius = min(size.x, size.y) * 0.38;

    add(_Arena(center: arenaCenter, radius: arenaRadius));

    final angleStep = 2 * pi / players.length;
    sumos = List.generate(players.length, (i) {
      final angle = angleStep * i - pi / 2;
      final pos = arenaCenter + Vector2(cos(angle), sin(angle)) * (arenaRadius * 0.5);
      final sumo = _SumoPlayer(
        position: pos,
        color: players[i].color,
        playerId: i,
        radius: 25,
      );
      add(sumo);
      return sumo;
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    for (final sumo in sumos) {
      if (!sumo.alive) continue;

      // Apply velocity with friction
      sumo.position += sumo.velocity * dt;
      sumo.velocity *= 0.95;

      // Check if out of arena
      final dist = sumo.position.distanceTo(arenaCenter);
      if (dist > arenaRadius + sumo.radius) {
        sumo.alive = false;
        _checkWin();
      }

      // Collision with other sumos
      for (final other in sumos) {
        if (other == sumo || !other.alive) continue;
        final d = sumo.position.distanceTo(other.position);
        if (d < sumo.radius + other.radius) {
          final normal = (other.position - sumo.position).normalized();
          final overlap = sumo.radius + other.radius - d;
          sumo.position -= normal * overlap * 0.5;
          other.position += normal * overlap * 0.5;

          // Transfer momentum
          final relVel = sumo.velocity - other.velocity;
          final impulse = normal * relVel.dot(normal);
          sumo.velocity -= impulse * 0.8;
          other.velocity += impulse * 0.8;
        }
      }
    }
  }

  void _checkWin() {
    final alive = sumos.where((s) => s.alive).toList();
    if (alive.length <= 1) {
      _gameOver = true;
      for (int i = 0; i < players.length; i++) {
        players[i].score = sumos[i].alive ? 1 : 0;
      }
      onGameEnd();
    }
  }

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    final pos = info.eventPosition.global;
    for (int i = 0; i < sumos.length; i++) {
      if (!sumos[i].alive) continue;
      if (sumos[i].position.distanceTo(pos) < 50) {
        _dragToPlayer[pointerId] = i;
        break;
      }
    }
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    final playerIdx = _dragToPlayer.remove(pointerId);
    if (playerIdx == null) return;
    // Apply dash velocity from fling
    sumos[playerIdx].velocity += info.velocity / 3;
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    // Visual feedback only
  }
}

class _SumoPlayer extends PositionComponent {
  final Color color;
  final int playerId;
  final double radius;
  Vector2 velocity = Vector2.zero();
  bool alive = true;

  _SumoPlayer({
    required Vector2 position,
    required this.color,
    required this.playerId,
    required this.radius,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    if (!alive) return;

    // Body
    canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
    // Inner
    canvas.drawCircle(Offset.zero, radius * 0.6, Paint()..color = color.withValues(alpha: 0.7));
    // Face
    canvas.drawCircle(const Offset(-6, -5), 3, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(6, -5), 3, Paint()..color = Colors.white);
    canvas.drawArc(
      const Rect.fromLTWH(-6, 2, 12, 8),
      0, pi, false,
      Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke,
    );
    // Glow
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }
}

class _Arena extends PositionComponent {
  final Vector2 center;
  final double radius;

  _Arena({required this.center, required this.radius});

  @override
  void render(Canvas canvas) {
    // Outer ring
    canvas.drawCircle(
      Offset(center.x, center.y),
      radius,
      Paint()
        ..color = const Color(0xFF2a2a4e)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(center.x, center.y),
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Inner circle
    canvas.drawCircle(
      Offset(center.x, center.y),
      radius * 0.3,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
