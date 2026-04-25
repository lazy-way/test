import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

enum MusicTrack { none, home, game }

class MusicController {
  MusicController(this._ref);

  final Ref _ref;

  static const String _homeAsset = 'home_loop.wav';
  static const String _gameAsset = 'game_loop.wav';

  bool _initialized = false;
  MusicTrack _currentTrack = MusicTrack.none;

  Future<void> playHome() => _play(MusicTrack.home);

  Future<void> playGame() => _play(MusicTrack.game);

  Future<void> stop() async {
    _currentTrack = MusicTrack.none;
    await FlameAudio.bgm.stop();
  }

  Future<void> syncWithSettings() async {
    final soundEnabled = _ref.read(settingsProvider).soundEnabled;
    if (!soundEnabled) {
      await FlameAudio.bgm.stop();
      return;
    }

    switch (_currentTrack) {
      case MusicTrack.home:
        await _play(MusicTrack.home, forceRestart: true);
        break;
      case MusicTrack.game:
        await _play(MusicTrack.game, forceRestart: true);
        break;
      case MusicTrack.none:
        break;
    }
  }

  Future<void> toggleMute() async {
    _ref.read(settingsProvider.notifier).toggleSound();
    await syncWithSettings();
  }

  Future<void> dispose() async {
    await FlameAudio.bgm.stop();
  }

  Future<void> _play(MusicTrack track, {bool forceRestart = false}) async {
    final previousTrack = _currentTrack;
    final soundEnabled = _ref.read(settingsProvider).soundEnabled;
    _currentTrack = track;

    if (!soundEnabled) {
      await FlameAudio.bgm.stop();
      return;
    }

    if (!_initialized) {
      await FlameAudio.bgm.initialize();
      _initialized = true;
    }

    if (!forceRestart && FlameAudio.bgm.isPlaying && previousTrack == track) {
      return;
    }

    final asset = switch (track) {
      MusicTrack.home => _homeAsset,
      MusicTrack.game => _gameAsset,
      MusicTrack.none => null,
    };

    if (asset == null) {
      await FlameAudio.bgm.stop();
      return;
    }

    await FlameAudio.bgm.play(asset, volume: 0.7);
  }
}

final musicControllerProvider = Provider<MusicController>((ref) {
  final controller = MusicController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
