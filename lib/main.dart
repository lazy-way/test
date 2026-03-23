import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'app/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ProviderScope(child: MiniGamesApp()));
}

class MiniGamesApp extends StatelessWidget {
  const MiniGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '1 2 3 4 Player Games',
      theme: AppTheme.themeData,
      routerConfig: routerProvider,
      debugShowCheckedModeBanner: false,
    );
  }
}
