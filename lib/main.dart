import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:st_manager/screens/login_screen.dart';
import 'package:st_manager/screens/routers_screen.dart';
import 'package:st_manager/screens/dashboard_screen.dart';
import 'package:st_manager/screens/settings_screen.dart';
import 'package:st_manager/services/secure_storage_service.dart';
import 'package:st_manager/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SplashScreen());

  try {
    await Firebase.initializeApp();
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
    return;
  }

  runApp(const MyApp());
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined,
                  size: 80, color: const Color(0xFFD4AF37)),
              const SizedBox(height: 16),
              const Text('ST_Manager',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFFD4AF37),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 8),
              const CircularProgressIndicator(color: Color(0xFFD4AF37)),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('فشل الاتصال بقاعدة البيانات:\n$error',
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center),
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
    final themeMode = await _storage.read('theme_mode');
    if (themeMode == 'light') {
      setState(() => _themeMode = ThemeMode.light);
    }
  }

  void changeTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await _storage.write(
        'theme_mode', mode == ThemeMode.light ? 'light' : 'dark');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ST_Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/routers': (_) => const RoutersScreen(),
        '/dashboard': (_) {
          final args =
              ModalRoute.of(_)!.settings.arguments as Map<String, String>;
          return DashboardScreen(routerData: args);
        },
        '/settings': (_) => SettingsScreen(
            onThemeChanged: changeTheme, currentMode: _themeMode),
      },
    );
  }
}
