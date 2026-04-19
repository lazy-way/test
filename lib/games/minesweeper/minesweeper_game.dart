import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/player.dart';
import '../../core/models/game_result.dart';
import '../../core/widgets/game_wrapper.dart';

class MinesweeperGame extends StatelessWidget {
  final List<Player> players;

  const MinesweeperGame({super.key, required this.players});

  static Widget widget({required List<Player> players}) {
    final resultSummary = ValueNotifier<SoloGameSummary?>(null);
    return GameWrapper(
      gameName: 'Minesweeper',
      players: players,
      resultSummaryBuilder: () => resultSummary.value,
      gameBuilder: (onEnd) => _MinesweeperPlayArea(
        players: players,
        onGameEnd: onEnd,
        resultSummary: resultSummary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget(players: players);
}

enum _MinesweeperDifficulty {
  beginner('Beginner', 9, 9, 10, Color(0xFF4DD0E1)),
  intermediate('Intermediate', 12, 12, 22, Color(0xFFFFC857)),
  expert('Expert', 16, 16, 40, Color(0xFFFF6B6B));

  const _MinesweeperDifficulty(
    this.label,
    this.rows,
    this.columns,
    this.mines,
    this.color,
  );

  final String label;
  final int rows;
  final int columns;
  final int mines;
  final Color color;
}

class _MineCell {
  bool hasMine = false;
  bool revealed = false;
  bool flagged = false;
  bool question = false;
  bool exploded = false;
  int adjacentMines = 0;
}

class _MinesweeperPlayArea extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onGameEnd;
  final ValueNotifier<SoloGameSummary?> resultSummary;

  const _MinesweeperPlayArea({
    required this.players,
    required this.onGameEnd,
    required this.resultSummary,
  });

  @override
  State<_MinesweeperPlayArea> createState() => _MinesweeperPlayAreaState();
}

class _MinesweeperPlayAreaState extends State<_MinesweeperPlayArea> {
  final Random _random = Random();

  _MinesweeperDifficulty _difficulty = _MinesweeperDifficulty.beginner;
  late List<_MineCell> _cells;
  bool _firstTap = true;
  bool _flagMode = false;
  bool _paused = false;
  bool _gameOver = false;
  bool _won = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  int get _rows => _difficulty.rows;
  int get _columns => _difficulty.columns;
  int get _mineCount => _difficulty.mines;

  @override
  void initState() {
    super.initState();
    _startNewGame();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused && !_gameOver) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNewGame({_MinesweeperDifficulty? difficulty}) {
    final nextDifficulty = difficulty ?? _difficulty;
    setState(() {
      _difficulty = nextDifficulty;
      _cells = List.generate(_rows * _columns, (_) => _MineCell());
      _firstTap = true;
      _flagMode = false;
      _paused = false;
      _gameOver = false;
      _won = false;
      _elapsedSeconds = 0;
      widget.players[0].score = 0;
    });
    _publishSummary();
  }

  Iterable<int> _neighborsOf(int index) sync* {
    final row = index ~/ _columns;
    final col = index % _columns;
    for (int rowOffset = -1; rowOffset <= 1; rowOffset++) {
      for (int colOffset = -1; colOffset <= 1; colOffset++) {
        if (rowOffset == 0 && colOffset == 0) {
          continue;
        }
        final nextRow = row + rowOffset;
        final nextCol = col + colOffset;
        if (nextRow >= 0 && nextRow < _rows && nextCol >= 0 && nextCol < _columns) {
          yield nextRow * _columns + nextCol;
        }
      }
    }
  }

  void _placeMines(int safeIndex) {
    final forbidden = <int>{safeIndex, ..._neighborsOf(safeIndex)};
    final candidates = List<int>.generate(_cells.length, (index) => index)
      ..removeWhere(forbidden.contains)
      ..shuffle(_random);

    final fallbackCandidates = List<int>.generate(_cells.length, (index) => index)
      ..remove(safeIndex)
      ..shuffle(_random);

    final usable = candidates.length >= _mineCount ? candidates : fallbackCandidates;

    for (int i = 0; i < _mineCount; i++) {
      _cells[usable[i]].hasMine = true;
    }

    for (int index = 0; index < _cells.length; index++) {
      _cells[index].adjacentMines =
          _neighborsOf(index).where((neighbor) => _cells[neighbor].hasMine).length;
    }
  }

  void _onCellTap(int index) {
    if (_paused || _gameOver) {
      return;
    }

    final cell = _cells[index];
    if (_flagMode && !cell.revealed) {
      setState(() => _cycleMark(index));
      return;
    }
    if (cell.flagged) {
      return;
    }

    if (_firstTap) {
      _placeMines(index);
      _firstTap = false;
    }

    if (cell.revealed) {
      _chordReveal(index);
      return;
    }

    if (cell.hasMine) {
      setState(() {
        cell.exploded = true;
        _revealAllMines();
        _gameOver = true;
        widget.players[0].score = 0;
      });
      _publishSummary();
      widget.onGameEnd();
      return;
    }

    bool won = false;
    setState(() {
      _revealFrom(index);
      won = _checkForWin();
    });
    if (won) {
      widget.onGameEnd();
    }
  }

  void _onCellLongPress(int index) {
    if (_paused || _gameOver || _cells[index].revealed) {
      return;
    }
    setState(() => _cycleMark(index));
  }

  void _cycleMark(int index) {
    final cell = _cells[index];
    if (cell.revealed) {
      return;
    }
    if (!cell.flagged && !cell.question) {
      cell.flagged = true;
    } else if (cell.flagged) {
      cell.flagged = false;
      cell.question = true;
    } else {
      cell.question = false;
    }
  }

  void _revealFrom(int startIndex) {
    final queue = <int>[startIndex];
    while (queue.isNotEmpty) {
      final index = queue.removeLast();
      final cell = _cells[index];
      if (cell.revealed || cell.flagged) {
        continue;
      }
      cell.revealed = true;
      cell.question = false;
      if (cell.adjacentMines != 0) {
        continue;
      }
      for (final neighbor in _neighborsOf(index)) {
        if (!_cells[neighbor].revealed && !_cells[neighbor].hasMine) {
          queue.add(neighbor);
        }
      }
    }
  }

  void _chordReveal(int index) {
    final cell = _cells[index];
    if (!cell.revealed || cell.adjacentMines == 0) {
      return;
    }

    final neighbors = _neighborsOf(index).toList();
    final flaggedNeighbors = neighbors.where((neighbor) => _cells[neighbor].flagged).length;
    if (flaggedNeighbors != cell.adjacentMines) {
      return;
    }

    bool hitMine = false;
    for (final neighbor in neighbors) {
      final nextCell = _cells[neighbor];
      if (nextCell.flagged || nextCell.revealed) {
        continue;
      }
      if (nextCell.hasMine) {
        nextCell.exploded = true;
        hitMine = true;
      } else {
        _revealFrom(neighbor);
      }
    }

    bool won = false;
    setState(() {
      if (hitMine) {
        _revealAllMines();
        _gameOver = true;
        widget.players[0].score = 0;
      } else {
        won = _checkForWin();
      }
    });
    if (hitMine || won) {
      _publishSummary();
      widget.onGameEnd();
    }
  }

  void _revealAllMines() {
    for (final cell in _cells) {
      if (cell.hasMine) {
        cell.revealed = true;
      }
    }
  }

  bool _checkForWin() {
    final revealedSafeCount = _cells.where((cell) => cell.revealed && !cell.hasMine).length;
    final totalSafeCells = _cells.length - _mineCount;
    if (revealedSafeCount == totalSafeCells) {
      _won = true;
      _gameOver = true;
      _revealAllMines();
      widget.players[0].score = 1;
      return true;
    }
    return false;
  }

  void _publishSummary() {
    final clearedCells = _cells.where((cell) => cell.revealed && !cell.hasMine).length;
    final totalSafeCells = _cells.length - _mineCount;
    widget.resultSummary.value = SoloGameSummary(
      title: _won ? 'Board Cleared' : _gameOver ? 'Mine Triggered' : 'Minesweeper Run',
      subtitle: _won
          ? 'Completed on ${_difficulty.label}'
          : _gameOver
              ? 'A mine was revealed before the board was cleared'
              : 'Clear every safe cell and mark the mines',
      stats: [
        SoloGameStat(label: 'Difficulty', value: _difficulty.label),
        SoloGameStat(label: 'Time', value: _formatTime(_elapsedSeconds)),
        SoloGameStat(label: 'Cleared', value: '$clearedCells/$totalSafeCells'),
      ],
      color: _won ? const Color(0xFF7EE081) : _difficulty.color,
      icon: _won ? Icons.verified_rounded : Icons.flag_rounded,
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _numberColor(int count) {
    switch (count) {
      case 1:
        return const Color(0xFF3B82F6);
      case 2:
        return const Color(0xFF22C55E);
      case 3:
        return const Color(0xFFEF4444);
      case 4:
        return const Color(0xFF8B5CF6);
      case 5:
        return const Color(0xFFF97316);
      case 6:
        return const Color(0xFF14B8A6);
      case 7:
        return const Color(0xFFE5E7EB);
      default:
        return const Color(0xFFF472B6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flaggedCount = _cells.where((cell) => cell.flagged).length;
    final statusText = _won
        ? 'Board cleared'
        : _gameOver
            ? 'Mine triggered'
            : _flagMode
                ? 'Flag mode enabled'
                : 'Tap to reveal, hold to flag';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF13212B), Color(0xFF081117)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _MineStatCard(
                      label: _difficulty.label,
                      value: '${_rows}x$_columns',
                      color: _difficulty.color,
                      icon: Icons.grid_view_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MineStatCard(
                      label: 'Mines',
                      value: '${_mineCount - flaggedCount}',
                      color: const Color(0xFFFF6B6B),
                      icon: Icons.flag_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MineStatCard(
                      label: 'Time',
                      value: _formatTime(_elapsedSeconds),
                      color: const Color(0xFF4DD0E1),
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final difficulty in _MinesweeperDifficulty.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _MineChip(
                        label: difficulty.label,
                        color: difficulty.color,
                        selected: _difficulty == difficulty,
                        onTap: () => _startNewGame(difficulty: difficulty),
                      ),
                    ),
                  _MineChip(
                    label: _flagMode ? 'Reveal Mode' : 'Flag Mode',
                    color: const Color(0xFFFFC857),
                    selected: _flagMode,
                    onTap: () => setState(() => _flagMode = !_flagMode),
                  ),
                  const SizedBox(width: 8),
                  _MineChip(
                    label: _paused ? 'Resume' : 'Pause',
                    color: const Color(0xFF4DD0E1),
                    selected: _paused,
                    onTap: () => setState(() => _paused = !_paused),
                  ),
                  const SizedBox(width: 8),
                  _MineChip(
                    label: 'New Board',
                    color: const Color(0xFF7EE081),
                    selected: false,
                    onTap: _startNewGame,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  _paused ? 'Board paused' : statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _won
                        ? const Color(0xFF7EE081)
                        : _gameOver
                            ? const Color(0xFFFF9AA5)
                            : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Opacity(
                opacity: _paused ? 0.35 : 1,
                child: IgnorePointer(
                  ignoring: _paused,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cellSize = min(
                          constraints.maxWidth / _columns,
                          constraints.maxHeight / _rows,
                        );
                        final boardWidth = cellSize * _columns;
                        final boardHeight = cellSize * _rows;

                        return SingleChildScrollView(
                          child: Center(
                            child: Container(
                              width: boardWidth,
                              height: boardHeight,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF172733), Color(0xFF0A141C)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _difficulty.color.withValues(alpha: 0.2),
                                    blurRadius: 24,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _columns,
                                ),
                                itemCount: _cells.length,
                                itemBuilder: (context, index) {
                                  final cell = _cells[index];
                                  final revealed = cell.revealed;
                                  final showMine = cell.hasMine && (revealed || _gameOver);
                                  final tileColor = revealed
                                      ? cell.exploded
                                          ? const Color(0xFFFF6B6B)
                                          : const Color(0xFF0F1A20)
                                      : const Color(0xFF213746);

                                  return GestureDetector(
                                    onTap: () => _onCellTap(index),
                                    onLongPress: () => _onCellLongPress(index),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 120),
                                      margin: const EdgeInsets.all(1.3),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: LinearGradient(
                                          colors: revealed
                                              ? [tileColor, tileColor.withValues(alpha: 0.92)]
                                              : [const Color(0xFF325162), const Color(0xFF213746)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: revealed
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : Colors.white.withValues(alpha: 0.18),
                                        ),
                                        boxShadow: revealed
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.18),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                      ),
                                      child: Center(
                                        child: Builder(
                                          builder: (_) {
                                            if (cell.flagged && !revealed) {
                                              return const Icon(
                                                Icons.flag_rounded,
                                                color: Color(0xFFFF6B6B),
                                                size: 16,
                                              );
                                            }
                                            if (cell.question && !revealed) {
                                              return Text(
                                                '?',
                                                style: GoogleFonts.fredoka(
                                                  color: const Color(0xFFFFE7A3),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              );
                                            }
                                            if (showMine) {
                                              return Icon(
                                                Icons.circle,
                                                color: cell.exploded
                                                    ? Colors.black
                                                    : const Color(0xFFFFD166),
                                                size: 14,
                                              );
                                            }
                                            if (cell.adjacentMines > 0 && revealed) {
                                              return Text(
                                                '${cell.adjacentMines}',
                                                style: GoogleFonts.fredoka(
                                                  color: _numberColor(cell.adjacentMines),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (_paused)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  'Resume to continue clearing cells',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MineStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MineStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MineChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MineChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
