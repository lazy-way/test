import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';

class ColorMatchGame extends StatelessWidget {
  final List<Player> players;

  const ColorMatchGame({super.key, required this.players});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Color Match',
      players: players,
      gameBuilder: (onEnd) => _ColorMatchPlayArea(players: players, onGameEnd: onEnd),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget(players: players);
  }
}

class _ColorMatchPlayArea extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onGameEnd;

  const _ColorMatchPlayArea({required this.players, required this.onGameEnd});

  @override
  State<_ColorMatchPlayArea> createState() => _ColorMatchPlayAreaState();
}

class _ColorMatchPlayAreaState extends State<_ColorMatchPlayArea>
    with TickerProviderStateMixin {
  static const colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple, Colors.orange];
  static const colorNames = ['RED', 'BLUE', 'GREEN', 'YELLOW', 'PURPLE', 'ORANGE'];

  final Random _random = Random();
  int _round = 0;
  final int _totalRounds = 15;
  int _targetColorIndex = 0;
  List<int> _buttonColors = [];
  late List<int> _scores;
  bool _showTarget = false;
  bool _roundActive = false;
  bool _gameOver = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _scores = List.filled(widget.players.length, 0);
    // Delay first round to wait for GameWrapper's 3-2-1 countdown (~3.5s)
    Future.delayed(const Duration(milliseconds: 3800), () {
      if (mounted) {
        _started = true;
        _nextRound();
      }
    });
  }

  void _nextRound() {
    if (_round >= _totalRounds) {
      _gameOver = true;
      for (int i = 0; i < widget.players.length; i++) {
        widget.players[i].score = _scores[i];
      }
      widget.onGameEnd();
      return;
    }

    setState(() {
      _round++;
      _targetColorIndex = _random.nextInt(colors.length);
      _buttonColors = List.generate(4, (_) => _random.nextInt(colors.length));
      _buttonColors[_random.nextInt(4)] = _targetColorIndex;
      _showTarget = true;
      _roundActive = false;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && !_gameOver) {
        setState(() {
          _showTarget = false;
          _roundActive = true;
        });
      }
    });
  }

  void _onColorTap(int playerIndex, int buttonIndex) {
    if (!_roundActive || _gameOver) return;

    if (_buttonColors[buttonIndex] == _targetColorIndex) {
      setState(() {
        _scores[playerIndex] += 1;
        _roundActive = false;
      });
      Future.delayed(const Duration(milliseconds: 500), _nextRound);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerCount = widget.players.length;

    return Container(
      color: const Color(0xFF0a0a2e),
      child: SafeArea(
        child: Column(
          children: [
            // Round counter and scores
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _started ? 'Round $_round/$_totalRounds' : 'Get Ready...',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  ),
                  Row(
                    children: List.generate(playerCount, (i) => Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.players[i].color,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_scores[i]}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )),
                  ),
                ],
              ),
            ),

            // P2 buttons at TOP (rotated 180° for facing player)
            if (playerCount > 1)
              Expanded(
                flex: 3,
                child: Transform.rotate(
                  angle: pi,
                  child: _PlayerButtonZone(
                    playerIndex: 1,
                    playerColor: widget.players[1].color,
                    buttonColors: _buttonColors,
                    colors: colors,
                    onTap: (bi) => _onColorTap(1, bi),
                    active: _roundActive,
                  ),
                ),
              ),

            // Color flash in CENTER
            Expanded(
              flex: 2,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _showTarget ? colors[_targetColorIndex] : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _showTarget ? [
                      BoxShadow(
                        color: colors[_targetColorIndex].withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ] : [],
                  ),
                  child: Center(
                    child: Text(
                      !_started
                          ? ''
                          : _showTarget
                              ? colorNames[_targetColorIndex]
                              : '?',
                      style: GoogleFonts.fredoka(
                        fontWeight: FontWeight.w700,
                        fontSize: _showTarget ? 16 : 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // P1 buttons at BOTTOM (normal orientation)
            Expanded(
              flex: 3,
              child: _PlayerButtonZone(
                playerIndex: 0,
                playerColor: widget.players[0].color,
                buttonColors: _buttonColors,
                colors: colors,
                onTap: (bi) => _onColorTap(0, bi),
                active: _roundActive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerButtonZone extends StatelessWidget {
  final int playerIndex;
  final Color playerColor;
  final List<int> buttonColors;
  final List<Color> colors;
  final ValueChanged<int> onTap;
  final bool active;

  const _PlayerButtonZone({
    required this.playerIndex,
    required this.playerColor,
    required this.buttonColors,
    required this.colors,
    required this.onTap,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: playerColor.withValues(alpha: active ? 0.5 : 0.2),
          width: 2,
        ),
        color: playerColor.withValues(alpha: 0.05),
      ),
      child: buttonColors.isEmpty
          ? const SizedBox()
          : GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: List.generate(4, (i) {
                if (i >= buttonColors.length) return const SizedBox();
                return GestureDetector(
                  onTap: active ? () => onTap(i) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: active
                          ? colors[buttonColors[i]]
                          : colors[buttonColors[i]].withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: active ? [
                        BoxShadow(
                          color: colors[buttonColors[i]].withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ] : [],
                    ),
                  ),
                );
              }),
            ),
    );
  }
}
