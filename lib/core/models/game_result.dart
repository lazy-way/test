import 'package:flutter/material.dart';

import 'player.dart';

class GameResult {
  final List<Player> rankings; // sorted by score, highest first
  final Duration gameDuration;

  const GameResult({
    required this.rankings,
    required this.gameDuration,
  });

  Player get winner => rankings.first;
  bool get isDraw => rankings.length > 1 && rankings[0].score == rankings[1].score;
}

class SoloGameSummary {
  final String title;
  final String subtitle;
  final List<SoloGameStat> stats;
  final Color color;
  final IconData icon;

  const SoloGameSummary({
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.color,
    required this.icon,
  });
}

class SoloGameStat {
  final String label;
  final String value;

  const SoloGameStat({
    required this.label,
    required this.value,
  });
}
