import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Player colors
  static const Color player1Color = Color(0xFFFF4757);
  static const Color player2Color = Color(0xFF3742FA);
  static const Color player3Color = Color(0xFF2ED573);
  static const Color player4Color = Color(0xFFFFC312);

  static const List<Color> playerColors = [player1Color, player2Color, player3Color, player4Color];
  static const List<String> playerNames = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];

  // Gradients
  static const LinearGradient homeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CE7), Color(0xFF0984E3)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2D1B69), Color(0xFF0F0C29)],
  );

  static const LinearGradient gameSelectGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  );

  // Category colors
  static const Color racingColor = Color(0xFFFF6B6B);
  static const Color sportsColor = Color(0xFF4ECDC4);
  static const Color actionColor = Color(0xFFFFE66D);
  static const Color puzzleColor = Color(0xFFA29BFE);
  static const Color strategyColor = Color(0xFFFF9FF3);

  // Text Styles
  static TextStyle get titleStyle => GoogleFonts.fredoka(
    fontWeight: FontWeight.w700,
    fontSize: 32,
    color: Colors.white,
    letterSpacing: 1.2,
  );

  static TextStyle get headingStyle => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle get bodyStyle => GoogleFonts.poppins(
    fontSize: 16,
    color: Colors.white,
  );

  static TextStyle get buttonStyle => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle get gameCardTitle => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static ThemeData get themeData => ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF6C5CE7),
    scaffoldBackgroundColor: const Color(0xFF0F0C29),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    useMaterial3: true,
  );
}
