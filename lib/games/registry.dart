import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/game_config.dart';
import '../core/models/game_category.dart';
import '../core/models/player.dart';
import '../core/providers/player_provider.dart';

import 'ping_pong/ping_pong_game.dart';
import 'air_hockey/air_hockey_game.dart';
import 'tank_battle/tank_battle_game.dart';
import 'sumo_push/sumo_push_game.dart';
import 'color_match/color_match_game.dart';
import 'snake_arena/snake_arena_game.dart';
import 'micro_racers/micro_racers_game.dart';
import 'fruit_slash/fruit_slash_game.dart';
import 'memory_cards/memory_cards_game.dart';
import 'block_stacker/block_stacker_game.dart';
import 'boat_rush/boat_rush_game.dart';
import 'skateboard_dash/skateboard_dash_game.dart';
import 'basketball_hoops/basketball_hoops_game.dart';
import 'dice_war/dice_war_game.dart';
import 'dot_capture/dot_capture_game.dart';

class GameRegistry {
  static const List<GameConfig> allGames = [
    // Sports
    GameConfig(
      id: 'ping_pong',
      name: 'Ping Pong',
      description: 'Classic paddle ball game',
      icon: Icons.sports_tennis,
      category: GameCategory.sports,
      minPlayers: 1,
      maxPlayers: 2,
      accentColor: Color(0xFF4ECDC4),
    ),
    GameConfig(
      id: 'air_hockey',
      name: 'Air Hockey',
      description: 'Drag your mallet, score goals',
      icon: Icons.circle_outlined,
      category: GameCategory.sports,
      minPlayers: 1,
      maxPlayers: 2,
      accentColor: Color(0xFF45B7D1),
    ),
    GameConfig(
      id: 'basketball_hoops',
      name: 'Basketball',
      description: 'Swipe to shoot hoops',
      icon: Icons.sports_basketball,
      category: GameCategory.sports,
      minPlayers: 1,
      maxPlayers: 2,
      accentColor: Color(0xFFFF9F43),
    ),

    // Action
    GameConfig(
      id: 'tank_battle',
      name: 'Tank Battle',
      description: 'Top-down tank warfare',
      icon: Icons.gps_fixed,
      category: GameCategory.action,
      minPlayers: 2,
      maxPlayers: 2,
      accentColor: Color(0xFFFF6B6B),
    ),
    GameConfig(
      id: 'sumo_push',
      name: 'Sumo Push',
      description: 'Push opponents off the ring',
      icon: Icons.sports_martial_arts,
      category: GameCategory.action,
      minPlayers: 2,
      maxPlayers: 2,
      accentColor: Color(0xFFFFE66D),
    ),
    GameConfig(
      id: 'fruit_slash',
      name: 'Fruit Slash',
      description: 'Swipe to slice, avoid bombs',
      icon: Icons.content_cut,
      category: GameCategory.action,
      minPlayers: 1,
      maxPlayers: 2,
      accentColor: Color(0xFFFF6348),
    ),

    // Racing
    GameConfig(
      id: 'micro_racers',
      name: 'Micro Racers',
      description: 'Race around the track',
      icon: Icons.directions_car,
      category: GameCategory.racing,
      minPlayers: 1,
      maxPlayers: 2,
      accentColor: Color(0xFFFF4757),
    ),
    GameConfig(
      id: 'boat_rush',
      name: 'Boat Rush',
      description: 'Dodge obstacles on the river',
      icon: Icons.sailing,
      category: GameCategory.racing,
      minPlayers: 2,
      maxPlayers: 2,
      accentColor: Color(0xFF0984E3),
    ),
    GameConfig(
      id: 'skateboard_dash',
      name: 'Skate Dash',
      description: 'Jump over obstacles',
      icon: Icons.skateboarding,
      category: GameCategory.racing,
      minPlayers: 1,
      maxPlayers: 2,
      accentColor: Color(0xFFA29BFE),
    ),

    // Puzzle
    GameConfig(
      id: 'color_match',
      name: 'Color Match',
      description: 'Match the flashing color',
      icon: Icons.palette,
      category: GameCategory.puzzle,
      minPlayers: 1,
      maxPlayers: 2,
      accentColor: Color(0xFFA29BFE),
    ),
    GameConfig(
      id: 'memory_cards',
      name: 'Memory Cards',
      description: 'Find matching pairs',
      icon: Icons.grid_view_rounded,
      category: GameCategory.puzzle,
      minPlayers: 1,
      maxPlayers: 2,
      accentColor: Color(0xFF6C5CE7),
    ),
    GameConfig(
      id: 'block_stacker',
      name: 'Block Stacker',
      description: 'Stack blocks, build tall',
      icon: Icons.view_column_rounded,
      category: GameCategory.puzzle,
      minPlayers: 1,
      maxPlayers: 2,
      accentColor: Color(0xFFFD79A8),
    ),

    // Strategy
    GameConfig(
      id: 'snake_arena',
      name: 'Snake Arena',
      description: 'Classic snake battle',
      icon: Icons.route,
      category: GameCategory.strategy,
      minPlayers: 2,
      maxPlayers: 2,
      accentColor: Color(0xFF2ED573),
    ),
    GameConfig(
      id: 'dice_war',
      name: 'Dice War',
      description: 'Conquer territory with dice',
      icon: Icons.casino,
      category: GameCategory.strategy,
      minPlayers: 2,
      maxPlayers: 2,
      accentColor: Color(0xFFFF9FF3),
    ),
    GameConfig(
      id: 'dot_capture',
      name: 'Dot Capture',
      description: 'Connect dots, claim squares',
      icon: Icons.grid_on,
      category: GameCategory.strategy,
      minPlayers: 2,
      maxPlayers: 2,
      accentColor: Color(0xFF54A0FF),
    ),
  ];

  static Widget buildGame(BuildContext context, WidgetRef ref, String gameId) {
    final players = ref.read(playerProvider);

    switch (gameId) {
      case 'ping_pong':
        return PingPongGame.widget(players: players);
      case 'air_hockey':
        return AirHockeyGame.widget(players: players);
      case 'tank_battle':
        return TankBattleGame.widget(players: players);
      case 'sumo_push':
        return SumoPushGame.widget(players: players);
      case 'color_match':
        return ColorMatchGame.widget(players: players);
      case 'snake_arena':
        return SnakeArenaGame.widget(players: players);
      case 'micro_racers':
        return MicroRacersGame.widget(players: players);
      case 'fruit_slash':
        return FruitSlashGame.widget(players: players);
      case 'memory_cards':
        return MemoryCardsGame.widget(players: players);
      case 'block_stacker':
        return BlockStackerGame.widget(players: players);
      case 'boat_rush':
        return BoatRushGame.widget(players: players);
      case 'skateboard_dash':
        return SkateboardDashGame.widget(players: players);
      case 'basketball_hoops':
        return BasketballHoopsGame.widget(players: players);
      case 'dice_war':
        return DiceWarGame.widget(players: players);
      case 'dot_capture':
        return DotCaptureGame.widget(players: players);
      default:
        return const Scaffold(body: Center(child: Text('Game not found')));
    }
  }
}
