import 'dart:async';
import 'package:flutter/foundation.dart';

class GameTimer {
  final Duration duration;
  final VoidCallback onComplete;
  final ValueChanged<Duration>? onTick;

  Timer? _timer;
  late Duration _remaining;
  bool _isRunning = false;

  GameTimer({
    required this.duration,
    required this.onComplete,
    this.onTick,
  }) {
    _remaining = duration;
  }

  Duration get remaining => _remaining;
  bool get isRunning => _isRunning;
  double get progress => 1.0 - (_remaining.inMilliseconds / duration.inMilliseconds);

  void start() {
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining -= const Duration(seconds: 1);
      onTick?.call(_remaining);
      if (_remaining.inSeconds <= 0) {
        stop();
        onComplete();
      }
    });
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
  }

  void dispose() {
    stop();
  }
}
