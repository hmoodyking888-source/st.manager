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

  // مواقع نسبية (0..1)
  double _userX = 0.2, _userY = 0.3;
  double _passX = 0.2, _passY = 0.5;
  double _netX = 0.2, _netY = 0.65;
  double _durX = 0.2, _durY = 0.75;
  double _notesX = 0.2, _notesY = 0.85;

  List<String> _profiles = [];

  // نموذج النص التجريبي
  String get _previewUser => _generateSample(_userLength);
  String get _previewPass => _generateSample(_passLength);

  String _generateSample(int length) {
    if (length <= 0) return '';
    if (_charType == 'numbers')
      return List.generate(length, (i) => '${i % 10}').join();
    if (_charType == 'letters')
      return List.generate(length, (i) => String.fromCharCode(97 + (i % 26)))
          .join();
    return List.generate(length, (i) => '${i % 10}').join() + 'a';
  }

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

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final fontColor = PdfColor.fromInt(_fontColor.value);

    // صفحة A4 عمودية
    final pageFormat = PdfPageFormat.a4; // 210 x 297 mm
    final pageWidth = pageFormat.width;
    final pageHeight = pageFormat.height;

    // حساب الشبكة: نريد بطاقات بعرض 85mm وارتفاع 55mm (حجم بطاقة هوتسبوت نموذجي)
    const double cardW = 85.0;
    const double cardH = 55.0;
    final cols = (pageWidth / cardW).floor();
    final rows = (pageHeight / cardH).floor();
    final maxPerPage = cols * rows;

    // إنشاء صفحات متعددة إذا لزم الأمر
    int cardIndex = 0;
    while (cardIndex < _cardCount) {
      final page = pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          final List<pw.Widget> cards = [];
          for (int i = 0;
              i < maxPerPage && cardIndex < _cardCount;
              i++, cardIndex++) {
            final user = _generateRandom(
                lettersOnly: _charType == 'letters',
                numbersOnly: _charType == 'numbers');
            final pass = _generateRandom(
                lettersOnly: _charType == 'letters',
                numbersOnly: _charType == 'numbers');

            final card = pw.Container(
              width: cardW,
              height: cardH,
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 0.5)),
              child: pw.Stack(
                children: [
                  if (_templateImage != null)
                    pw.Image(
                      pw.MemoryImage(
                          File(_templateImage!.path).readAsBytesSync()),
                      fit: pw.BoxFit.cover,
                    ),
                  pw.Positioned(
                    left: _userX * cardW,
                    top: _userY * cardH,
                    child: pw.Text(user,
                        style: pw.TextStyle(
                            color: fontColor, fontSize: _fontSize)),
                  ),
                  pw.Positioned(
                    left: _passX * cardW,
                    top: _passY * cardH,
                    child: pw.Text(pass,
                        style: pw.TextStyle(
                            color: fontColor, fontSize: _fontSize)),
                  ),
                  if (_showNetwork)
                    pw.Positioned(
                      left: _netX * cardW,
                      top: _netY * cardH,
                      child: pw.Text(_networkCtrl.text,
                          style: pw.TextStyle(color: fontColor, fontSize: 10)),
                    ),
                  if (_showDuration)
                    pw.Positioned(
                      left: _durX * cardW,
                      top: _durY * cardH,
                      child: pw.Text(_durationCtrl.text,
                          style: pw.TextStyle(color: fontColor, fontSize: 10)),
                    ),
                  if (_showNotes)
                    pw.Positioned(
                      left: _notesX * cardW,
                      top: _notesY * cardH,
                      child: pw.Text(_notesCtrl.text,
                          style: pw.TextStyle(color: fontColor, fontSize: 10)),
                    ),
                ],
              ),
            );

            final col = i % cols;
            final row = i ~/ cols;
            cards.add(pw.Positioned(
              left: col * cardW,
              top: row * cardH,
              child: card,
            ));
          }
          return pw.Stack(children: cards);
        },
      );
      pdf.addPage(page);
    }

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      format: pageFormat,
      usePrinterSettings: true,
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('توليد البطاقات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // المعاينة المباشرة مع النصوص التجريبية
            if (_templateImage != null)
              Stack(
                children: [
                  Image.file(_templateImage!, height: 250, fit: BoxFit.contain),
                  // User
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
                        child: Text(_previewUser,
                            style: TextStyle(
                                color: _fontColor, fontSize: _fontSize)),
                      ),
                    ),
                  ),
                  // Pass
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
                        child: Text(_previewPass,
                            style: TextStyle(
                                color: _fontColor, fontSize: _fontSize)),
                      ),
                    ),
                  ),
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
                          child: Text(_networkCtrl.text,
                              style:
                                  TextStyle(color: _fontColor, fontSize: 10)),
                        ),
                      ),
                    ),
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
                          child: Text(_durationCtrl.text,
                              style:
                                  TextStyle(color: _fontColor, fontSize: 10)),
                        ),
                      ),
                    ),
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
                          child: Text(_notesCtrl.text,
                              style:
                                  TextStyle(color: _fontColor, fontSize: 10)),
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
                        onChanged: (v) => _cardCount = int.tryParse(v) ?? 10)),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        decoration:
                            const InputDecoration(labelText: 'طول اليوزر'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _userLength = int.tryParse(v) ?? 6)),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        decoration:
                            const InputDecoration(labelText: 'طول الباسوورد'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _passLength = int.tryParse(v) ?? 6)),
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
            // حجم الخط
            Row(
              children: [
                const Text('حجم الخط: ', style: TextStyle(color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 8,
                    max: 30,
                    divisions: 22,
                    label: _fontSize.round().toString(),
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
                Text(_fontSize.round().toString(),
                    style: const TextStyle(color: Colors.white)),
              ],
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
