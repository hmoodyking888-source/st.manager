import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color black = Color(0xFF000000);
  static const Color gold = Color(0xFFD4AF37);
  static const Color darkGrey = Color(0xFF1A1A1A);
  static const Color semiBlack = Color(0xFF0D0D0D);
  static const Color greenOnline = Color(0xFF4CAF50);
  static const Color redOffline = Color(0xFFF44336);

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
      fontFamily: GoogleFonts.cairo().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: black,
        foregroundColor: gold,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
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
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        // <-- صححنا إلى CardThemeData
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
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
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
        labelStyle: GoogleFonts.cairo(color: gold),
        hintStyle: GoogleFonts.cairo(color: Colors.grey),
      ),
      textTheme: TextTheme(
        headlineMedium:
            GoogleFonts.cairo(color: gold, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.cairo(color: gold, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.cairo(color: Colors.white),
        bodyMedium: GoogleFonts.cairo(color: Colors.white70),
        labelSmall: GoogleFonts.cairo(color: gold),
      ),
    );
  }
}
