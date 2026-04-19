import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/player.dart';
import '../../core/models/game_result.dart';
import '../../core/widgets/game_wrapper.dart';

class SudokuGame extends StatelessWidget {
  final List<Player> players;

  const SudokuGame({super.key, required this.players});

  static Widget widget({required List<Player> players}) {
    final resultSummary = ValueNotifier<SoloGameSummary?>(null);
    return GameWrapper(
      gameName: 'Sudoku',
      players: players,
      resultSummaryBuilder: () => resultSummary.value,
      gameBuilder: (onEnd) => _SudokuPlayArea(
        players: players,
        onGameEnd: onEnd,
        resultSummary: resultSummary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget(players: players);
}

enum _SudokuDifficulty {
  easy('Easy', 40, Color(0xFF5DD39E)),
  medium('Medium', 32, Color(0xFFF4B942)),
  hard('Hard', 26, Color(0xFFF45B69));

  const _SudokuDifficulty(this.label, this.givens, this.color);

  final String label;
  final int givens;
  final Color color;
}

class _SudokuPlayArea extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onGameEnd;
  final ValueNotifier<SoloGameSummary?> resultSummary;

  const _SudokuPlayArea({
    required this.players,
    required this.onGameEnd,
    required this.resultSummary,
  });

  @override
  State<_SudokuPlayArea> createState() => _SudokuPlayAreaState();
}

class _SudokuPlayAreaState extends State<_SudokuPlayArea> {
  static const int _boardSize = 9;

  final Random _random = Random();
  late List<int> _givens;
  late List<int> _solution;
  late List<int> _values;
  late List<Set<int>> _notes;

  _SudokuDifficulty _difficulty = _SudokuDifficulty.medium;
  int _selectedIndex = 0;
  int _elapsedSeconds = 0;
  int _mistakes = 0;
  bool _noteMode = false;
  bool _completed = false;
  bool _paused = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startNewGame();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused && !_completed) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNewGame({_SudokuDifficulty? difficulty}) {
    final nextDifficulty = difficulty ?? _difficulty;
    final solution = _generateSolvedBoard();
    final puzzle = _createPuzzle(solution, nextDifficulty.givens);

    setState(() {
      _difficulty = nextDifficulty;
      _solution = solution;
      _givens = List<int>.from(puzzle);
      _values = List<int>.from(puzzle);
      _notes = List.generate(_boardSize * _boardSize, (_) => <int>{});
      _elapsedSeconds = 0;
      _mistakes = 0;
      _noteMode = false;
      _completed = false;
      _paused = false;
      _selectedIndex = _firstEditableIndex();
      widget.players[0].score = 0;
    });
    _publishSummary();
  }

  void _restartPuzzle() {
    setState(() {
      _values = List<int>.from(_givens);
      _notes = List.generate(_boardSize * _boardSize, (_) => <int>{});
      _elapsedSeconds = 0;
      _mistakes = 0;
      _noteMode = false;
      _completed = false;
      _paused = false;
      _selectedIndex = _firstEditableIndex();
      widget.players[0].score = 0;
    });
    _publishSummary();
  }

  int _firstEditableIndex() {
    final index = _givens.indexWhere((value) => value == 0);
    return index == -1 ? 0 : index;
  }

  List<int> _generateSolvedBoard() {
    const base = 3;
    const side = base * base;

    int pattern(int row, int col) => (base * (row % base) + row ~/ base + col) % side;

    List<int> shuffled(List<int> source) {
      final values = List<int>.from(source);
      values.shuffle(_random);
      return values;
    }

    final rows = <int>[];
    final cols = <int>[];
    for (final group in shuffled([0, 1, 2])) {
      for (final row in shuffled([0, 1, 2])) {
        rows.add(group * base + row);
      }
    }
    for (final group in shuffled([0, 1, 2])) {
      for (final col in shuffled([0, 1, 2])) {
        cols.add(group * base + col);
      }
    }

    final numbers = shuffled([1, 2, 3, 4, 5, 6, 7, 8, 9]);
    final board = List<int>.filled(side * side, 0);
    for (int row = 0; row < side; row++) {
      for (int col = 0; col < side; col++) {
        board[row * side + col] = numbers[pattern(rows[row], cols[col])];
      }
    }
    return board;
  }

  List<int> _createPuzzle(List<int> solution, int givens) {
    final puzzle = List<int>.from(solution);
    final positions = List<int>.generate(solution.length, (index) => index)..shuffle(_random);

    for (final index in positions) {
      if (puzzle.where((value) => value != 0).length <= givens) {
        break;
      }
      final backup = puzzle[index];
      puzzle[index] = 0;
      if (_countSolutions(List<int>.from(puzzle), limit: 2) != 1) {
        puzzle[index] = backup;
      }
    }
    return puzzle;
  }

  int _countSolutions(List<int> board, {int limit = 2}) {
    int count = 0;

    bool solve() {
      int bestIndex = -1;
      List<int> bestCandidates = [];

      for (int index = 0; index < board.length; index++) {
        if (board[index] != 0) {
          continue;
        }
        final candidates = _candidatesFor(board, index);
        if (candidates.isEmpty) {
          return false;
        }
        if (bestIndex == -1 || candidates.length < bestCandidates.length) {
          bestIndex = index;
          bestCandidates = candidates;
          if (candidates.length == 1) {
            break;
          }
        }
      }

      if (bestIndex == -1) {
        count++;
        return count < limit;
      }

      for (final candidate in bestCandidates) {
        board[bestIndex] = candidate;
        final shouldContinue = solve();
        board[bestIndex] = 0;
        if (!shouldContinue) {
          return false;
        }
      }
      return true;
    }

    solve();
    return count;
  }

  List<int> _candidatesFor(List<int> board, int index) {
    final row = index ~/ _boardSize;
    final col = index % _boardSize;
    final used = <int>{};

    for (int offset = 0; offset < _boardSize; offset++) {
      used.add(board[row * _boardSize + offset]);
      used.add(board[offset * _boardSize + col]);
    }

    final startRow = (row ~/ 3) * 3;
    final startCol = (col ~/ 3) * 3;
    for (int boxRow = startRow; boxRow < startRow + 3; boxRow++) {
      for (int boxCol = startCol; boxCol < startCol + 3; boxCol++) {
        used.add(board[boxRow * _boardSize + boxCol]);
      }
    }

    return List<int>.generate(9, (index) => index + 1)
        .where((digit) => !used.contains(digit))
        .toList();
  }

  void _selectCell(int index) {
    if (_paused) {
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _handleDigit(int digit) {
    if (_paused || _completed || _givens[_selectedIndex] != 0) {
      return;
    }

    setState(() {
      if (_noteMode) {
        if (_notes[_selectedIndex].contains(digit)) {
          _notes[_selectedIndex].remove(digit);
        } else {
          _notes[_selectedIndex].add(digit);
        }
        return;
      }

      final previous = _values[_selectedIndex];
      _values[_selectedIndex] = digit;
      _notes[_selectedIndex].clear();
      if (previous != digit && digit != _solution[_selectedIndex]) {
        _mistakes++;
      }
    });

    _checkCompletion();
  }

  void _eraseSelected() {
    if (_paused || _completed || _givens[_selectedIndex] != 0) {
      return;
    }

    setState(() {
      _values[_selectedIndex] = 0;
      _notes[_selectedIndex].clear();
    });
  }

  void _checkCompletion() {
    if (_values.contains(0)) {
      return;
    }
    if (_conflictingIndexes().isNotEmpty) {
      return;
    }
    if (!_listEquals(_values, _solution)) {
      return;
    }

    setState(() {
      _completed = true;
      widget.players[0].score = 1;
    });
    _publishSummary();
    widget.onGameEnd();
  }

  void _publishSummary() {
    widget.resultSummary.value = SoloGameSummary(
      title: _completed ? 'Puzzle Solved' : 'Sudoku Session',
      subtitle: _completed
          ? 'Completed on ${_difficulty.label} difficulty'
          : 'Keep filling the grid without duplicates',
      stats: [
        SoloGameStat(label: 'Difficulty', value: _difficulty.label),
        SoloGameStat(label: 'Time', value: _formatTime(_elapsedSeconds)),
        SoloGameStat(label: 'Mistakes', value: '$_mistakes'),
      ],
      color: _difficulty.color,
      icon: _completed ? Icons.auto_awesome_rounded : Icons.grid_on_rounded,
    );
  }

  bool _listEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  Set<int> _conflictingIndexes() {
    final conflicts = <int>{};

    void collectConflict(List<int> indexes) {
      final groups = <int, List<int>>{};
      for (final index in indexes) {
        final value = _values[index];
        if (value == 0) {
          continue;
        }
        groups.putIfAbsent(value, () => <int>[]).add(index);
      }
      for (final duplicate in groups.values.where((group) => group.length > 1)) {
        conflicts.addAll(duplicate);
      }
    }

    for (int row = 0; row < _boardSize; row++) {
      collectConflict(List<int>.generate(_boardSize, (col) => row * _boardSize + col));
    }
    for (int col = 0; col < _boardSize; col++) {
      collectConflict(List<int>.generate(_boardSize, (row) => row * _boardSize + col));
    }
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        final indexes = <int>[];
        for (int row = boxRow * 3; row < boxRow * 3 + 3; row++) {
          for (int col = boxCol * 3; col < boxCol * 3 + 3; col++) {
            indexes.add(row * _boardSize + col);
          }
        }
        collectConflict(indexes);
      }
    }

    return conflicts;
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedRow = _selectedIndex ~/ _boardSize;
    final selectedCol = _selectedIndex % _boardSize;
    final selectedValue = _values[_selectedIndex];
    final conflicts = _conflictingIndexes();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101B32), Color(0xFF08111F)],
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
                    child: _StatCard(
                      label: _difficulty.label,
                      value: 'Sudoku 9x9',
                      color: _difficulty.color,
                      icon: Icons.extension_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Time',
                      value: _formatTime(_elapsedSeconds),
                      color: const Color(0xFF58C4DD),
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Mistakes',
                      value: '$_mistakes',
                      color: const Color(0xFFF45B69),
                      icon: Icons.priority_high_rounded,
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
                  for (final difficulty in _SudokuDifficulty.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ChipButton(
                        label: difficulty.label,
                        color: difficulty.color,
                        selected: _difficulty == difficulty,
                        onTap: () => _startNewGame(difficulty: difficulty),
                      ),
                    ),
                  _ChipButton(
                    label: 'Restart',
                    color: const Color(0xFF7E8AA2),
                    selected: false,
                    onTap: _restartPuzzle,
                  ),
                  const SizedBox(width: 8),
                  _ChipButton(
                    label: _paused ? 'Resume' : 'Pause',
                    color: const Color(0xFF58C4DD),
                    selected: _paused,
                    onTap: () => setState(() => _paused = !_paused),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Opacity(
                opacity: _paused ? 0.35 : 1,
                child: IgnorePointer(
                  ignoring: _paused,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardSize = min(constraints.maxWidth, constraints.maxHeight * 0.72);
                        return Column(
                          children: [
                            Center(
                              child: Container(
                                width: boardSize,
                                height: boardSize,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF16243C), Color(0xFF0B1426)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _difficulty.color.withValues(alpha: 0.18),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 9,
                                  ),
                                  itemCount: 81,
                                  itemBuilder: (context, index) {
                                    final row = index ~/ _boardSize;
                                    final col = index % _boardSize;
                                    final value = _values[index];
                                    final isGiven = _givens[index] != 0;
                                    final isSelected = index == _selectedIndex;
                                    final isConflict = conflicts.contains(index);
                                    final sameGroup = row == selectedRow || col == selectedCol;
                                    final sameBox = row ~/ 3 == selectedRow ~/ 3 &&
                                        col ~/ 3 == selectedCol ~/ 3;
                                    final sameValue = selectedValue != 0 && value == selectedValue;
                                    final backgroundColor = isSelected
                                        ? _difficulty.color.withValues(alpha: 0.35)
                                        : isConflict
                                            ? const Color(0xFFF45B69).withValues(alpha: 0.24)
                                            : sameValue
                                                ? Colors.white.withValues(alpha: 0.16)
                                                : sameGroup || sameBox
                                                    ? Colors.white.withValues(alpha: 0.08)
                                                    : Colors.transparent;

                                    return GestureDetector(
                                      onTap: () => _selectCell(index),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: backgroundColor,
                                          border: Border(
                                            top: BorderSide(
                                              color: row % 3 == 0
                                                  ? Colors.white.withValues(alpha: 0.7)
                                                  : Colors.white.withValues(alpha: 0.12),
                                              width: row % 3 == 0 ? 2.2 : 0.8,
                                            ),
                                            left: BorderSide(
                                              color: col % 3 == 0
                                                  ? Colors.white.withValues(alpha: 0.7)
                                                  : Colors.white.withValues(alpha: 0.12),
                                              width: col % 3 == 0 ? 2.2 : 0.8,
                                            ),
                                            right: BorderSide(
                                              color: col == 8
                                                  ? Colors.white.withValues(alpha: 0.7)
                                                  : Colors.white.withValues(alpha: 0.08),
                                              width: col == 8 ? 2.2 : 0.8,
                                            ),
                                            bottom: BorderSide(
                                              color: row == 8
                                                  ? Colors.white.withValues(alpha: 0.7)
                                                  : Colors.white.withValues(alpha: 0.08),
                                              width: row == 8 ? 2.2 : 0.8,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: value != 0
                                              ? Text(
                                                  '$value',
                                                  style: GoogleFonts.fredoka(
                                                    fontSize: isGiven ? 24 : 22,
                                                    fontWeight: FontWeight.w600,
                                                    color: isConflict
                                                        ? const Color(0xFFFFD0D4)
                                                        : isGiven
                                                            ? Colors.white
                                                            : _difficulty.color,
                                                  ),
                                                )
                                              : _notes[index].isEmpty
                                                  ? const SizedBox.shrink()
                                                  : Padding(
                                                      padding: const EdgeInsets.all(2),
                                                      child: GridView.count(
                                                        physics:
                                                            const NeverScrollableScrollPhysics(),
                                                        crossAxisCount: 3,
                                                        children: List.generate(9, (digitIndex) {
                                                          final digit = digitIndex + 1;
                                                          return Center(
                                                            child: Text(
                                                              _notes[index].contains(digit)
                                                                  ? '$digit'
                                                                  : '',
                                                              style: TextStyle(
                                                                fontSize: 8.5,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.white.withValues(
                                                                  alpha: 0.72,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        }),
                                                      ),
                                                    ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _paused
                                          ? 'Puzzle paused'
                                          : _givens[_selectedIndex] != 0
                                              ? 'Given clue selected'
                                              : _noteMode
                                                  ? 'Note mode on'
                                                  : conflicts.isNotEmpty
                                                      ? 'Duplicate detected'
                                                      : 'Fill the grid without conflicts',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  TextButton(
                                    onPressed: _checkCompletion,
                                    child: Text(
                                      'Check',
                                      style: TextStyle(
                                        color: _difficulty.color,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildPad(),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (_paused)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Resume to continue solving',
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

  Widget _buildPad() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF111C33), Color(0xFF0B1422)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: List.generate(9, (index) {
              final digit = index + 1;
              return _PadButton(
                label: '$digit',
                color: _difficulty.color,
                onTap: () => _handleDigit(digit),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PadButton(
                  label: _noteMode ? 'Notes On' : 'Notes',
                  color: _noteMode ? _difficulty.color : const Color(0xFF7E8AA2),
                  expanded: true,
                  onTap: () => setState(() => _noteMode = !_noteMode),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PadButton(
                  label: 'Erase',
                  color: const Color(0xFFF45B69),
                  expanded: true,
                  onTap: _eraseSelected,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
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
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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

class _ChipButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ChipButton({
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
          color: selected ? color.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.05),
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

class _PadButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;

  const _PadButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: expanded ? null : 54,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: expanded ? 16 : 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
