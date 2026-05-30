import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HotspotCardsScreen extends StatefulWidget {
  const HotspotCardsScreen({super.key});

  @override
  State<HotspotCardsScreen> createState() => _HotspotCardsScreenState();
}

class _HotspotCardsScreenState extends State<HotspotCardsScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  String _duration = '1h';

  void _generatePdf() async {
    final pdf = pw.Document();
    final goldColor = PdfColor.fromInt(0xFFD4AF37); // لون ذهبي مخصص
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
      appBar: AppBar(title: const Text('بطاقات الهوتسبوت')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              style: const TextStyle(color: Colors.white),
            ),
            DropdownButtonFormField<String>(
              value: _duration,
              items: ['1h', '6h', '1d', '1w']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _duration = val!),
              decoration: const InputDecoration(labelText: 'المدة'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('تصدير PDF'),
              onPressed: _generatePdf,
            ),
          ],
        ),
      ),
    );
  }
}
