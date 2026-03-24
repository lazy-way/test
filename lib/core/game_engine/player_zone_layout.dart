import 'package:flame/game.dart';
import 'dart:ui';

class PlayerZoneLayout {
  final Vector2 screenSize;
  final int playerCount;
  late List<Rect> _zones;

  PlayerZoneLayout({
    required this.screenSize,
    required this.playerCount,
  }) {
    _calculateZones();
  }

  void _calculateZones() {
    final w = screenSize.x;
    final h = screenSize.y;

    switch (playerCount) {
      case 1:
        _zones = [Rect.fromLTWH(0, 0, w, h)];
        break;
      case 2:
        _zones = [
          Rect.fromLTWH(0, h / 2, w, h / 2),   // Bottom (Player 1)
          Rect.fromLTWH(0, 0, w, h / 2),        // Top (Player 2)
        ];
        break;
      default:
        _zones = [Rect.fromLTWH(0, 0, w, h)];
    }
  }

  Rect getZone(int playerIndex) {
    if (playerIndex < 0 || playerIndex >= _zones.length) {
      return _zones.first;
    }
    return _zones[playerIndex];
  }

  int getPlayerForPosition(Vector2 position) {
    for (int i = 0; i < _zones.length; i++) {
      if (_zones[i].contains(Offset(position.x, position.y))) {
        return i;
      }
    }
    return 0;
  }

  List<Rect> get zones => List.unmodifiable(_zones);
}
