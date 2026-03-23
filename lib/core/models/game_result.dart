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
