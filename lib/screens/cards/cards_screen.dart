import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class CardsScreen extends StatefulWidget {
  final RouterService? routerService;
  const CardsScreen({super.key, required this.routerService});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  File? _templateImage;
  final ImagePicker _picker = ImagePicker();
  String _profile = 'default';
  int _cardCount = 1;
  int _userLength = 6;
  int _passLength = 6;
  String _charType = 'mixed';
  Color _fontColor = Colors.white;
  double _fontSize = 14;
  bool _showNetwork = true;
  final _networkCtrl = TextEditingController(text: 'ST_Manager');
  bool _showDuration = true;
  final _durationCtrl = TextEditingController(text: '1 يوم');
  bool _showNotes = false;
  final _notesCtrl = TextEditingController();
  double _userX = 0.1, _userY = 0.3;
  double _passX = 0.1, _passY = 0.5;
  double _notesX = 0.1, _notesY = 0.7;
  List<String> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    if (widget.routerService == null) return;
    try {
      final res = await widget.routerService!.getHotspotProfiles();
      setState(() => _profiles = res.map((e) => e['name'].toString()).toList());
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _templateImage = File(image.path));
    }
  }

  String _generateRandom({bool numbersOnly = false, bool lettersOnly = false}) {
    if (numbersOnly)
      return (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
          .toString();
    if (lettersOnly)
      return String.fromCharCodes(List.generate(
          6, (_) => 97 + (DateTime.now().microsecondsSinceEpoch % 26)));
    return (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
            .toString() +
        'ab';
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final goldColor = PdfColor.fromInt(0xFFD4AF37);
    final fontColor = PdfColor.fromInt(_fontColor.value);

    if (_templateImage != null) {
      final imgBytes = await _templateImage!.readAsBytes();
      final pdfImage = pw.MemoryImage(imgBytes);
      for (int i = 0; i < _cardCount; i++) {
        final user = _generateRandom(
            lettersOnly: _charType == 'letters',
            numbersOnly: _charType == 'numbers');
        final pass = _generateRandom(
            lettersOnly: _charType == 'letters',
            numbersOnly: _charType == 'numbers');
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            build: (context) => pw.Stack(
              children: [
                pw.Image(pdfImage, fit: pw.BoxFit.cover),
                pw.Positioned(
                  left: _userX * 80,
                  top: _userY * 50,
                  child: pw.Text(user,
                      style:
                          pw.TextStyle(color: fontColor, fontSize: _fontSize)),
                ),
                pw.Positioned(
                  left: _passX * 80,
                  top: _passY * 50,
                  child: pw.Text(pass,
                      style:
                          pw.TextStyle(color: fontColor, fontSize: _fontSize)),
                ),
                if (_showNetwork)
                  pw.Positioned(
                    left: _notesX * 80,
                    top: _notesY * 50,
                    child: pw.Text(_networkCtrl.text,
                        style: pw.TextStyle(color: fontColor, fontSize: 12)),
                  ),
                if (_showDuration)
                  pw.Positioned(
                    left: _notesX * 80,
                    top: (_notesY + 0.1) * 50,
                    child: pw.Text(_durationCtrl.text,
                        style: pw.TextStyle(color: fontColor, fontSize: 12)),
                  ),
                if (_showNotes)
                  pw.Positioned(
                    left: _notesX * 80,
                    top: (_notesY + 0.2) * 50,
                    child: pw.Text(_notesCtrl.text,
                        style: pw.TextStyle(color: fontColor, fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
      }
    } else {
      for (int i = 0; i < _cardCount; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.roll80,
            build: (context) => pw.Container(
              color: PdfColors.black,
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                children: [
                  pw.Text(_networkCtrl.text,
                      style: pw.TextStyle(color: goldColor, fontSize: 18)),
                  pw.Text(_generateRandom(),
                      style: pw.TextStyle(color: fontColor, fontSize: 16)),
                ],
              ),
            ),
          ),
        );
      }
    }
    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      format: const PdfPageFormat(80 * PdfPageFormat.mm, 50 * PdfPageFormat.mm),
      usePrinterSettings: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('توليد البطاقات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_templateImage != null)
              Stack(
                children: [
                  Image.file(_templateImage!, height: 200, fit: BoxFit.contain),
                  Positioned(
                    left: _userX * 150,
                    top: _userY * 200,
                    child: GestureDetector(
                      onPanUpdate: (details) => setState(() {
                        _userX += details.delta.dx / 150;
                        _userY += details.delta.dy / 200;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        color: Colors.red.withOpacity(0.5),
                        child: const Icon(Icons.drag_indicator,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text('رفع صورة قالب'),
                onPressed: _pickImage,
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField(
              value: _profile,
              items: _profiles
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _profile = v!),
              decoration: const InputDecoration(labelText: 'البروفايل'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration:
                        const InputDecoration(labelText: 'عدد البطاقات'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _cardCount = int.tryParse(v) ?? 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'طول اليوزر'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _userLength = int.tryParse(v) ?? 6,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration:
                        const InputDecoration(labelText: 'طول الباسوورد'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _passLength = int.tryParse(v) ?? 6,
                  ),
                ),
              ],
            ),
            DropdownButtonFormField(
              value: _charType,
              items: const [
                DropdownMenuItem(value: 'numbers', child: Text('أرقام فقط')),
                DropdownMenuItem(value: 'letters', child: Text('أحرف فقط')),
                DropdownMenuItem(value: 'mixed', child: Text('أحرف وأرقام')),
              ],
              onChanged: (v) => setState(() => _charType = v!),
              decoration: const InputDecoration(labelText: 'نوع الأحرف'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Colors.white,
                Colors.black,
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow
              ]
                  .map((c) => GestureDetector(
                        onTap: () => setState(() => _fontColor = c),
                        child: CircleAvatar(
                            backgroundColor: c,
                            radius: 15,
                            child: _fontColor == c
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null),
                      ))
                  .toList(),
            ),
            SwitchListTile(
                title: const Text('اسم الشبكة'),
                value: _showNetwork,
                onChanged: (v) => setState(() => _showNetwork = v)),
            if (_showNetwork)
              TextField(
                  controller: _networkCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الشبكة')),
            SwitchListTile(
                title: const Text('المدة'),
                value: _showDuration,
                onChanged: (v) => setState(() => _showDuration = v)),
            if (_showDuration)
              TextField(
                  controller: _durationCtrl,
                  decoration: const InputDecoration(labelText: 'المدة')),
            SwitchListTile(
                title: const Text('ملاحظات إضافية'),
                value: _showNotes,
                onChanged: (v) => setState(() => _showNotes = v)),
            if (_showNotes)
              TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات')),
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
