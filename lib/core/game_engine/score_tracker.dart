import '../models/player.dart';
import '../models/game_result.dart';

class ScoreTracker {
  final List<Player> players;
  final Map<int, int> _scores = {};

  ScoreTracker({required this.players}) {
    for (final p in players) {
      _scores[p.id] = 0;
    }
  }

  int getScore(int playerId) => _scores[playerId] ?? 0;

  void addScore(int playerId, int points) {
    _scores[playerId] = (_scores[playerId] ?? 0) + points;
  }

  void setScore(int playerId, int score) {
    _scores[playerId] = score;
  }

  GameResult getResult(Duration duration) {
    final sortedPlayers = List<Player>.from(players);
    sortedPlayers.sort((a, b) => getScore(b.id).compareTo(getScore(a.id)));
    for (final p in sortedPlayers) {
      p.score = getScore(p.id);
    }
    return GameResult(rankings: sortedPlayers, gameDuration: duration);
  }
}
