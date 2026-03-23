enum GameCategory {
  all('All', '🎮'),
  racing('Racing', '🏎️'),
  sports('Sports', '⚽'),
  action('Action', '💥'),
  puzzle('Puzzle', '🧩'),
  strategy('Strategy', '🧠');

  final String label;
  final String emoji;
  const GameCategory(this.label, this.emoji);
}
