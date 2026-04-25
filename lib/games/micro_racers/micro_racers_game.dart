import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class MicroRacersGame extends FlameGame with MultiTouchDragDetector {
  static const double _trackStrokeWidth = 50.0;
  static const double _carHalfWidth = 8.0;
  static const double _carHalfHeight = 5.0;
  static const double _trackSpeed = 300.0;

  final List<Player> players;
  final VoidCallback onGameEnd;

  late List<_RaceCar> cars;
  late List<_Joystick> joysticks;
  final int lapsToWin = 3;
  bool _gameOver = false;
  final Map<int, int> _dragToJoystick = {};

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

    final cx = size.x / 2;
    final cy = size.y / 2;
    final rx = size.x * 0.35;
    final ry = size.y * 0.30;

    cars = List.generate(players.length, (i) {
      final startAngle = 2 * pi * i / players.length;
      return _RaceCar(
        position: Vector2(cx + rx * cos(startAngle), cy + ry * sin(startAngle)),
        color: players[i].color,
        playerId: i,
        angle: startAngle + pi / 2,
        lastAngleSample: startAngle,
      );
    });

    // Create joysticks in each player's zone
    final joystickRadius = 40.0;
    joysticks = List.generate(players.length, (i) {
      Vector2 center;
      if (i == 0) {
        // Bottom player - joystick at bottom-center
        center = Vector2(size.x / 2, size.y - joystickRadius - 20);
      } else {
        // Top player - joystick at top-center
        center = Vector2(size.x / 2, joystickRadius + 20);
      }
      return _Joystick(
        center: center,
        radius: joystickRadius,
        color: players[i].color,
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
    final ry = size.y * 0.30;

    for (int i = 0; i < cars.length; i++) {
      final car = cars[i];
      final joy = joysticks[i];

      final verticalInput = i == 0 ? -joy.delta.y : joy.delta.y;
      final horizontalInput = i == 0 ? joy.delta.x : -joy.delta.x;
      final movementInput = Vector2(horizontalInput, -verticalInput);
      car.speed = movementInput.length.clamp(0.0, 1.0) * _trackSpeed;

      // Check if car is on grass (outside track band)
      final dx = car.position.x - cx;
      final dy = car.position.y - cy;
      // Normalized distance from ellipse center line (1.0 = on the ellipse)
      final ellipseDist = sqrt((dx * dx) / (rx * rx) + (dy * dy) / (ry * ry));
      final trackHalfWidth = (_trackStrokeWidth / 2) / ((rx + ry) / 2);
      final onGrass = (ellipseDist - 1.0).abs() > trackHalfWidth;
      car.onGrass = onGrass;

      // Slow down on grass — 3× slower than normal.
      final effectiveSpeed = onGrass ? car.speed / 3.0 : car.speed;
      if (movementInput.length2 > 0) {
        final delta = movementInput.normalized() * effectiveSpeed * dt;
        car.position += delta;
        car.angle = atan2(delta.y, delta.x) + pi / 2;
      }

      car.position.x = car.position.x.clamp(_carHalfWidth, size.x - _carHalfWidth);
      car.position.y = car.position.y.clamp(_carHalfHeight, size.y - _carHalfHeight);

      final normalizedDx = (car.position.x - cx) / rx;
      final normalizedDy = (car.position.y - cy) / ry;
      final angleSample = atan2(normalizedDy, normalizedDx);
      final normalizedRadius = sqrt(
        normalizedDx * normalizedDx + normalizedDy * normalizedDy,
      );

      if (normalizedRadius > 0.35 && movementInput.length2 > 0) {
        final angleDelta = _normalizeAngleDelta(angleSample - car.lastAngleSample);
        if (angleDelta.abs() < 1.0) {
          car.unwrappedAngleProgress += angleDelta;
        }
      }
      car.lastAngleSample = angleSample;

      while (car.unwrappedAngleProgress >= (car.laps + 1) * 2 * pi) {
        car.laps++;
        if (car.laps >= lapsToWin) {
          _gameOver = true;
          for (int j = 0; j < players.length; j++) {
            players[j].score = cars[j].laps;
          }
          onGameEnd();
          return;
        }
      }
    }
  }

  double _normalizeAngleDelta(double delta) {
    while (delta > pi) {
      delta -= 2 * pi;
    }
    while (delta < -pi) {
      delta += 2 * pi;
    }
    return delta;
  }

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;

    for (int i = 0; i < joysticks.length; i++) {
      final dist = (pos - joysticks[i].center).length;
      if (dist < joysticks[i].radius + 20) {
        _dragToJoystick[pointerId] = i;
        break;
      }
    }

    // Also allow touching anywhere in zone to activate joystick
    if (!_dragToJoystick.containsKey(pointerId)) {
      for (int i = 0; i < players.length; i++) {
        final zone = _getPlayerZone(i);
        if (zone.contains(Offset(pos.x, pos.y))) {
          _dragToJoystick[pointerId] = i;
          break;
        }
      }
    }
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    if (_gameOver) return;
    final joyIdx = _dragToJoystick[pointerId];
    if (joyIdx == null) return;

    final pos = info.eventPosition.global;
    final joy = joysticks[joyIdx];
    final offset = pos - joy.center;
    final clamped = offset.length > joy.radius
        ? offset.normalized() * joy.radius
        : offset;

    joy.thumbPos = joy.center + clamped;
    joy.delta = Vector2(
      clamped.x / joy.radius,
      clamped.y / joy.radius,
    );
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    final joyIdx = _dragToJoystick.remove(pointerId);
    if (joyIdx != null) {
      joysticks[joyIdx].thumbPos = joysticks[joyIdx].center.clone();
      joysticks[joyIdx].delta = Vector2.zero();
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
    final ry = size.y * 0.30;

    // Track
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()
        ..color = const Color(0xFF555555)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _trackStrokeWidth,
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

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-_carHalfWidth, -_carHalfHeight, _carHalfWidth * 2, _carHalfHeight * 2),
          const Radius.circular(3),
        ),
        Paint()..color = car.color,
      );
      canvas.drawRect(
        const Rect.fromLTWH(2, -3, 4, 6),
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
      // Glow (green tint on grass)
      canvas.drawCircle(
        Offset.zero,
        10,
        Paint()
          ..color = (car.onGrass ? Colors.green : car.color).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      canvas.restore();
    }

    // Lap counters
    for (int i = 0; i < cars.length; i++) {
      final y = i == 0 ? size.y - 60.0 : 40.0;
      final tp = TextPainter(
        text: TextSpan(
          text: 'P${i + 1}: Lap ${cars[i].laps}/$lapsToWin',
          style: TextStyle(color: cars[i].color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(10, y));
    }

    // Joysticks
    for (final joy in joysticks) {
      // Base circle
      canvas.drawCircle(
        Offset(joy.center.x, joy.center.y),
        joy.radius,
        Paint()
          ..color = joy.color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(joy.center.x, joy.center.y),
        joy.radius,
        Paint()
          ..color = joy.color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      // Thumb
      canvas.drawCircle(
        Offset(joy.thumbPos.x, joy.thumbPos.y),
        16,
        Paint()..color = joy.color.withValues(alpha: 0.6),
      );
      canvas.drawCircle(
        Offset(joy.thumbPos.x, joy.thumbPos.y),
        16,
        Paint()
          ..color = joy.color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Zone divider
    canvas.drawLine(
      Offset(0, size.y / 2),
      Offset(size.x, size.y / 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 1,
    );
  }
}

class _RaceCar {
  Vector2 position;
  Color color;
  int playerId;
  double angle;
  double speed = 0;
  int laps = 0;
  double lastAngleSample;
  double unwrappedAngleProgress = 0;
  bool onGrass = false;

  _RaceCar({
    required this.position,
    required this.color,
    required this.playerId,
    required this.angle,
    required this.lastAngleSample,
  });
}

class _Joystick {
  final Vector2 center;
  final double radius;
  final Color color;
  late Vector2 thumbPos;
  Vector2 delta = Vector2.zero();

  _Joystick({
    required this.center,
    required this.radius,
    required this.color,
  }) {
    thumbPos = center.clone();
  }
}
