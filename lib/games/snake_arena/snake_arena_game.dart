import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class SnakeArenaGame extends FlameGame with MultiTouchDragDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;

  static const double cellSize = 15;
  late int gridW, gridH;
  late List<_Snake> snakes;
  late Vector2 food;
  double _moveTimer = 0;
  final double moveInterval = 0.15;
  bool _gameOver = false;
  final Map<int, int> _dragToPlayer = {};
  final Random _rng = Random();

  SnakeArenaGame({required this.players, required this.onGameEnd});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Snake Arena',
      players: players,
      gameBuilder: (onEnd) => GameWidget(
        game: SnakeArenaGame(players: players, onGameEnd: onEnd),
        backgroundBuilder: (context) => Container(color: const Color(0xFF0a1a0a)),
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    gridW = (size.x / cellSize).floor();
    gridH = (size.y / cellSize).floor();

    final startPositions = [
      Vector2(5.0, (gridH ~/ 2).toDouble()),
      Vector2(gridW - 6.0, (gridH ~/ 2).toDouble()),
      Vector2((gridW ~/ 2).toDouble(), 5.0),
      Vector2((gridW ~/ 2).toDouble(), gridH - 6.0),
    ];
    final startDirs = [
      Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
    ];

    snakes = List.generate(players.length, (i) => _Snake(
      segments: [startPositions[i].clone()],
      direction: startDirs[i].clone(),
      color: players[i].color,
      playerId: i,
    ));

    _spawnFood();
  }

  void _spawnFood() {
    final occupied = <String>{};
    for (final s in snakes) {
      for (final seg in s.segments) {
        occupied.add('${seg.x.toInt()},${seg.y.toInt()}');
      }
    }
    do {
      food = Vector2(_rng.nextInt(gridW).toDouble(), _rng.nextInt(gridH).toDouble());
    } while (occupied.contains('${food.x.toInt()},${food.y.toInt()}'));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    _moveTimer += dt;
    if (_moveTimer < moveInterval) return;
    _moveTimer = 0;

    for (final snake in snakes) {
      if (!snake.alive) continue;

      final head = snake.segments.last.clone();
      head.add(snake.direction);

      // Wall collision
      if (head.x < 0 || head.x >= gridW || head.y < 0 || head.y >= gridH) {
        snake.alive = false;
        continue;
      }

      // Self/other snake collision
      bool hit = false;
      for (final s in snakes) {
        if (!s.alive) continue;
        for (final seg in s.segments) {
          if (seg.x == head.x && seg.y == head.y) {
            hit = true;
            break;
          }
        }
        if (hit) break;
      }
      if (hit) {
        snake.alive = false;
        continue;
      }

      snake.segments.add(head);

      // Food
      if (head.x == food.x && head.y == food.y) {
        snake.score++;
        _spawnFood();
      } else {
        snake.segments.removeAt(0);
      }
    }

    _checkWin();
  }

  void _checkWin() {
    final alive = snakes.where((s) => s.alive).toList();
    if (alive.length <= 1) {
      _gameOver = true;
      for (int i = 0; i < players.length; i++) {
        players[i].score = snakes[i].alive ? snakes[i].score + 10 : snakes[i].score;
      }
      onGameEnd();
    }
  }

  @override
  void onDragStart(int pointerId, DragStartInfo info) {
    final pos = info.eventPosition.global;
    // Assign to player based on screen zone
    for (int i = 0; i < players.length; i++) {
      final zone = _getPlayerZone(i);
      if (zone.contains(Offset(pos.x, pos.y))) {
        _dragToPlayer[pointerId] = i;
        break;
      }
    }
  }

  @override
  void onDragUpdate(int pointerId, DragUpdateInfo info) {
    final playerIdx = _dragToPlayer[pointerId];
    if (playerIdx == null || !snakes[playerIdx].alive) return;

    final delta = info.delta.global;
    if (delta.length < 3) return;

    Vector2 newDir;
    if (delta.x.abs() > delta.y.abs()) {
      newDir = Vector2(delta.x > 0 ? 1 : -1, 0);
    } else {
      newDir = Vector2(0, delta.y > 0 ? 1 : -1);
    }

    // Prevent 180 turn
    if (newDir.x != -snakes[playerIdx].direction.x || newDir.y != -snakes[playerIdx].direction.y) {
      snakes[playerIdx].direction = newDir;
    }
  }

  @override
  void onDragEnd(int pointerId, DragEndInfo info) {
    _dragToPlayer.remove(pointerId);
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

    // Grid
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.03);
    for (int x = 0; x < gridW; x++) {
      for (int y = 0; y < gridH; y++) {
        if ((x + y) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
            gridPaint,
          );
        }
      }
    }

    // Food
    canvas.drawCircle(
      Offset(food.x * cellSize + cellSize / 2, food.y * cellSize + cellSize / 2),
      cellSize * 0.4,
      Paint()..color = Colors.red,
    );
    canvas.drawCircle(
      Offset(food.x * cellSize + cellSize / 2, food.y * cellSize + cellSize / 2),
      cellSize * 0.4,
      Paint()
        ..color = Colors.red.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Snakes
    for (final snake in snakes) {
      if (!snake.alive) continue;
      for (int i = 0; i < snake.segments.length; i++) {
        final seg = snake.segments[i];
        final isHead = i == snake.segments.length - 1;
        final opacity = 0.5 + 0.5 * (i / snake.segments.length);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(seg.x * cellSize + 1, seg.y * cellSize + 1, cellSize - 2, cellSize - 2),
            Radius.circular(isHead ? 4 : 2),
          ),
          Paint()..color = snake.color.withValues(alpha: opacity),
        );
        if (isHead) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(seg.x * cellSize + 1, seg.y * cellSize + 1, cellSize - 2, cellSize - 2),
              const Radius.circular(4),
            ),
            Paint()
              ..color = snake.color.withValues(alpha: 0.3)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
        }
      }
    }

    // Player zone borders
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < players.length; i++) {
      canvas.drawRect(_getPlayerZone(i), borderPaint);
    }
  }
}

class _Snake {
  List<Vector2> segments;
  Vector2 direction;
  Color color;
  int playerId;
  bool alive = true;
  int score = 0;

  _Snake({
    required this.segments,
    required this.direction,
    required this.color,
    required this.playerId,
  });
}
