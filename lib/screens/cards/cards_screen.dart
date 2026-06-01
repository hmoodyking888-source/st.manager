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
  int _cardCount = 10;
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

  // مواقع مستقلة لكل عنصر (نسبة من 0 إلى 1)
  double _userX = 0.2, _userY = 0.3;
  double _passX = 0.2, _passY = 0.5;
  double _netX = 0.2, _netY = 0.65;
  double _durX = 0.2, _durY = 0.75;
  double _notesX = 0.2, _notesY = 0.85;

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
    if (image != null) setState(() => _templateImage = File(image.path));
  }

  String _generateRandom({bool numbersOnly = false, bool lettersOnly = false}) {
    if (numbersOnly) {
      return List.generate(_userLength,
              (_) => (DateTime.now().microsecondsSinceEpoch % 10).toString())
          .join();
    }
    if (lettersOnly) {
      return List.generate(
          _userLength,
          (_) => String.fromCharCode(
              97 + (DateTime.now().microsecondsSinceEpoch % 26))).join();
    }
    return List.generate(_userLength,
                (_) => (DateTime.now().microsecondsSinceEpoch % 10).toString())
            .join() +
        String.fromCharCode(97 + (DateTime.now().microsecondsSinceEpoch % 26));
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final fontColor = PdfColor.fromInt(_fontColor.value);

    // حساب الشبكة
    int cols, rows;
    if (_cardCount >= 40) {
      cols = 5;
      rows = 8;
    } else if (_cardCount >= 20) {
      cols = 4;
      rows = 5;
    } else {
      cols = 3;
      rows = (_cardCount / 3).ceil();
    }

    final pageWidth = 80.0 * PdfPageFormat.mm;
    final pageHeight = 50.0 * PdfPageFormat.mm;
    final cardWidth = pageWidth / cols;
    final cardHeight = pageHeight / rows;

    // إنشاء صفحة واحدة تحتوي على شبكة البطاقات
    final page = pw.Page(
      pageFormat:
          const PdfPageFormat(80 * PdfPageFormat.mm, 50 * PdfPageFormat.mm),
      build: (context) {
        final List<pw.Widget> cards = [];
        for (int i = 0; i < _cardCount; i++) {
          final user = _generateRandom(
              lettersOnly: _charType == 'letters',
              numbersOnly: _charType == 'numbers');
          final pass = _generateRandom(
              lettersOnly: _charType == 'letters',
              numbersOnly: _charType == 'numbers');

          // حاوية بعرض وارتفاع محددين
          final card = pw.Container(
            width: cardWidth,
            height: cardHeight,
            child: pw.Stack(
              children: [
                if (_templateImage != null)
                  pw.Image(
                    pw.MemoryImage(
                        File(_templateImage!.path).readAsBytesSync()),
                    fit: pw.BoxFit.cover,
                  ),
                // النصوص تتحرك حسب المواقع النسبية
                pw.Positioned(
                  left: _userX * cardWidth,
                  top: _userY * cardHeight,
                  child: pw.Text(user,
                      style:
                          pw.TextStyle(color: fontColor, fontSize: _fontSize)),
                ),
                pw.Positioned(
                  left: _passX * cardWidth,
                  top: _passY * cardHeight,
                  child: pw.Text(pass,
                      style:
                          pw.TextStyle(color: fontColor, fontSize: _fontSize)),
                ),
                if (_showNetwork)
                  pw.Positioned(
                    left: _netX * cardWidth,
                    top: _netY * cardHeight,
                    child: pw.Text(_networkCtrl.text,
                        style: pw.TextStyle(color: fontColor, fontSize: 10)),
                  ),
                if (_showDuration)
                  pw.Positioned(
                    left: _durX * cardWidth,
                    top: _durY * cardHeight,
                    child: pw.Text(_durationCtrl.text,
                        style: pw.TextStyle(color: fontColor, fontSize: 10)),
                  ),
                if (_showNotes)
                  pw.Positioned(
                    left: _notesX * cardWidth,
                    top: _notesY * cardHeight,
                    child: pw.Text(_notesCtrl.text,
                        style: pw.TextStyle(color: fontColor, fontSize: 10)),
                  ),
              ],
            ),
          );

          cards.add(
            pw.Positioned(
              left: (i % cols) * cardWidth,
              top: (i ~/ cols) * cardHeight,
              child: card,
            ),
          );
        }
        return pw.Stack(children: cards);
      },
    );
    pdf.addPage(page);

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
            // معاينة القالب مع عناصر قابلة للسحب
            if (_templateImage != null)
              Stack(
                children: [
                  Image.file(_templateImage!, height: 250, fit: BoxFit.contain),
                  // عنصر اليوزر
                  Positioned(
                    left: _userX * 200,
                    top: _userY * 250,
                    child: GestureDetector(
                      onPanUpdate: (d) => setState(() {
                        _userX += d.delta.dx / 200;
                        _userY += d.delta.dy / 250;
                      }),
                      child: Container(
                        color: Colors.red.withOpacity(0.3),
                        child: const Text('User',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ),
                  // عنصر الباس
                  Positioned(
                    left: _passX * 200,
                    top: _passY * 250,
                    child: GestureDetector(
                      onPanUpdate: (d) => setState(() {
                        _passX += d.delta.dx / 200;
                        _passY += d.delta.dy / 250;
                      }),
                      child: Container(
                        color: Colors.blue.withOpacity(0.3),
                        child: const Text('Pass',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ),
                  // الشبكة
                  if (_showNetwork)
                    Positioned(
                      left: _netX * 200,
                      top: _netY * 250,
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() {
                          _netX += d.delta.dx / 200;
                          _netY += d.delta.dy / 250;
                        }),
                        child: Container(
                          color: Colors.green.withOpacity(0.3),
                          child: const Text('Net',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                    ),
                  // المدة
                  if (_showDuration)
                    Positioned(
                      left: _durX * 200,
                      top: _durY * 250,
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() {
                          _durX += d.delta.dx / 200;
                          _durY += d.delta.dy / 250;
                        }),
                        child: Container(
                          color: Colors.yellow.withOpacity(0.3),
                          child: const Text('Dur',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                    ),
                  // ملاحظات
                  if (_showNotes)
                    Positioned(
                      left: _notesX * 200,
                      top: _notesY * 250,
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() {
                          _notesX += d.delta.dx / 200;
                          _notesY += d.delta.dy / 250;
                        }),
                        child: Container(
                          color: Colors.purple.withOpacity(0.3),
                          child: const Text('Notes',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 10)),
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
            // إعدادات
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
                    onChanged: (v) => _cardCount = int.tryParse(v) ?? 10,
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
            // اختيار اللون
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Colors.white,
                Colors.black,
                Colors.red,
                Colors.blue,
                Colors.green
              ]
                  .map((c) => GestureDetector(
                        onTap: () => setState(() => _fontColor = c),
                        child: CircleAvatar(
                          backgroundColor: c,
                          radius: 15,
                          child: _fontColor == c
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
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
