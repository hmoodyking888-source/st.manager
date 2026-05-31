import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/screens/applications/scripts_screen.dart';
import 'package:st_manager/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ApplicationsScreen extends StatefulWidget {
  final RouterService? routerService;
  const ApplicationsScreen({super.key, required this.routerService});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  void _openBot() async {
    const url = 'https://t.me/ST_ManagerBot';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _fixLoop() {
    // اكتشاف وإصلاح اللوب
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التطبيقات')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildButton('سكربتات', Icons.code, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ScriptsScreen(
                              routerService: widget.routerService)));
                }),
                _buildButton('تخفيض البينغ', Icons.speed, () {}),
                _buildButton('فتح السرعة', Icons.bolt, () {}),
                _buildButton('إصلاح', Icons.build, _fixLoop),
                _buildButton('تفعيل البوت', Icons.telegram, _openBot),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String label, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.gold, size: 40),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
