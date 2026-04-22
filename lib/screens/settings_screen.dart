import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';
import '../core/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.homeGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
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
                        'SETTINGS',
                        textAlign: TextAlign.center,
                        style: AppTheme.titleStyle.copyWith(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _SettingsTile(
                icon: Icons.volume_up_rounded,
                title: 'Sound & Music',
                value: settings.soundEnabled,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggleSound(),
              ),
              _SettingsTile(
                icon: Icons.vibration_rounded,
                title: 'Vibration',
                value: settings.vibrationEnabled,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggleVibration(),
              ),
              const Spacer(),
              Text(
                'Version 1.0.0',
                style: AppTheme.bodyStyle.copyWith(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: AppTheme.bodyStyle)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF2ED573),
            ),
          ],
        ),
      ),
    );
  }
}
