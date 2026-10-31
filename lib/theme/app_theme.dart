import 'package:flutter/material.dart';

/// الثيمات المتاحة في التطبيق.
enum AppThemePreset {
  classicGold,
  neonBlue,
  neonGreen,
  royalPurple,
  classicLight,
}

/// ألوان موحّدة يمكن للشاشات استخدامها بدلاً من تثبيت الألوان داخل كل شاشة.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color accent;
  final Color secondary;
  final Color text;
  final Color mutedText;
  final Color border;
  final Color onAccent;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
    required this.secondary,
    required this.text,
    required this.mutedText,
    required this.border,
    required this.onAccent,
  });

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? accent,
    Color? secondary,
    Color? text,
    Color? mutedText,
    Color? border,
    Color? onAccent,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      accent: accent ?? this.accent,
      secondary: secondary ?? this.secondary,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      border: border ?? this.border,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      text: Color.lerp(text, other.text, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      border: Color.lerp(border, other.border, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

class AppTheme {
  // الألوان القديمة محفوظة كما هي لضمان عدم كسر الشاشات الحالية التي تستخدمها.
  static const Color black = Color(0xFF000000);
  static const Color gold = Color(0xFFD4AF37);
  static const Color darkGrey = Color(0xFF1A1A1A);
  static const Color semiBlack = Color(0xFF0D0D0D);
  static const Color greenOnline = Color(0xFF4CAF50);
  static const Color redOffline = Color(0xFFF44336);
  static const Color navyBlue = Color(0xFF1A237E);

  static const Color lightBackground = Color(0xFFF5F8F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF0F5F0);
  static const Color lightBorder = Color(0xFFC9D8CA);
  static const Color lightPrimaryGreen = Color(0xFF2E7D32);
  static const Color lightSecondaryGreen = Color(0xFF66BB6A);
  static const Color lightAccentGreen = Color(0xFFA5D6A7);
  static const Color darkText = Color(0xFF1F2A1F);
  static const Color mediumText = Color(0xFF5E6B5E);
  static const Color softText = Color(0xFF6F7B6F);

  static const String _fontFamily = 'Cairo';

  /// الحالة المشتركة حتى تتغير ألوان التطبيق فور اختيار ثيم جديد.
  static final ValueNotifier<AppThemePreset> currentPreset =
      ValueNotifier<AppThemePreset>(AppThemePreset.classicGold);

  static const List<AppThemePreset> availablePresets = [
    AppThemePreset.classicGold,
    AppThemePreset.neonBlue,
    AppThemePreset.neonGreen,
    AppThemePreset.royalPurple,
    AppThemePreset.classicLight,
  ];

  static AppThemePreset? presetFromId(String? id) {
    switch (id) {
      case 'classicGold':
        return AppThemePreset.classicGold;
      case 'neonBlue':
        return AppThemePreset.neonBlue;
      case 'neonGreen':
        return AppThemePreset.neonGreen;
      case 'royalPurple':
        return AppThemePreset.royalPurple;
      case 'classicLight':
        return AppThemePreset.classicLight;
      default:
        return null;
    }
  }

  static String presetId(AppThemePreset preset) => preset.name;

  static String presetName(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.classicGold:
        return 'الذهبي الكلاسيكي';
      case AppThemePreset.neonBlue:
        return 'نيون أزرق وأبيض';
      case AppThemePreset.neonGreen:
        return 'الأخضر الزمردي';
      case AppThemePreset.royalPurple:
        return 'البنفسجي الفخم';
      case AppThemePreset.classicLight:
        return 'الوضع الفاتح';
    }
  }

  static String presetDescription(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.classicGold:
        return 'الهوية الأصلية بالأسود والذهبي';
      case AppThemePreset.neonBlue:
        return 'توهج أزرق كهربائي مع تفاصيل بيضاء';
      case AppThemePreset.neonGreen:
        return 'أخضر زمردي أنيق على خلفية داكنة';
      case AppThemePreset.royalPurple:
        return 'بنفسجي ملكي بتفاصيل مضيئة';
      case AppThemePreset.classicLight:
        return 'الوضع الفاتح التقليدي';
    }
  }

  static bool isLightPreset(AppThemePreset preset) =>
      preset == AppThemePreset.classicLight;

  static void setCurrentPreset(AppThemePreset preset) {
    currentPreset.value = preset;
  }

  static AppThemeColors paletteFor(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.classicGold:
        return const AppThemeColors(
          background: black,
          surface: semiBlack,
          surfaceAlt: Color(0xFF151515),
          accent: gold,
          secondary: gold,
          text: Colors.white,
          mutedText: Colors.white70,
          border: gold,
          onAccent: black,
        );
      case AppThemePreset.neonBlue:
        return const AppThemeColors(
          background: Color(0xFF050B17),
          surface: Color(0xFF0B1628),
          surfaceAlt: Color(0xFF10243B),
          accent: Color(0xFF29C8FF),
          secondary: Color(0xFFEAF9FF),
          text: Color(0xFFF3FAFF),
          mutedText: Color(0xFFA8BED0),
          border: Color(0xFF237FA3),
          onAccent: Color(0xFF001018),
        );
      case AppThemePreset.neonGreen:
        return const AppThemeColors(
          background: Color(0xFF04120D),
          surface: Color(0xFF0A2017),
          surfaceAlt: Color(0xFF103225),
          accent: Color(0xFF35E89A),
          secondary: Color(0xFFC7FFE8),
          text: Color(0xFFEFFFF7),
          mutedText: Color(0xFFA1C7B4),
          border: Color(0xFF287D5B),
          onAccent: Color(0xFF001B10),
        );
      case AppThemePreset.royalPurple:
        return const AppThemeColors(
          background: Color(0xFF10091A),
          surface: Color(0xFF1C1230),
          surfaceAlt: Color(0xFF281A40),
          accent: Color(0xFFC59AFF),
          secondary: Color(0xFFF0E4FF),
          text: Color(0xFFFBF6FF),
          mutedText: Color(0xFFBDAFCF),
          border: Color(0xFF7952A6),
          onAccent: Color(0xFF1A0B29),
        );
      case AppThemePreset.classicLight:
        return const AppThemeColors(
          background: lightBackground,
          surface: lightSurface,
          surfaceAlt: lightSurfaceAlt,
          accent: lightPrimaryGreen,
          secondary: lightSecondaryGreen,
          text: darkText,
          mutedText: mediumText,
          border: lightBorder,
          onAccent: Colors.white,
        );
    }
  }

  static AppThemeColors get activePalette => paletteFor(currentPreset.value);

  static AppThemeColors colorsOf(BuildContext context) =>
      Theme.of(context).extension<AppThemeColors>() ?? activePalette;

  static ThemeData themeFor(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.classicGold:
        return darkTheme;
      case AppThemePreset.classicLight:
        return lightTheme;
      case AppThemePreset.neonBlue:
      case AppThemePreset.neonGreen:
      case AppThemePreset.royalPurple:
        return _buildNeonTheme(paletteFor(preset));
    }
  }

  /// الثيم الافتراضي الأصلي - بقيت ألوانه وقيمه الأساسية كما كانت.
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
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white70,
          fontSize: 14,
        ),
        labelSmall: TextStyle(
          fontFamily: _fontFamily,
          color: gold,
          fontSize: 12,
        ),
      ),
      extensions: [paletteFor(AppThemePreset.classicGold)],
    );
  }

  /// الوضع الفاتح الأصلي محفوظ للتوافق مع صفحة الإعدادات القديمة.
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
          color: darkText,
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
      extensions: [paletteFor(AppThemePreset.classicLight)],
    );
  }

  static ThemeData _buildNeonTheme(AppThemeColors palette) {
    final scheme = ColorScheme.dark(
      primary: palette.accent,
      secondary: palette.secondary,
      surface: palette.surface,
      error: redOffline,
      onPrimary: palette.onAccent,
      onSecondary: palette.onAccent,
      onSurface: palette.text,
      onError: Colors.white,
    );

    final baseTextTheme = ThemeData.dark().textTheme.apply(
          fontFamily: _fontFamily,
          bodyColor: palette.text,
          displayColor: palette.text,
        );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      primaryColor: palette.accent,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      iconTheme: IconThemeData(color: palette.accent),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: palette.accent,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: palette.accent,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: palette.accent,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: palette.text,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: palette.text),
        bodyMedium:
            baseTextTheme.bodyMedium?.copyWith(color: palette.mutedText),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: palette.text,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(color: palette.accent),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: palette.accent),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: palette.accent,
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: palette.background),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.accent,
        unselectedItemColor: palette.mutedText,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.accent.withOpacity(0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? palette.accent
                  : palette.mutedText,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: _fontFamily,
              color: states.contains(WidgetState.selected)
                  ? palette.accent
                  : palette.mutedText,
              fontWeight: FontWeight.w600,
            )),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border, width: 1.0),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.accent.withOpacity(0.25),
          disabledForegroundColor: palette.mutedText,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.accent,
          side: BorderSide(color: palette.border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: palette.accent),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: palette.border.withOpacity(0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: palette.accent, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: redOffline),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: redOffline, width: 1.6),
        ),
        labelStyle: TextStyle(color: palette.accent, fontFamily: _fontFamily),
        hintStyle:
            TextStyle(color: palette.mutedText, fontFamily: _fontFamily),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.accent,
        textColor: palette.text,
        selectedColor: palette.accent,
      ),
      dialogBackgroundColor: palette.surface,
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        textStyle: TextStyle(color: palette.text, fontFamily: _fontFamily),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          side: BorderSide(color: palette.border.withOpacity(0.7)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border.withOpacity(0.35),
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? palette.accent
                : palette.surfaceAlt),
        checkColor: WidgetStatePropertyAll(palette.onAccent),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(palette.accent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? palette.accent
                : palette.mutedText),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? palette.accent.withOpacity(0.35)
                : palette.surfaceAlt),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        inactiveTrackColor: palette.border.withOpacity(0.45),
        thumbColor: palette.accent,
        overlayColor: palette.accent.withOpacity(0.15),
        valueIndicatorColor: palette.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.border.withOpacity(0.25),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceAlt,
        contentTextStyle: TextStyle(
          color: palette.text,
          fontFamily: _fontFamily,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceAlt,
        selectedColor: palette.accent.withOpacity(0.22),
        disabledColor: palette.surfaceAlt.withOpacity(0.5),
        labelStyle: TextStyle(color: palette.text, fontFamily: _fontFamily),
        secondaryLabelStyle:
            TextStyle(color: palette.accent, fontFamily: _fontFamily),
        side: BorderSide(color: palette.border.withOpacity(0.55)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        textStyle: TextStyle(color: palette.text, fontFamily: _fontFamily),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accent.withOpacity(0.25),
        selectionHandleColor: palette.accent,
      ),
      extensions: [palette],
    );
  }
}
