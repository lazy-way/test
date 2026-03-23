import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';

class DiceWarGame extends StatelessWidget {
  final List<Player> players;
  const DiceWarGame({super.key, required this.players});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Dice War',
      players: players,
      gameBuilder: (onEnd) => _DiceWarArea(players: players, onGameEnd: onEnd),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget(players: players);
  }
}

class _DiceWarArea extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onGameEnd;
  const _DiceWarArea({required this.players, required this.onGameEnd});

  @override
  State<_DiceWarArea> createState() => _DiceWarAreaState();
}

class _DiceWarAreaState extends State<_DiceWarArea> with SingleTickerProviderStateMixin {
  static const gridSize = 6;
  late List<List<int>> owners; // player index, -1 = neutral
  late List<List<int>> strength; // dice count 1-6
  int currentPlayer = 0;
  int? selectedRow, selectedCol;
  String message = '';
  bool rolling = false;
  bool gameOver = false;
  int turnsLeft = 30;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    owners = List.generate(gridSize, (_) => List.filled(gridSize, -1));
    strength = List.generate(gridSize, (_) => List.filled(gridSize, 1));

    // Distribute territories
    final cells = <(int, int)>[];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        cells.add((r, c));
      }
    }
    cells.shuffle(_rng);

    for (int i = 0; i < cells.length; i++) {
      final (r, c) = cells[i];
      owners[r][c] = i % widget.players.length;
      strength[r][c] = 1 + _rng.nextInt(3);
    }
  }

  bool _isAdjacent(int r1, int c1, int r2, int c2) {
    return (r1 == r2 && (c1 - c2).abs() == 1) || (c1 == c2 && (r1 - r2).abs() == 1);
  }

  void _onCellTap(int row, int col) {
    if (rolling || gameOver) return;

    if (selectedRow == null) {
      // Select own territory
      if (owners[row][col] == currentPlayer && strength[row][col] > 1) {
        setState(() {
          selectedRow = row;
          selectedCol = col;
          message = 'Tap enemy territory to attack';
        });
      }
    } else {
      // Attack
      if (owners[row][col] != currentPlayer && _isAdjacent(selectedRow!, selectedCol!, row, col)) {
        _attack(selectedRow!, selectedCol!, row, col);
      }
      setState(() {
        selectedRow = null;
        selectedCol = null;
      });
    }
  }

  void _attack(int fromR, int fromC, int toR, int toC) {
    setState(() => rolling = true);

    // Roll dice
    int attackRoll = 0;
    for (int i = 0; i < strength[fromR][fromC]; i++) {
      attackRoll += 1 + _rng.nextInt(6);
    }
    int defenseRoll = 0;
    for (int i = 0; i < strength[toR][toC]; i++) {
      defenseRoll += 1 + _rng.nextInt(6);
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        if (attackRoll > defenseRoll) {
          owners[toR][toC] = currentPlayer;
          strength[toR][toC] = strength[fromR][fromC] - 1;
          strength[fromR][fromC] = 1;
          message = 'Attack won! ($attackRoll vs $defenseRoll)';
        } else {
          strength[fromR][fromC] = 1;
          message = 'Attack lost! ($attackRoll vs $defenseRoll)';
        }
        rolling = false;
        _endTurn();
      });
    });
  }

  void _endTurn() {
    turnsLeft--;

    // Check if any player has been eliminated
    final activePlayers = <int>{};
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (owners[r][c] >= 0) activePlayers.add(owners[r][c]);
      }
    }

    if (activePlayers.length <= 1 || turnsLeft <= 0) {
      gameOver = true;
      // Count territories
      for (int i = 0; i < widget.players.length; i++) {
        int count = 0;
        for (int r = 0; r < gridSize; r++) {
          for (int c = 0; c < gridSize; c++) {
            if (owners[r][c] == i) count++;
          }
        }
        widget.players[i].score = count;
      }
      widget.onGameEnd();
      return;
    }

    // Next player
    do {
      currentPlayer = (currentPlayer + 1) % widget.players.length;
    } while (!activePlayers.contains(currentPlayer));

    // Reinforce: add 1 strength to a random owned territory
    final owned = <(int, int)>[];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (owners[r][c] == currentPlayer && strength[r][c] < 6) {
          owned.add((r, c));
        }
      }
    }
    if (owned.isNotEmpty) {
      final (r, c) = owned[_rng.nextInt(owned.length)];
      strength[r][c]++;
    }
  }

  void _skipTurn() {
    if (rolling || gameOver) return;
    setState(() {
      selectedRow = null;
      selectedCol = null;
      message = '';
      _endTurn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = widget.players[currentPlayer].color;

    return Container(
      color: const Color(0xFF0a0a1e),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
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
                  Text('Turns: $turnsLeft', style: const TextStyle(color: Colors.white54)),
                  TextButton(
                    onPressed: _skipTurn,
                    child: const Text('SKIP', style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ),
            ),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            const SizedBox(height: 8),
            // Scores
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.players.length, (i) {
                int count = 0;
                for (int r = 0; r < gridSize; r++) {
                  for (int c = 0; c < gridSize; c++) {
                    if (owners[r][c] == i) count++;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.players[i].color)),
                      const SizedBox(width: 4),
                      Text('$count', style: TextStyle(color: widget.players[i].color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            // Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridSize,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: gridSize * gridSize,
                    itemBuilder: (context, index) {
                      final r = index ~/ gridSize;
                      final c = index % gridSize;
                      final owner = owners[r][c];
                      final str = strength[r][c];
                      final isSelected = r == selectedRow && c == selectedCol;
                      final color = owner >= 0 ? widget.players[owner].color : Colors.grey;

                      return GestureDetector(
                        onTap: () => _onCellTap(r, c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: color.withValues(alpha: isSelected ? 0.8 : 0.4),
                            border: Border.all(
                              color: isSelected ? Colors.white : color.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$str',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
