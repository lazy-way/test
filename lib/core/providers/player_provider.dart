import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../../app/theme.dart';

class PlayerNotifier extends StateNotifier<List<Player>> {
  PlayerNotifier() : super([
    Player(id: 0, color: AppTheme.player1Color, name: 'Player 1'),
    Player(id: 1, color: AppTheme.player2Color, name: 'Player 2'),
  ]);

  void setPlayerCount(int count) {
    state = List.generate(count, (i) => Player(
      id: i,
      color: AppTheme.playerColors[i],
      name: AppTheme.playerNames[i],
    ));
  }

  void togglePlayer(int index) {
    if (index < 0 || index > 3) return;
    final currentIds = state.map((p) => p.id).toSet();
    if (currentIds.contains(index)) {
      if (state.length <= 1) return; // Must have at least 1 player
      state = state.where((p) => p.id != index).toList();
    } else {
      state = [...state, Player(
        id: index,
        color: AppTheme.playerColors[index],
        name: AppTheme.playerNames[index],
      )]..sort((a, b) => a.id.compareTo(b.id));
    }
  }

  void resetScores() {
    state = state.map((p) => p.copyWith(score: 0)).toList();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, List<Player>>((ref) {
  return PlayerNotifier();
});
