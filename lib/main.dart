import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:st_manager/screens/login_screen.dart';
import 'package:st_manager/screens/routers_screen.dart';
import 'package:st_manager/screens/dashboard_screen.dart';
import 'package:st_manager/screens/settings_screen.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final Future<FirebaseApp> _firebaseInit;

  @override
  void initState() {
    super.initState();
    _firebaseInit = Firebase.initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _firebaseInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LaunchAppShell(child: _LaunchSplash());
        }

        if (snapshot.hasError) {
          return _LaunchAppShell(
            child: _LaunchError(error: snapshot.error.toString()),
          );
        }

        return const MyApp();
      },
    );
  }
}

class _LaunchAppShell extends StatelessWidget {
  final Widget child;

  const _LaunchAppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: child,
    );
  }
}

class _LaunchSplash extends StatelessWidget {
  const _LaunchSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 80,
              color: AppTheme.gold,
            ),
            const SizedBox(height: 16),
            const Text(
              'ST_Manager',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFFD4AF37),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const CircularProgressIndicator(color: Color(0xFFD4AF37)),
          ],
        ),
      ),
    );
  }
}

class _LaunchError extends StatelessWidget {
  final String error;

  const _LaunchError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'فشل الاتصال بقاعدة البيانات:\n$error',
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  final SecureStorageService _storage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      // المفتاح الجديد يحفظ الثيمات الأربعة، مع دعم قيمة theme_mode القديمة.
      final savedPresetId = await _storage.read('app_theme_id');
      final savedPreset = AppTheme.presetFromId(savedPresetId);

      if (savedPreset != null) {
        AppTheme.setCurrentPreset(savedPreset);
        if (!mounted) return;
        setState(() {
          _themeMode = AppTheme.isLightPreset(savedPreset)
              ? ThemeMode.light
              : ThemeMode.dark;
        });
        return;
      }

      final oldThemeMode = await _storage.read('theme_mode');
      final legacyPreset = oldThemeMode == 'light'
          ? AppThemePreset.classicLight
          : AppThemePreset.classicGold;

      AppTheme.setCurrentPreset(legacyPreset);
      if (!mounted) return;
      setState(() {
        _themeMode = oldThemeMode == 'light' ? ThemeMode.light : ThemeMode.dark;
      });
    } catch (_) {
      // في حال تعذر قراءة التخزين يبقى الثيم الافتراضي الذهبي كما هو.
    }
  }

  Future<void> changeTheme(ThemeMode mode) async {
    if (!mounted) return;

    final preset = mode == ThemeMode.light
        ? AppThemePreset.classicLight
        : AppThemePreset.classicGold;

    setState(() => _themeMode = mode);
    AppTheme.setCurrentPreset(preset);

    await _storage.write(
      'theme_mode',
      mode == ThemeMode.light ? 'light' : 'dark',
    );
    await _storage.write('app_theme_id', AppTheme.presetId(preset));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.currentPreset,
      builder: (context, preset, child) {
        return MaterialApp(
          title: 'ST_Manager',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeFor(preset),
          // استخدام الثيم المختار مباشرةً ومنع تبديله حسب وضع الجهاز.
          themeMode: ThemeMode.light,
          initialRoute: '/login',
          routes: {
            '/login': (_) => const LoginScreen(),
            '/routers': (_) => const RoutersScreen(),
            '/dashboard': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is Map<String, String>) {
                return DashboardScreen(routerData: args);
              }

              return const Scaffold(
                body: Center(child: Text('Missing dashboard arguments')),
              );
            },
            '/settings': (_) => SettingsScreen(
                  onThemeChanged: changeTheme,
                  currentMode: AppTheme.isLightPreset(preset)
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
          },
        );
      },
    );
  }
}
