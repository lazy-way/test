import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class MicroRacersGame extends FlameGame with MultiTouchTapDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  late List<_RaceCar> cars;
  late Path trackPath;
  late List<Offset> trackPoints;
  final int lapsToWin = 3;
  bool _gameOver = false;
  final Map<int, int> _activeTouches = {};

  MicroRacersGame({required this.players, required this.onGameEnd});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Micro Racers',
      players: players,
      gameBuilder: (onEnd) => GameWidget(
        game: MicroRacersGame(players: players, onGameEnd: onEnd),
        backgroundBuilder: (context) => Container(color: const Color(0xFF2d5a27)),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Create oval track
    final cx = size.x / 2;
    final cy = size.y / 2;
    final rx = size.x * 0.35;
    final ry = size.y * 0.35;

    trackPoints = List.generate(100, (i) {
      final angle = 2 * pi * i / 100;
      return Offset(cx + rx * cos(angle), cy + ry * sin(angle));
    });

    cars = List.generate(players.length, (i) {
      final startAngle = 2 * pi * i / players.length;
      return _RaceCar(
        position: Vector2(cx + rx * cos(startAngle), cy + ry * sin(startAngle)),
        color: players[i].color,
        playerId: i,
        angle: startAngle + pi / 2,
        trackAngle: startAngle,
      );
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    final cx = size.x / 2;
    final cy = size.y / 2;
    final rx = size.x * 0.35;
    final ry = size.y * 0.35;

    for (final car in cars) {
      // Auto accelerate along track
      car.speed = 150;
      car.trackAngle += car.speed * dt / (max(rx, ry));

      // Apply steering
      car.trackAngle += car.steering * dt * 0.5;

      // Keep on track with some freedom
      final targetX = cx + rx * cos(car.trackAngle);
      final targetY = cy + ry * sin(car.trackAngle);
      car.position.x += (targetX - car.position.x) * 0.1;
      car.position.y += (targetY - car.position.y) * 0.1;
      car.angle = car.trackAngle + pi / 2;

      // Lap counting
      if (car.trackAngle - car.lastLapAngle >= 2 * pi) {
        car.laps++;
        car.lastLapAngle = car.trackAngle;
        if (car.laps >= lapsToWin) {
          _gameOver = true;
          for (int i = 0; i < players.length; i++) {
            players[i].score = cars[i].laps;
          }
          onGameEnd();
          return;
        }
      }
    }
  }

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;

    for (int i = 0; i < players.length; i++) {
      final zone = _getPlayerZone(i);
      if (zone.contains(Offset(pos.x, pos.y))) {
        // Left half of zone = steer left, right half = steer right
        final zoneCenterX = zone.left + zone.width / 2;
        cars[i].steering = pos.x < zoneCenterX ? -1.0 : 1.0;
        _activeTouches[pointerId] = i;
        break;
      }
    }
  }

  @override
  void onTapUp(int pointerId, TapUpInfo info) {
    final playerIdx = _activeTouches.remove(pointerId);
    if (playerIdx != null) {
      cars[playerIdx].steering = 0;
    }
  }

  @override
  void onTapCancel(int pointerId) {
    final playerIdx = _activeTouches.remove(pointerId);
    if (playerIdx != null) {
      cars[playerIdx].steering = 0;
    }
  }

  Rect _getPlayerZone(int index) {
    switch (players.length) {
      case 1: return Rect.fromLTWH(0, 0, size.x, size.y);
      case 2:
        return index == 0
            ? Rect.fromLTWH(0, size.y / 2, size.x, size.y / 2)
            : Rect.fromLTWH(0, 0, size.x, size.y / 2);
      default:
        return Rect.fromLTWH(0, 0, size.x, size.y);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final cx = size.x / 2;
    final cy = size.y / 2;
    final rx = size.x * 0.35;
    final ry = size.y * 0.35;

    // Track
    final trackPaint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 50;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      trackPaint,
    );

    // Track borders
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: (rx - 25) * 2, height: (ry - 25) * 2),
      borderPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: (rx + 25) * 2, height: (ry + 25) * 2),
      borderPaint,
    );

    // Start/finish line
    canvas.drawLine(
      Offset(cx + rx - 25, cy),
      Offset(cx + rx + 25, cy),
      Paint()..color = Colors.white..strokeWidth = 3,
    );

    // Cars
    for (final car in cars) {
      canvas.save();
      canvas.translate(car.position.x, car.position.y);
      canvas.rotate(car.angle);

      // Car body
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-8, -5, 16, 10),
          const Radius.circular(3),
        ),
        Paint()..color = car.color,
      );
      // Windshield
      canvas.drawRect(
        const Rect.fromLTWH(2, -3, 4, 6),
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );

      canvas.restore();
    }

    // Lap counters
    for (int i = 0; i < cars.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'P${i + 1}: Lap ${cars[i].laps}/$lapsToWin',
          style: TextStyle(color: cars[i].color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, 10.0 + i * 20));
    }
  }
}

class _RaceCar {
  Vector2 position;
  Color color;
  int playerId;
  double angle;
  double trackAngle;
  double speed = 0;
  double steering = 0;
  int laps = 0;
  double lastLapAngle;

  _RaceCar({
    required this.position,
    required this.color,
    required this.playerId,
    required this.angle,
    required this.trackAngle,
  }) : lastLapAngle = trackAngle;
}
