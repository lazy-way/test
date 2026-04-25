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

  // Turn-based state
  int currentPlayer = 0;
  bool _waitingForSettle = false; // wait for pieces to stop before switching turns

  SumoPushGame({required this.players, required this.onGameEnd});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Pen Fight',
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
    arenaRadius = min(size.x, size.y) * 0.38 * 2.5;

    add(_Arena(center: arenaCenter, radius: arenaRadius));

    // Place P1 at bottom, P2 at top
    final positions = [
      arenaCenter + Vector2(0, arenaRadius * 0.45),  // P1 bottom
      arenaCenter + Vector2(0, -arenaRadius * 0.45), // P2 top
    ];

    sumos = List.generate(players.length, (i) {
      final sumo = _SumoPlayer(
        position: positions[i].clone(),
        color: players[i].color,
        playerId: i,
        radius: 25,
      );
      add(sumo);
      return sumo;
    });

    // Turn indicator
    add(_TurnIndicator(game: this));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    bool anyMoving = false;

    for (final sumo in sumos) {
      if (!sumo.alive) continue;

      // Apply velocity with friction
      sumo.position += sumo.velocity * dt;
      sumo.velocity *= 0.94;

      // Stop tiny velocities
      if (sumo.velocity.length < 5) {
        sumo.velocity = Vector2.zero();
      } else {
        anyMoving = true;
      }

      // Check if out of arena
      final dist = sumo.position.distanceTo(arenaCenter);
      if (dist > arenaRadius + sumo.radius) {
        sumo.alive = false;
        _checkWin();
        return;
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
          sumo.velocity -= impulse * 0.7;
          other.velocity += impulse * 0.7;
        }
      }
    }

    // After a fling, wait for all pieces to settle before switching turns
    if (_waitingForSettle && !anyMoving) {
      _waitingForSettle = false;
      _switchTurn();
    }
  }

  void _switchTurn() {
    if (_gameOver) return;
    currentPlayer = (currentPlayer + 1) % players.length;
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
    if (_waitingForSettle || _gameOver) return;
    final pos = info.eventPosition.global;

    // Only allow current player to drag their piece
    final sumo = sumos[currentPlayer];
    if (!sumo.alive) return;
    if (sumo.position.distanceTo(pos) < 60) {
      _dragToPlayer[pointerId] = currentPlayer;
    }
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    final playerIdx = _dragToPlayer.remove(pointerId);
    if (playerIdx == null) return;

    // Cap the fling velocity.
    var vel = info.velocity;
    final maxSpeed = 6000.0;
    if (vel.length > maxSpeed) {
      vel = vel.normalized() * maxSpeed;
    }
    sumos[playerIdx].velocity += vel / 6;

    // Wait for pieces to settle before switching
    _waitingForSettle = true;
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    // Visual feedback only
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Active player glow around their piece
    if (!_gameOver && !_waitingForSettle) {
      final sumo = sumos[currentPlayer];
      if (sumo.alive) {
        canvas.drawCircle(
          Offset(sumo.position.x, sumo.position.y),
          sumo.radius + 8,
          Paint()
            ..color = sumo.color.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
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

class _TurnIndicator extends PositionComponent {
  final SumoPushGame game;

  _TurnIndicator({required this.game});

  @override
  void render(Canvas canvas) {
    if (game._gameOver) return;

    final text = game._waitingForSettle
        ? '...'
        : 'P${game.currentPlayer + 1}\'s Turn';
    final color = game.players[game.currentPlayer].color;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: 0.7),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(game.size.x / 2 - tp.width / 2, 16));
  }
}

class _Arena extends PositionComponent {
  final Vector2 center;
  final double radius;

  _Arena({required this.center, required this.radius});

  @override
  void render(Canvas canvas) {
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
