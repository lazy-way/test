import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class AirHockeyGame extends FlameGame with MultiTouchDragDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  late _Mallet mallet1, mallet2;
  late _Puck puck;
  List<int> scores = [0, 0];
  final int winScore = 7;
  bool _gameOver = false;
  final Map<int, int> _dragToMallet = {};

  AirHockeyGame({required this.players, required this.onGameEnd});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Air Hockey',
      players: players,
      gameBuilder: (onEnd) => GameWidget(
        game: AirHockeyGame(players: players, onGameEnd: onEnd),
        backgroundBuilder: (context) => Container(color: const Color(0xFF1a1a3e)),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Table border
    add(_TableBorder(screenSize: size));

    // Goals
    final goalWidth = size.x * 0.4;

    // Mallets
    mallet1 = _Mallet(
      position: Vector2(size.x / 2, size.y * 0.85),
      color: players[0].color,
      radius: 30,
    );
    mallet2 = _Mallet(
      position: Vector2(size.x / 2, size.y * 0.15),
      color: players.length > 1 ? players[1].color : Colors.grey,
      radius: 30,
      isAI: players.length < 2,
    );

    puck = _Puck(
      position: Vector2(size.x / 2, size.y / 2),
      radius: 15,
    );

    add(mallet1);
    add(mallet2);
    add(puck);

    // Score displays
    add(_HockeyScore(
      position: Vector2(20, size.y / 2 + 20),
      scoreGetter: () => scores[0],
      color: players[0].color,
    ));
    add(_HockeyScore(
      position: Vector2(20, size.y / 2 - 40),
      scoreGetter: () => scores.length > 1 ? scores[1] : 0,
      color: players.length > 1 ? players[1].color : Colors.grey,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    // AI mallet
    if (mallet2.isAI) {
      final target = Vector2(puck.position.x, puck.position.y);
      if (target.y > size.y * 0.5) target.y = size.y * 0.25;
      final diff = target - mallet2.position;
      if (diff.length > 5) {
        mallet2.position += diff.normalized() * min(300 * dt, diff.length);
      }
      mallet2.position.y = mallet2.position.y.clamp(mallet2.radius.toDouble(), size.y / 2 - mallet2.radius);
      mallet2.position.x = mallet2.position.x.clamp(mallet2.radius.toDouble(), size.x - mallet2.radius);
    }

    // Puck movement
    puck.position += puck.velocity * dt;

    // Friction
    puck.velocity *= 0.998;

    // Wall bounce
    if (puck.position.x <= puck.radius || puck.position.x >= size.x - puck.radius) {
      puck.velocity.x = -puck.velocity.x * 0.9;
      puck.position.x = puck.position.x.clamp(puck.radius.toDouble(), size.x - puck.radius);
    }

    // Goal detection
    final goalLeft = size.x / 2 - size.x * 0.2;
    final goalRight = size.x / 2 + size.x * 0.2;

    if (puck.position.y <= puck.radius) {
      if (puck.position.x > goalLeft && puck.position.x < goalRight) {
        // Player 1 scores
        scores[0]++;
        _checkWin();
        _resetPuck();
      } else {
        puck.velocity.y = -puck.velocity.y * 0.9;
        puck.position.y = puck.radius.toDouble();
      }
    }
    if (puck.position.y >= size.y - puck.radius) {
      if (puck.position.x > goalLeft && puck.position.x < goalRight) {
        // Player 2 scores
        if (scores.length > 1) scores[1]++;
        _checkWin();
        _resetPuck();
      } else {
        puck.velocity.y = -puck.velocity.y * 0.9;
        puck.position.y = size.y - puck.radius;
      }
    }

    // Mallet-puck collision
    _checkMalletCollision(mallet1);
    _checkMalletCollision(mallet2);
  }

  void _checkMalletCollision(_Mallet mallet) {
    final dist = mallet.position.distanceTo(puck.position);
    if (dist < mallet.radius + puck.radius) {
      final normal = (puck.position - mallet.position).normalized();
      puck.velocity = normal * max(puck.velocity.length, 400);
      puck.position = mallet.position + normal * (mallet.radius + puck.radius + 1);
    }
  }

  void _resetPuck() {
    puck.position = Vector2(size.x / 2, size.y / 2);
    puck.velocity = Vector2.zero();
  }

  void _checkWin() {
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] >= winScore) {
        _gameOver = true;
        for (int j = 0; j < players.length; j++) {
          players[j].score = scores[j < scores.length ? j : 0];
        }
        onGameEnd();
        return;
      }
    }
  }

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    final pos = info.eventPosition.global;
    final d1 = pos.distanceTo(mallet1.position);
    final d2 = pos.distanceTo(mallet2.position);

    if (d1 < 60 && !mallet1.isAI) {
      _dragToMallet[pointerId] = 0;
    } else if (d2 < 60 && !mallet2.isAI) {
      _dragToMallet[pointerId] = 1;
    }
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    final malletIdx = _dragToMallet[pointerId];
    if (malletIdx == null) return;

    final mallet = malletIdx == 0 ? mallet1 : mallet2;
    mallet.position += info.delta.global;

    // Constrain to own half
    mallet.position.x = mallet.position.x.clamp(mallet.radius.toDouble(), size.x - mallet.radius);
    if (malletIdx == 0) {
      mallet.position.y = mallet.position.y.clamp(size.y / 2 + mallet.radius, size.y - mallet.radius);
    } else {
      mallet.position.y = mallet.position.y.clamp(mallet.radius.toDouble(), size.y / 2 - mallet.radius);
    }
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    _dragToMallet.remove(pointerId);
  }
}

class _Mallet extends PositionComponent {
  final Color color;
  final double radius;
  final bool isAI;

  _Mallet({
    required Vector2 position,
    required this.color,
    required this.radius,
    this.isAI = false,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    // Outer ring
    canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
    // Inner circle
    canvas.drawCircle(Offset.zero, radius * 0.5, Paint()..color = color.withValues(alpha: 0.6));
    // Glow
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }
}

class _Puck extends PositionComponent {
  final double radius;
  Vector2 velocity = Vector2.zero();

  _Puck({required Vector2 position, required this.radius})
      : super(position: position, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }
}

class _TableBorder extends PositionComponent {
  final Vector2 screenSize;
  _TableBorder({required this.screenSize});

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, screenSize.x - 4, screenSize.y - 4),
        const Radius.circular(8),
      ),
      paint,
    );

    // Center line
    canvas.drawLine(
      Offset(0, screenSize.y / 2),
      Offset(screenSize.x, screenSize.y / 2),
      paint,
    );

    // Center circle
    canvas.drawCircle(
      Offset(screenSize.x / 2, screenSize.y / 2),
      50,
      paint,
    );

    // Goals
    final goalWidth = screenSize.x * 0.4;
    final goalPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.4)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Top goal
    canvas.drawLine(
      Offset(screenSize.x / 2 - goalWidth / 2, 0),
      Offset(screenSize.x / 2 + goalWidth / 2, 0),
      goalPaint,
    );
    // Bottom goal
    canvas.drawLine(
      Offset(screenSize.x / 2 - goalWidth / 2, screenSize.y),
      Offset(screenSize.x / 2 + goalWidth / 2, screenSize.y),
      goalPaint,
    );
  }
}

class _HockeyScore extends PositionComponent {
  final int Function() scoreGetter;
  final Color color;

  _HockeyScore({
    required Vector2 position,
    required this.scoreGetter,
    required this.color,
  }) : super(position: position);

  @override
  void render(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${scoreGetter()}',
        style: TextStyle(color: color.withValues(alpha: 0.4), fontSize: 48, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
  }
}
