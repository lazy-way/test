import 'package:flutter/material.dart';

class Player {
  final int id;
  final Color color;
  final String name;
  int score;

  Player({
    required this.id,
    required this.color,
    required this.name,
    this.score = 0,
  });

  Player copyWith({int? score}) {
    return Player(
      id: id,
      color: color,
      name: name,
      score: score ?? this.score,
    );
  }
}
