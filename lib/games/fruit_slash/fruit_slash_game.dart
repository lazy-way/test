import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class FruitSlashGame extends FlameGame with MultiTouchDragDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  final List<_Fruit> fruits = [];
  late List<int> scores;
  double _spawnTimer = 0;
  double _gameTime = 60;
  bool _gameOver = false;
  final Random _rng = Random();
  final Map<int, List<Offset>> _trails = {};

  FruitSlashGame({required this.players, required this.onGameEnd});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Fruit Slash',
      players: players,
      gameBuilder: (onEnd) => GameWidget(
        game: FruitSlashGame(players: players, onGameEnd: onEnd),
        backgroundBuilder: (context) => Container(color: const Color(0xFF1a0a2e)),
      ),
    );
  }

  static const fruitColors = [Colors.red, Colors.orange, Colors.green, Colors.yellow, Colors.purple];
  static const fruitEmojis = ['●', '●', '●', '●', '●'];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    scores = List.filled(players.length, 0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    _gameTime -= dt;
    if (_gameTime <= 0) {
      _gameOver = true;
      for (int i = 0; i < players.length; i++) {
        players[i].score = scores[i];
      }
      onGameEnd();
      return;
    }

    // Spawn fruits
    _spawnTimer += dt;
    if (_spawnTimer > 0.4) {
      _spawnTimer = 0;
      _spawnFruit();
    }

    // Update fruits
    for (final fruit in List.from(fruits)) {
      fruit.position += fruit.velocity * dt;
      fruit.velocity.y += 400 * dt; // Gravity
      fruit.rotation += fruit.rotSpeed * dt;

      if (fruit.position.y > size.y + 50) {
        fruits.remove(fruit);
      }
    }
  }

  void _spawnFruit() {
    final x = 50 + _rng.nextDouble() * (size.x - 100);
    final isBomb = _rng.nextDouble() < 0.15;

    fruits.add(_Fruit(
      position: Vector2(x, size.y + 20),
      velocity: Vector2((_rng.nextDouble() - 0.5) * 100, -500 - _rng.nextDouble() * 200),
      radius: 20 + _rng.nextDouble() * 10,
      color: isBomb ? Colors.black : fruitColors[_rng.nextInt(fruitColors.length)],
      isBomb: isBomb,
      rotation: 0,
      rotSpeed: (_rng.nextDouble() - 0.5) * 5,
    ));
  }

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    _trails[pointerId] = [Offset(info.eventPosition.global.x, info.eventPosition.global.y)];
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;
    _trails[pointerId]?.add(Offset(pos.x, pos.y));

    // Check fruit hits
    for (final fruit in List.from(fruits)) {
      if (fruit.slashed) continue;
      final dist = (fruit.position - pos).length;
      if (dist < fruit.radius + 10) {
        fruit.slashed = true;
        final playerIdx = _getPlayerForPos(pos);
        if (fruit.isBomb) {
          scores[playerIdx] = max(0, scores[playerIdx] - 3);
        } else {
          scores[playerIdx]++;
        }
        // Keep fruit for visual but mark slashed
        Future.delayed(const Duration(milliseconds: 200), () {
          fruits.remove(fruit);
        });
      }
    }
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    _trails.remove(pointerId);
  }

  int _getPlayerForPos(Vector2 pos) {
    for (int i = 0; i < players.length; i++) {
      final zone = _getPlayerZone(i);
      if (zone.contains(Offset(pos.x, pos.y))) return i;
    }
    return 0;
  }

  Rect _getPlayerZone(int index) {
    switch (players.length) {
      case 1: return Rect.fromLTWH(0, 0, size.x, size.y);
      case 2:
        return index == 0
            ? Rect.fromLTWH(0, size.y / 2, size.x, size.y / 2)  // Bottom
            : Rect.fromLTWH(0, 0, size.x, size.y / 2);           // Top
      default:
        return Rect.fromLTWH(0, 0, size.x, size.y);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Zone borders
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < players.length; i++) {
      canvas.drawRect(_getPlayerZone(i), borderPaint);
    }

    // Fruits
    for (final fruit in fruits) {
      canvas.save();
      canvas.translate(fruit.position.x, fruit.position.y);
      canvas.rotate(fruit.rotation);

      if (fruit.slashed) {
        // Slashed effect
        canvas.drawCircle(Offset.zero, fruit.radius, Paint()..color = fruit.color.withValues(alpha: 0.3));
        canvas.drawLine(
          Offset(-fruit.radius, 0),
          Offset(fruit.radius, 0),
          Paint()..color = Colors.white..strokeWidth = 2,
        );
      } else {
        canvas.drawCircle(Offset.zero, fruit.radius, Paint()..color = fruit.color);
        if (fruit.isBomb) {
          // Bomb fuse
          canvas.drawLine(
            Offset(0, -fruit.radius),
            Offset(5, -fruit.radius - 8),
            Paint()..color = Colors.orange..strokeWidth = 2,
          );
          canvas.drawCircle(
            Offset(5, -fruit.radius - 8), 3,
            Paint()..color = Colors.red,
          );
        }
        canvas.drawCircle(
          Offset.zero,
          fruit.radius,
          Paint()
            ..color = fruit.color.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.restore();
    }

    // Slash trails
    for (final trail in _trails.values) {
      if (trail.length < 2) continue;
      final path = Path()..moveTo(trail.first.dx, trail.first.dy);
      for (int i = 1; i < trail.length; i++) {
        path.lineTo(trail[i].dx, trail[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      // Trim trail
      if (trail.length > 10) trail.removeRange(0, trail.length - 10);
    }

    // Timer
    final timerText = TextPainter(
      text: TextSpan(
        text: '${_gameTime.ceil()}s',
        style: TextStyle(
          color: _gameTime < 10 ? Colors.red : Colors.white70,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    timerText.layout();
    timerText.paint(canvas, Offset(size.x / 2 - timerText.width / 2, 10));

    // Scores
    for (int i = 0; i < players.length; i++) {
      final zone = _getPlayerZone(i);
      final scoreText = TextPainter(
        text: TextSpan(
          text: '${scores[i]}',
          style: TextStyle(color: players[i].color.withValues(alpha: 0.5), fontSize: 48, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      scoreText.layout();
      scoreText.paint(canvas, Offset(
        zone.center.dx - scoreText.width / 2,
        zone.center.dy - scoreText.height / 2,
      ));
    }
  }
}

class _Fruit {
  Vector2 position;
  Vector2 velocity;
  double radius;
  Color color;
  bool isBomb;
  double rotation;
  double rotSpeed;
  bool slashed = false;

  _Fruit({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.color,
    required this.isBomb,
    required this.rotation,
    required this.rotSpeed,
  });
}
