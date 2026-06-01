import 'package:flutter/material.dart';

class AppTheme {
  static const Color black = Color(0xFF000000);
  static const Color gold = Color(0xFFD4AF37);
  static const Color darkGrey = Color(0xFF1A1A1A);
  static const Color semiBlack = Color(0xFF0D0D0D);
  static const Color greenOnline = Color(0xFF4CAF50);
  static const Color redOffline = Color(0xFFF44336);

  static const String _fontFamily = 'Cairo';

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      primaryColor: gold,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: gold,
        surface: semiBlack,
        error: redOffline,
        onPrimary: black,
        onSecondary: black,
        onSurface: gold,
        onError: black,
      ),
      fontFamily: _fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        foregroundColor: gold,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: gold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: black,
        selectedItemColor: gold,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: semiBlack,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: gold, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semiBlack,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 2),
        ),
        labelStyle: const TextStyle(fontFamily: _fontFamily, color: gold),
        hintStyle: const TextStyle(fontFamily: _fontFamily, color: Colors.grey),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: _fontFamily,
          color: gold,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        titleLarge: TextStyle(
          fontFamily: _fontFamily,
          color: gold,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        bodyLarge: TextStyle(
            fontFamily: _fontFamily, color: Colors.white, fontSize: 16),
        bodyMedium: TextStyle(
            fontFamily: _fontFamily, color: Colors.white70, fontSize: 14),
        labelSmall:
            TextStyle(fontFamily: _fontFamily, color: gold, fontSize: 12),
      ),
    );
  }
}
