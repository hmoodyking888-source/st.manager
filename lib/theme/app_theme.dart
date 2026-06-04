import 'package:flutter/material.dart';

class AppTheme {
  static const Color black = Color(0xFF000000);
  static const Color gold = Color(0xFFD4AF37);
  static const Color darkGrey = Color(0xFF1A1A1A);
  static const Color semiBlack = Color(0xFF0D0D0D);
  static const Color greenOnline = Color(0xFF4CAF50);
  static const Color redOffline = Color(0xFFF44336);
  static const Color navyBlue = Color(0xFF1A237E);
  static const Color lightBackground =
      Color(0xFFF8F9FA); // أبيض مائل للرمادي الناعم
  static const Color darkText = Color(0xFF212121); // أسود غامق للنصوص
  static const Color mediumText = Color(0xFF616161); // رمادي متوسط
  static const Color lightCard = Color(0xFFFFFFFF); // أبيض نقي للكروت

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

  // ---------- الثيم الفاتح (مُعاد تصميمه) ----------
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: navyBlue,
      colorScheme: const ColorScheme.light(
        primary: navyBlue,
        secondary: gold,
        surface: lightCard,
        error: redOffline,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkText,
        onError: Colors.white,
      ),
      fontFamily: _fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: navyBlue,
        unselectedItemColor: mediumText,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: navyBlue, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navyBlue,
          foregroundColor: Colors.white,
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
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navyBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navyBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navyBlue, width: 2),
        ),
        labelStyle: const TextStyle(fontFamily: _fontFamily, color: navyBlue),
        hintStyle: const TextStyle(fontFamily: _fontFamily, color: mediumText),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: _fontFamily,
          color: navyBlue,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        titleLarge: TextStyle(
          fontFamily: _fontFamily,
          color: navyBlue,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        bodyLarge:
            TextStyle(fontFamily: _fontFamily, color: darkText, fontSize: 16),
        bodyMedium:
            TextStyle(fontFamily: _fontFamily, color: mediumText, fontSize: 14),
        labelSmall:
            TextStyle(fontFamily: _fontFamily, color: gold, fontSize: 12),
      ),
    );
  }
}
