import 'package:flutter/material.dart';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class DotCaptureGame extends StatelessWidget {
  final List<Player> players;
  const DotCaptureGame({super.key, required this.players});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Dot Capture',
      players: players,
      gameBuilder: (onEnd) => _DotCaptureArea(players: players, onGameEnd: onEnd),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget(players: players);
  }
}

class _DotCaptureArea extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onGameEnd;
  const _DotCaptureArea({required this.players, required this.onGameEnd});

  @override
  State<_DotCaptureArea> createState() => _DotCaptureAreaState();
}

class _DotCaptureAreaState extends State<_DotCaptureArea> {
  static const int gridSize = 5; // 5x5 dots = 4x4 boxes

  // Horizontal lines: gridSize rows of (gridSize-1) lines
  late List<List<int>> hLines; // -1 = not drawn, player index if drawn
  // Vertical lines: (gridSize-1) rows of gridSize lines
  late List<List<int>> vLines;
  // Boxes: (gridSize-1) x (gridSize-1)
  late List<List<int>> boxes; // -1 = unclaimed

  int currentPlayer = 0;
  late List<int> scores;
  bool gameOver = false;

  @override
  void initState() {
    super.initState();
    hLines = List.generate(gridSize, (_) => List.filled(gridSize - 1, -1));
    vLines = List.generate(gridSize - 1, (_) => List.filled(gridSize, -1));
    boxes = List.generate(gridSize - 1, (_) => List.filled(gridSize - 1, -1));
    scores = List.filled(widget.players.length, 0);
  }

  void _drawHLine(int row, int col) {
    if (hLines[row][col] != -1 || gameOver) return;

    setState(() {
      hLines[row][col] = currentPlayer;
      bool scored = _checkBoxes();
      if (!scored) {
        currentPlayer = (currentPlayer + 1) % widget.players.length;
      }
      _checkGameOver();
    });
  }

  void _drawVLine(int row, int col) {
    if (vLines[row][col] != -1 || gameOver) return;

    setState(() {
      vLines[row][col] = currentPlayer;
      bool scored = _checkBoxes();
      if (!scored) {
        currentPlayer = (currentPlayer + 1) % widget.players.length;
      }
      _checkGameOver();
    });
  }

  bool _checkBoxes() {
    bool scored = false;
    for (int r = 0; r < gridSize - 1; r++) {
      for (int c = 0; c < gridSize - 1; c++) {
        if (boxes[r][c] == -1 &&
            hLines[r][c] != -1 && hLines[r + 1][c] != -1 &&
            vLines[r][c] != -1 && vLines[r][c + 1] != -1) {
          boxes[r][c] = currentPlayer;
          scores[currentPlayer]++;
          scored = true;
        }
      }
    }
    return scored;
  }

  void _checkGameOver() {
    bool allFilled = true;
    for (int r = 0; r < gridSize - 1; r++) {
      for (int c = 0; c < gridSize - 1; c++) {
        if (boxes[r][c] == -1) allFilled = false;
      }
    }
    if (allFilled) {
      gameOver = true;
      for (int i = 0; i < widget.players.length; i++) {
        widget.players[i].score = scores[i];
      }
      widget.onGameEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = widget.players[currentPlayer].color;

    return Container(
      color: const Color(0xFF0a0a2e),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: currentColor.withValues(alpha: 0.3),
                      border: Border.all(color: currentColor),
                    ),
                    child: Text('P${currentPlayer + 1}\'s Turn', style: TextStyle(color: currentColor, fontWeight: FontWeight.bold)),
                  ),
                  Row(
                    children: List.generate(widget.players.length, (i) => Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.players[i].color)),
                          const SizedBox(width: 4),
                          Text('${scores[i]}', style: TextStyle(color: widget.players[i].color, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    )),
                  ),
                ],
              ),
            ),
            // Game grid
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cellSize = constraints.maxWidth / (gridSize - 1);

                        return Stack(
                          children: [
                            // Boxes
                            for (int r = 0; r < gridSize - 1; r++)
                              for (int c = 0; c < gridSize - 1; c++)
                                if (boxes[r][c] != -1)
                                  Positioned(
                                    left: c * cellSize + 2,
                                    top: r * cellSize + 2,
                                    child: Container(
                                      width: cellSize - 4,
                                      height: cellSize - 4,
                                      color: widget.players[boxes[r][c]].color.withValues(alpha: 0.3),
                                    ),
                                  ),
                            // Horizontal lines (tappable)
                            for (int r = 0; r < gridSize; r++)
                              for (int c = 0; c < gridSize - 1; c++)
                                Positioned(
                                  left: c * cellSize + 8,
                                  top: r * cellSize - 8,
                                  child: GestureDetector(
                                    onTap: () => _drawHLine(r, c),
                                    child: Container(
                                      width: cellSize - 16,
                                      height: 16,
                                      color: hLines[r][c] != -1
                                          ? widget.players[hLines[r][c]].color
                                          : Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                            // Vertical lines (tappable)
                            for (int r = 0; r < gridSize - 1; r++)
                              for (int c = 0; c < gridSize; c++)
                                Positioned(
                                  left: c * cellSize - 8,
                                  top: r * cellSize + 8,
                                  child: GestureDetector(
                                    onTap: () => _drawVLine(r, c),
                                    child: Container(
                                      width: 16,
                                      height: cellSize - 16,
                                      color: vLines[r][c] != -1
                                          ? widget.players[vLines[r][c]].color
                                          : Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                            // Dots
                            for (int r = 0; r < gridSize; r++)
                              for (int c = 0; c < gridSize; c++)
                                Positioned(
                                  left: c * cellSize - 6,
                                  top: r * cellSize - 6,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
