import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';
import '../../app/theme.dart';

class BlockStackerGame extends StatelessWidget {
  final List<Player> players;
  const BlockStackerGame({super.key, required this.players});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Block Stacker',
      players: players,
      gameBuilder: (onEnd) => _BlockStackerArea(players: players, onGameEnd: onEnd),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget(players: players);
  }
}

class _BlockStackerArea extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onGameEnd;
  const _BlockStackerArea({required this.players, required this.onGameEnd});

  @override
  State<_BlockStackerArea> createState() => _BlockStackerAreaState();
}

class _BlockStackerAreaState extends State<_BlockStackerArea> {
  static const int gridRows = 15;
  static const int gridCols = 6;

  late List<List<List<bool>>> grids; // per player grid
  late List<double> blockPositions; // x position of current sliding block
  late List<int> blockWidths;
  late List<double> blockDirections;
  late List<int> currentRows; // current row being filled
  Timer? _timer;
  Timer? _gameTimer;
  double _timeLeft = 30;
  bool _gameOver = false;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    grids = List.generate(widget.players.length, (_) =>
      List.generate(gridRows, (_) => List.filled(gridCols, false)),
    );
    blockPositions = List.filled(widget.players.length, 0);
    blockWidths = List.filled(widget.players.length, 3);
    blockDirections = List.filled(widget.players.length, 1);
    currentRows = List.filled(widget.players.length, gridRows - 1);

    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_gameOver) return;
      setState(() {
        for (int i = 0; i < widget.players.length; i++) {
          blockPositions[i] += blockDirections[i] * 0.15;
          if (blockPositions[i] <= 0 || blockPositions[i] + blockWidths[i] >= gridCols) {
            blockDirections[i] = -blockDirections[i];
          }
          blockPositions[i] = blockPositions[i].clamp(0, gridCols - blockWidths[i].toDouble());
        }
      });
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_gameOver) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          _endGame();
        }
      });
    });
  }

  void _dropBlock(int playerIndex) {
    if (_gameOver) return;
    final row = currentRows[playerIndex];
    if (row < 0) return;

    setState(() {
      final startCol = blockPositions[playerIndex].round();
      final width = blockWidths[playerIndex];

      // Check overlap with previous row
      int placed = 0;
      for (int c = startCol; c < startCol + width && c < gridCols; c++) {
        if (c >= 0) {
          if (row == gridRows - 1 || grids[playerIndex][row + 1][c]) {
            grids[playerIndex][row][c] = true;
            placed++;
          }
        }
      }

      if (placed > 0 || row == gridRows - 1) {
        // Place on bottom row always works
        if (row == gridRows - 1) {
          for (int c = startCol; c < startCol + width && c < gridCols; c++) {
            if (c >= 0 && c < gridCols) grids[playerIndex][row][c] = true;
          }
          placed = width;
        }

        currentRows[playerIndex] = row - 1;
        blockWidths[playerIndex] = max(1, placed);
        blockPositions[playerIndex] = 0;
      }

      if (currentRows[playerIndex] < 0) {
        // Stack complete for this player
      }
    });
  }

  void _endGame() {
    _gameOver = true;
    _timer?.cancel();
    _gameTimer?.cancel();
    for (int i = 0; i < widget.players.length; i++) {
      int height = 0;
      for (int r = 0; r < gridRows; r++) {
        if (grids[i][r].any((c) => c)) {
          height = gridRows - r;
          break;
        }
      }
      widget.players[i].score = height;
    }
    widget.onGameEnd();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0a0a1e),
      child: SafeArea(
        child: Column(
          children: [
            // Timer
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${_timeLeft.ceil()}s',
                style: TextStyle(
                  color: _timeLeft < 10 ? Colors.red : Colors.white70,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Player grids
            Expanded(
              child: Column(
                children: List.generate(widget.players.length, (pi) => Expanded(
                  child: GestureDetector(
                    onTap: () => _dropBlock(pi),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: widget.players[pi].color.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cellW = constraints.maxWidth / gridCols;
                          final cellH = constraints.maxHeight / gridRows;

                          return Stack(
                            children: [
                              // Placed blocks
                              for (int r = 0; r < gridRows; r++)
                                for (int c = 0; c < gridCols; c++)
                                  if (grids[pi][r][c])
                                    Positioned(
                                      left: c * cellW,
                                      top: r * cellH,
                                      child: Container(
                                        width: cellW - 1,
                                        height: cellH - 1,
                                        decoration: BoxDecoration(
                                          color: widget.players[pi].color,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                              // Sliding block
                              if (currentRows[pi] >= 0)
                                Positioned(
                                  left: blockPositions[pi] * cellW,
                                  top: currentRows[pi] * cellH,
                                  child: Container(
                                    width: blockWidths[pi] * cellW - 1,
                                    height: cellH - 1,
                                    decoration: BoxDecoration(
                                      color: widget.players[pi].color.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              // Player label
                              Positioned(
                                bottom: 4,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Text(
                                    'P${pi + 1}',
                                    style: TextStyle(
                                      color: widget.players[pi].color.withValues(alpha: 0.3),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
