import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_config.dart';
import '../../games/registry.dart';

final gameListProvider = Provider<List<GameConfig>>((ref) {
  return GameRegistry.allGames;
});
