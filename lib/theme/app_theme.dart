import 'package:flutter/material.dart';

class AppTheme {
  static const Color black = Color(0xFF000000);
  static const Color gold = Color(0xFFD4AF37);
  static const Color darkGrey = Color(0xFF1A1A1A);
  static const Color semiBlack = Color(0xFF0D0D0D);
  static const Color greenOnline = Color(0xFF4CAF50);
  static const Color redOffline = Color(0xFFF44336);
  static const Color navyBlue = Color(0xFF1A237E);

  static const Color lightBackground = Color(0xFFF4F8F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF0F6F0);
  static const Color lightBorder = Color(0xFFCFE0D0);
  static const Color lightPrimaryGreen = Color(0xFF2E7D32);
  static const Color lightSecondaryGreen = Color(0xFF66BB6A);
  static const Color lightAccentGreen = Color(0xFFA5D6A7);
  static const Color lightGold = Color(0xFFC8A43A);
  static const Color darkText = Color(0xFF1F2A1F);
  static const Color mediumText = Color(0xFF5E6B5E);
  static const Color softText = Color(0xFF7B887B);

  static const String _fontFamily = 'Cairo';

  // ---------- الثيم الداكن (الافتراضي) ----------
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

  // ---------- الثيم الفاتح الجديد ----------
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightPrimaryGreen,
      colorScheme: const ColorScheme.light(
        primary: lightPrimaryGreen,
        secondary: lightSecondaryGreen,
        surface: lightSurface,
        error: redOffline,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkText,
        onError: Colors.white,
      ),
      fontFamily: _fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightPrimaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: lightPrimaryGreen,
        unselectedItemColor: softText,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: lightBorder, width: 1),
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 1.5,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightPrimaryGreen,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightPrimaryGreen,
        foregroundColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? lightPrimaryGreen
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? lightSecondaryGreen.withOpacity(0.45)
              : Colors.grey.shade300,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? lightPrimaryGreen
              : Colors.grey.shade300,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightPrimaryGreen, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: redOffline, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: redOffline, width: 1.6),
        ),
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: lightPrimaryGreen,
        ),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: mediumText,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: _fontFamily,
          color: lightPrimaryGreen,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        titleLarge: TextStyle(
          fontFamily: _fontFamily,
          color: darkText,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        bodyLarge: TextStyle(
          fontFamily: _fontFamily,
          color: darkText,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          fontFamily: _fontFamily,
          color: mediumText,
          fontSize: 14,
        ),
        labelSmall: TextStyle(
          fontFamily: _fontFamily,
          color: lightPrimaryGreen,
          fontSize: 12,
        ),
      ),
    );
  }
}
