import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/game_result.dart';
import 'player_zone_layout.dart';

abstract class BaseMiniGame extends FlameGame with MultiTouchTapDetector, MultiTouchDragDetector {
  final List<Player> players;
  final VoidCallback onGameEnd;
  late PlayerZoneLayout zoneLayout;
  bool gameStarted = false;
  bool gameEnded = false;
  final Stopwatch _stopwatch = Stopwatch();

  BaseMiniGame({
    required this.players,
    required this.onGameEnd,
  });

  int get playerCount => players.length;
  Duration? get gameDuration => null; // Override for timed games
  Duration get elapsed => _stopwatch.elapsed;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    zoneLayout = PlayerZoneLayout(
      screenSize: size,
      playerCount: playerCount,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      zoneLayout = PlayerZoneLayout(
        screenSize: size,
        playerCount: playerCount,
      );
    }
  }

  void startGame() {
    gameStarted = true;
    _stopwatch.start();
  }

  void endGame(GameResult result) {
    if (gameEnded) return;
    gameEnded = true;
    _stopwatch.stop();
    onGameEnd();
  }

  int getPlayerForPosition(Vector2 position) {
    return zoneLayout.getPlayerForPosition(position);
  }

  Rect getPlayerZone(int playerIndex) {
    return zoneLayout.getZone(playerIndex);
  }
}
