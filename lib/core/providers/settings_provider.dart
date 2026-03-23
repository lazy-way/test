import 'package:flutter_riverpod/flutter_riverpod.dart';

class Settings {
  final bool soundEnabled;
  final bool vibrationEnabled;

  const Settings({this.soundEnabled = true, this.vibrationEnabled = true});

  Settings copyWith({bool? soundEnabled, bool? vibrationEnabled}) {
    return Settings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier() : super(const Settings());

  void toggleSound() => state = state.copyWith(soundEnabled: !state.soundEnabled);
  void toggleVibration() => state = state.copyWith(vibrationEnabled: !state.vibrationEnabled);
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier();
});
