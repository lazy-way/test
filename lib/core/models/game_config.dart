import 'package:flutter/material.dart';
import 'game_category.dart';

class GameConfig {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final GameCategory category;
  final int minPlayers;
  final int maxPlayers;
  final Color accentColor;

  const GameConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.minPlayers,
    required this.maxPlayers,
    required this.accentColor,
  });

  bool supportsPlayerCount(int count) => count >= minPlayers && count <= maxPlayers;
}
