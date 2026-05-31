import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/screens/ppp/ppp_active_screen.dart';
import 'package:st_manager/theme/app_theme.dart';

class PppMenuScreen extends StatelessWidget {
  final RouterService? routerService;
  const PppMenuScreen({super.key, required this.routerService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('البرودباند')),
      body: Center(
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildOption(context, 'المتصلون الآن', Icons.people, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          PppActiveScreen(routerService: routerService)));
            }),
            _buildOption(context, 'إضافة حساب', Icons.person_add, () {
              // إضافة PPP secret
            }),
            _buildOption(context, 'تعديل حساب', Icons.edit, () {
              // تعديل
            }),
            _buildOption(context, 'الأسرار (Secrets)', Icons.vpn_key, () {
              // عرض جميع الأسرار
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.gold, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.semiBlack,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.gold, size: 40),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
