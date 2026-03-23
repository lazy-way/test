import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/player.dart';
import '../../core/widgets/game_wrapper.dart';
import '../../app/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class MemoryCardsGame extends StatelessWidget {
  final List<Player> players;
  const MemoryCardsGame({super.key, required this.players});

  static Widget widget({required List<Player> players}) {
    return GameWrapper(
      gameName: 'Memory Cards',
      players: players,
      gameBuilder: (onEnd) => _MemoryPlayArea(players: players, onGameEnd: onEnd),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget(players: players);
  }
}

class _MemoryPlayArea extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onGameEnd;
  const _MemoryPlayArea({required this.players, required this.onGameEnd});

  @override
  State<_MemoryPlayArea> createState() => _MemoryPlayAreaState();
}

class _MemoryPlayAreaState extends State<_MemoryPlayArea> {
  static const icons = [
    Icons.star, Icons.favorite, Icons.bolt, Icons.diamond,
    Icons.music_note, Icons.pets, Icons.rocket, Icons.local_fire_department,
    Icons.wb_sunny, Icons.nightlight, Icons.cloud, Icons.water_drop,
  ];

  late List<int> cards; // icon indices
  late List<bool> revealed;
  late List<bool> matched;
  late List<int> scores;
  int currentPlayer = 0;
  int? firstFlip;
  int? secondFlip;
  bool checking = false;
  bool gameOver = false;

  @override
  void initState() {
    super.initState();
    final pairCount = 8;
    final indices = List.generate(pairCount, (i) => i);
    cards = [...indices, ...indices];
    cards.shuffle(Random());
    revealed = List.filled(cards.length, false);
    matched = List.filled(cards.length, false);
    scores = List.filled(widget.players.length, 0);
  }

  void _onCardTap(int index) {
    if (checking || gameOver || revealed[index] || matched[index]) return;

    setState(() {
      revealed[index] = true;
      if (firstFlip == null) {
        firstFlip = index;
      } else {
        secondFlip = index;
        checking = true;

        if (cards[firstFlip!] == cards[secondFlip!]) {
          // Match found
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            setState(() {
              matched[firstFlip!] = true;
              matched[secondFlip!] = true;
              scores[currentPlayer]++;
              firstFlip = null;
              secondFlip = null;
              checking = false;

              if (matched.every((m) => m)) {
                gameOver = true;
                for (int i = 0; i < widget.players.length; i++) {
                  widget.players[i].score = scores[i];
                }
                widget.onGameEnd();
              }
            });
          });
        } else {
          // No match
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            setState(() {
              revealed[firstFlip!] = false;
              revealed[secondFlip!] = false;
              firstFlip = null;
              secondFlip = null;
              checking = false;
              currentPlayer = (currentPlayer + 1) % widget.players.length;
            });
          });
        }
      }
    });
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
                  // Current player indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: currentColor.withValues(alpha: 0.3),
                      border: Border.all(color: currentColor, width: 2),
                    ),
                    child: Text(
                      'P${currentPlayer + 1}\'s Turn',
                      style: TextStyle(color: currentColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Scores
                  Row(
                    children: List.generate(widget.players.length, (i) => Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.players[i].color,
                            ),
                            child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          ),
                          Text('${scores[i]}', style: TextStyle(color: widget.players[i].color, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                  ),
                ],
              ),
            ),
            // Card grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () => _onCardTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: matched[i]
                              ? Colors.green.withValues(alpha: 0.2)
                              : revealed[i]
                                  ? const Color(0xFF2a2a5e)
                                  : const Color(0xFF1a1a4e),
                          border: Border.all(
                            color: matched[i]
                                ? Colors.green.withValues(alpha: 0.5)
                                : revealed[i]
                                    ? currentColor.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.1),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: revealed[i] || matched[i]
                                ? Icon(
                                    icons[cards[i]],
                                    key: ValueKey('icon_$i'),
                                    color: matched[i] ? Colors.green : Colors.white,
                                    size: 32,
                                  )
                                : Icon(
                                    Icons.question_mark_rounded,
                                    key: ValueKey('hidden_$i'),
                                    color: Colors.white.withValues(alpha: 0.2),
                                    size: 24,
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
