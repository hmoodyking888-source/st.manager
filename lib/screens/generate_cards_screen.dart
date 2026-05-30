import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class GenerateCardsScreen extends StatefulWidget {
  final RouterService? routerService;
  const GenerateCardsScreen({super.key, required this.routerService});

  @override
  State<GenerateCardsScreen> createState() => _GenerateCardsScreenState();
}

class _GenerateCardsScreenState extends State<GenerateCardsScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  String _duration = '1h';
  List<String> _profiles = [];
  String? _selectedProfile;
  String _selectedTemplate = 'template1';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    if (widget.routerService == null) return;
    try {
      final res = await widget.routerService!
          .sendCommand('/ip/hotspot/user/profile/print');
      if (mounted) {
        setState(() {
          _profiles = res.map((e) => e['name'].toString()).toList();
          if (_profiles.isNotEmpty) _selectedProfile = _profiles.first;
        });
      }
    } catch (_) {}
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final goldColor = PdfColor.fromInt(0xFFD4AF37);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Container(
          color: PdfColors.black,
          padding: const pw.EdgeInsets.all(10),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('ST_Manager',
                  style: pw.TextStyle(color: goldColor, fontSize: 22)),
              pw.SizedBox(height: 10),
              pw.Text('User: ${_userController.text}',
                  style: const pw.TextStyle(color: PdfColors.white)),
              pw.Text('Pass: ${_passController.text}',
                  style: const pw.TextStyle(color: PdfColors.white)),
              pw.Text('Duration: $_duration',
                  style: const pw.TextStyle(color: PdfColors.white)),
              if (_selectedProfile != null)
                pw.Text('Profile: $_selectedProfile',
                    style: const pw.TextStyle(color: PdfColors.white)),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      format: const PdfPageFormat(80 * PdfPageFormat.mm, 50 * PdfPageFormat.mm),
      usePrinterSettings: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('توليد بطاقات جديدة')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _userController,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _duration,
                items: ['1h', '6h', '1d', '1w']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _duration = val!),
                decoration: const InputDecoration(labelText: 'المدة'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedProfile,
                items: _profiles
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedProfile = v),
                decoration: const InputDecoration(labelText: 'البروفايل'),
              ),
              const SizedBox(height: 16),
              Text('اختر قالب البطاقة',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['template1', 'template2', 'template3'].map((t) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTemplate = t),
                    child: Container(
                      width: 70,
                      height: 100,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedTemplate == t
                              ? AppTheme.gold
                              : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/images/templates/$t.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('تصدير PDF'),
                onPressed: _generatePdf,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
