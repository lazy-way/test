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
  static const colors = [
    Colors.red, Colors.blue, Colors.green, Colors.yellow,
    Colors.purple, Colors.orange, Colors.pink, Colors.cyan,
    Colors.teal, Colors.amber,
  ];
  static const colorNames = [
    'RED', 'BLUE', 'GREEN', 'YELLOW',
    'PURPLE', 'ORANGE', 'PINK', 'CYAN',
    'TEAL', 'AMBER',
  ];

  final Random _random = Random();
  int _round = 0;
  final int _totalRounds = 15;
  int _targetColorIndex = 0;
  List<int> _buttonColors = []; // 8 options
  late List<int> _scores;
  bool _gameOver = false;
  bool _started = false;

  // Round phases
  // 1: showColor - target color visible, options hidden, countdown running
  // 2: selectColor - target stays visible, options shown, players can tap
  // 3: pause - brief pause between rounds
  String _phase = 'idle';
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _scores = List.filled(widget.players.length, 0);
    // Wait for GameWrapper's 3-2-1-GO countdown
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

    // Pick target color
    _targetColorIndex = _random.nextInt(colors.length);

    // Generate 8 button colors: 1 correct + 7 different wrong colors
    final wrongColors = <int>[];
    for (int c = 0; c < colors.length; c++) {
      if (c != _targetColorIndex) wrongColors.add(c);
    }
    wrongColors.shuffle(_random);
    _buttonColors = wrongColors.sublist(0, 7);
    // Insert the correct answer at a random position
    _buttonColors.insert(_random.nextInt(8), _targetColorIndex);

    setState(() {
      _round++;
      _phase = 'showColor';
      _countdown = 3;
    });

    // Start 3-2-1 countdown
    _runCountdown();
  }

  void _runCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted || _gameOver) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(milliseconds: 800));
    }
    if (!mounted || _gameOver) return;
    setState(() {
      _phase = 'selectColor';
    });
  }

  void _onColorTap(int playerIndex, int buttonIndex) {
    if (_phase != 'selectColor' || _gameOver) return;

    if (_buttonColors[buttonIndex] == _targetColorIndex) {
      setState(() {
        _scores[playerIndex] += 1;
        _phase = 'pause';
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _nextRound();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerCount = widget.players.length;
    final showOptions = _phase == 'selectColor';

    return Container(
      color: const Color(0xFF0a0a2e),
      child: SafeArea(
        child: Column(
          children: [
            // Header: round + scores
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _started ? 'Round $_round/$_totalRounds' : 'Get Ready...',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
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

            // P2 options at TOP (rotated, hidden until countdown done)
            if (playerCount > 1)
              Expanded(
                flex: 3,
                child: showOptions
                    ? Transform.rotate(
                        angle: pi,
                        child: _PlayerButtonZone(
                          playerIndex: 1,
                          playerColor: widget.players[1].color,
                          buttonColors: _buttonColors,
                          colors: colors,
                          onTap: (bi) => _onColorTap(1, bi),
                        ),
                      )
                    : const SizedBox.expand(),
              ),

            // CENTER: target color + countdown
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Target color box
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: (_phase == 'showColor' || _phase == 'selectColor')
                            ? colors[_targetColorIndex]
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: (_phase == 'showColor' || _phase == 'selectColor')
                            ? [
                                BoxShadow(
                                  color: colors[_targetColorIndex].withValues(alpha: 0.5),
                                  blurRadius: 25,
                                  spreadRadius: 3,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          (_phase == 'showColor' || _phase == 'selectColor')
                              ? colorNames[_targetColorIndex]
                              : '',
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Countdown or "GO!"
                    if (_phase == 'showColor')
                      Text(
                        '$_countdown',
                        style: GoogleFonts.fredoka(
                          fontWeight: FontWeight.w700,
                          fontSize: 32,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    if (_phase == 'selectColor')
                      Text(
                        'TAP NOW!',
                        style: GoogleFonts.fredoka(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: const Color(0xFF2ED573),
                        ),
                      ),
                    if (_phase == 'pause')
                      Text(
                        'Correct!',
                        style: GoogleFonts.fredoka(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: const Color(0xFFFFC312),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // P1 options at BOTTOM (hidden until countdown done)
            Expanded(
              flex: 3,
              child: showOptions
                  ? _PlayerButtonZone(
                      playerIndex: 0,
                      playerColor: widget.players[0].color,
                      buttonColors: _buttonColors,
                      colors: colors,
                      onTap: (bi) => _onColorTap(0, bi),
                    )
                  : const SizedBox.expand(),
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

  const _PlayerButtonZone({
    required this.playerIndex,
    required this.playerColor,
    required this.buttonColors,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: playerColor.withValues(alpha: 0.4), width: 2),
        color: playerColor.withValues(alpha: 0.05),
      ),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        children: List.generate(min(8, buttonColors.length), (i) {
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              decoration: BoxDecoration(
                color: colors[buttonColors[i]],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: colors[buttonColors[i]].withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
