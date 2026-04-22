import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';
import '../core/models/game_category.dart';
import '../core/providers/player_provider.dart';
import '../games/registry.dart';

class GameSelectScreen extends ConsumerStatefulWidget {
  const GameSelectScreen({super.key});

  @override
  ConsumerState<GameSelectScreen> createState() => _GameSelectScreenState();
}

class _GameSelectScreenState extends ConsumerState<GameSelectScreen>
    with TickerProviderStateMixin {
  GameCategory _selectedCategory = GameCategory.all;
  late AnimationController _cardController;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(playerProvider);
    final playerCount = players.length;
    final allGames = GameRegistry.allGames;
    final filteredGames = _selectedCategory == GameCategory.all
        ? allGames
        : allGames.where((g) => g.category == _selectedCategory).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gameSelectGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'CHOOSE GAME',
                        textAlign: TextAlign.center,
                        style: AppTheme.titleStyle.copyWith(fontSize: 22),
                      ),
                    ),
                    // Player indicators
                    Row(
                      children: List.generate(
                        playerCount,
                        (i) => Container(
                          margin: const EdgeInsets.only(left: 4),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: players[i].color,
                          ),
                          child: Center(
                            child: Text(
                              '${players[i].id + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Category tabs
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: GameCategory.values.length,
                  itemBuilder: (context, i) {
                    final cat = GameCategory.values[i];
                    final isSelected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = cat);
                          _cardController.reset();
                          _cardController.forward();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isSelected
                                ? _getCategoryColor(cat)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                          child: Text(
                            '${cat.emoji} ${cat.label}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Game grid
              Expanded(
                child: AnimatedBuilder(
                  animation: _cardController,
                  builder: (context, child) {
                    final maxDelay = filteredGames.isEmpty
                        ? 0.0
                        : ((filteredGames.length - 1) * 0.06).clamp(0.0, 0.45);
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: filteredGames.length,
                      itemBuilder: (context, i) {
                        final game = filteredGames[i];
                        final supported = game.supportsPlayerCount(playerCount);
                        final delay = filteredGames.length <= 1
                            ? 0.0
                            : (i / (filteredGames.length - 1)) * maxDelay;
                        final animValue = Curves.easeOutBack.transform(
                          ((_cardController.value - delay) / (1 - maxDelay))
                              .clamp(0.0, 1.0),
                        );

                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - animValue)),
                          child: Opacity(
                            opacity: animValue.clamp(0.0, 1.0),
                            child: GestureDetector(
                              onTap: supported
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              GameRegistry.buildGame(
                                                context,
                                                ref,
                                                game.id,
                                              ),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      game.accentColor.withValues(
                                        alpha: supported ? 0.3 : 0.1,
                                      ),
                                      game.accentColor.withValues(
                                        alpha: supported ? 0.15 : 0.05,
                                      ),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: game.accentColor.withValues(
                                      alpha: supported ? 0.3 : 0.1,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            game.icon,
                                            size: 40,
                                            color: supported
                                                ? game.accentColor
                                                : Colors.white24,
                                          ),
                                          const Spacer(),
                                          Text(
                                            game.name,
                                            style: AppTheme.gameCardTitle
                                                .copyWith(
                                                  color: supported
                                                      ? Colors.white
                                                      : Colors.white38,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              color: _getCategoryColor(
                                                game.category,
                                              ).withValues(alpha: 0.3),
                                            ),
                                            child: Text(
                                              game.category.label,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: supported
                                                    ? _getCategoryColor(
                                                        game.category,
                                                      )
                                                    : Colors.white38,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: List.generate(
                                              game.maxPlayers,
                                              (pi) => Container(
                                                margin: const EdgeInsets.only(
                                                  right: 3,
                                                ),
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: pi < game.minPlayers
                                                      ? AppTheme
                                                            .playerColors[pi]
                                                            .withValues(
                                                              alpha: 0.8,
                                                            )
                                                      : AppTheme
                                                            .playerColors[pi]
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                  border: Border.all(
                                                    color: AppTheme
                                                        .playerColors[pi]
                                                        .withValues(alpha: 0.5),
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!supported)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Icon(
                                          Icons.lock_rounded,
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(GameCategory cat) {
    switch (cat) {
      case GameCategory.all:
        return Colors.white;
      case GameCategory.racing:
        return AppTheme.racingColor;
      case GameCategory.sports:
        return AppTheme.sportsColor;
      case GameCategory.action:
        return AppTheme.actionColor;
      case GameCategory.puzzle:
        return AppTheme.puzzleColor;
      case GameCategory.strategy:
        return AppTheme.strategyColor;
    }
  }
}
