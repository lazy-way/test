import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';
import '../../app/theme.dart';
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
  bool _showTarget = true;
  bool _roundActive = false;
  bool _gameOver = false;

  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _scores = List.filled(widget.players.length, 0);
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );
    _nextRound();
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
      // Ensure target is in the buttons
      _buttonColors[_random.nextInt(4)] = _targetColorIndex;
      _showTarget = true;
      _roundActive = false;
    });

    _flashController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 1000), () {
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
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0a0a2e),
      child: SafeArea(
        child: Column(
          children: [
            // Round counter and scores
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Round $_round/$_totalRounds',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
                  ),
                  Row(
                    children: List.generate(widget.players.length, (i) => Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
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

            // Target display
            Expanded(
              flex: 2,
              child: Center(
                child: AnimatedBuilder(
                  animation: _flashController,
                  builder: (context, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _showTarget ? colors[_targetColorIndex] : Colors.white24,
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
                          _showTarget ? colorNames[_targetColorIndex] : '?',
                          style: GoogleFonts.fredoka(fontWeight: FontWeight.w700,
                            fontSize: _showTarget ? 18 : 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Player zones with buttons
            Expanded(
              flex: 3,
              child: Column(
                      children: List.generate(widget.players.length, (playerIdx) {
                        final zone = _PlayerButtonZone(
                          playerIndex: playerIdx,
                          playerColor: widget.players[playerIdx].color,
                          buttonColors: _buttonColors,
                          colors: colors,
                          onTap: (bi) => _onColorTap(playerIdx, bi),
                          active: _roundActive,
                        );
                        return Expanded(
                          child: (playerIdx == 1 && widget.players.length == 2)
                              ? Transform.rotate(angle: pi, child: zone)
                              : zone,
                        );
                      }),
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
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: playerColor.withValues(alpha: 0.3), width: 2),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        children: List.generate(4, (i) {
          if (i >= buttonColors.length) return const SizedBox();
          return GestureDetector(
            onTap: active ? () => onTap(i) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: active ? colors[buttonColors[i]] : colors[buttonColors[i]].withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }),
      ),
    );
  }
}
