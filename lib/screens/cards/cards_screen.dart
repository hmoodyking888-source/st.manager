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
  double _networkFontSize = 12; // حجم خط اسم الشبكة
  double _durationFontSize = 10; // حجم خط المدة
  double _notesFontSize = 10; // حجم خط الملاحظات
  bool _showNetwork = true;
  final _networkCtrl = TextEditingController(text: 'ST_Manager');
  bool _showDuration = true;
  final _durationCtrl = TextEditingController(text: '1 يوم');
  bool _showNotes = false;
  final _notesCtrl = TextEditingController();

  // القوالب الافتراضية
  final List<Map<String, dynamic>> _defaultTemplates = [
    {
      'name': 'أسود وذهبي',
      'bgColor': const Color(0xFF000000),
      'borderColor': const Color(0xFFD4AF37),
      'textColor': Colors.white,
    },
    {
      'name': 'أزرق داكن',
      'bgColor': const Color(0xFF1A237E),
      'borderColor': const Color(0xFF42A5F5),
      'textColor': Colors.white,
    },
    {
      'name': 'أحمر أنيق',
      'bgColor': const Color(0xFFB71C1C),
      'borderColor': const Color(0xFFFFCDD2),
      'textColor': Colors.white,
    },
    {
      'name': 'أخضر طبيعي',
      'bgColor': const Color(0xFF1B5E20),
      'borderColor': const Color(0xFFA5D6A7),
      'textColor': Colors.white,
    },
    {
      'name': 'بنفسجي فاخر',
      'bgColor': const Color(0xFF4A148C),
      'borderColor': const Color(0xFFCE93D8),
      'textColor': Colors.white,
    },
    {
      'name': 'رمادي محايد',
      'bgColor': const Color(0xFF424242),
      'borderColor': const Color(0xFFBDBDBD),
      'textColor': Colors.white,
    },
  ];
  int _selectedTemplateIndex = 0;
  bool _useCustomImage = false; // هل نستخدم صورة مخصصة أم قالب افتراضي

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
    if (image != null) {
      setState(() {
        _templateImage = File(image.path);
        _useCustomImage = true;
      });
    }
  }

  void _selectTemplate(int index) {
    setState(() {
      _selectedTemplateIndex = index;
      _useCustomImage = false;
      _templateImage = null;
    });
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final fontColor = PdfColor.fromInt(_fontColor.value);

    final pageFormat = PdfPageFormat.a4;
    final pageWidth = pageFormat.width;
    final pageHeight = pageFormat.height;

    const double cardW = 85.0;
    const double cardH = 55.0;
    final cols = (pageWidth / cardW).floor();
    final rows = (pageHeight / cardH).floor();
    final maxPerPage = cols * rows;

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

            // خلفية القالب
            pw.Widget background;
            if (_useCustomImage && _templateImage != null) {
              background = pw.Image(
                pw.MemoryImage(File(_templateImage!.path).readAsBytesSync()),
                fit: pw.BoxFit.cover,
              );
            } else {
              final template = _defaultTemplates[_selectedTemplateIndex];
              background = pw.Container(
                color: PdfColor.fromInt(template['bgColor'].value),
              );
            }

            final card = pw.Container(
              width: cardW,
              height: cardH,
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 0.5)),
              child: pw.Stack(
                children: [
                  background,
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
                          style: pw.TextStyle(
                              color: fontColor, fontSize: _networkFontSize)),
                    ),
                  if (_showDuration)
                    pw.Positioned(
                      left: _durX * cardW,
                      top: _durY * cardH,
                      child: pw.Text(_durationCtrl.text,
                          style: pw.TextStyle(
                              color: fontColor, fontSize: _durationFontSize)),
                    ),
                  if (_showNotes)
                    pw.Positioned(
                      left: _notesX * cardW,
                      top: _notesY * cardH,
                      child: pw.Text(_notesCtrl.text,
                          style: pw.TextStyle(
                              color: fontColor, fontSize: _notesFontSize)),
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
            // اختيار القالب
            const Text('اختر قالب البطاقة:',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _defaultTemplates.length + 1, // +1 لخيار رفع صورة
                itemBuilder: (_, i) {
                  if (i < _defaultTemplates.length) {
                    final t = _defaultTemplates[i];
                    final isSelected =
                        !_useCustomImage && _selectedTemplateIndex == i;
                    return GestureDetector(
                      onTap: () => _selectTemplate(i),
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: t['bgColor'],
                          border: Border.all(
                            color:
                                isSelected ? AppTheme.gold : t['borderColor'],
                            width: isSelected ? 3 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(t['name'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: t['textColor'], fontSize: 10)),
                        ),
                      ),
                    );
                  } else {
                    // زر رفع صورة مخصصة
                    final isSelected = _useCustomImage;
                    return GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 70,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.darkGrey,
                          border: Border.all(
                            color: isSelected ? AppTheme.gold : Colors.grey,
                            width: isSelected ? 3 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                color: Colors.white54, size: 24),
                            Text('رفع صورة',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 9)),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            // المعاينة المباشرة مع النصوص التجريبية
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                color: _useCustomImage
                    ? null
                    : _defaultTemplates[_selectedTemplateIndex]['bgColor'],
              ),
              child: _useCustomImage && _templateImage != null
                  ? Stack(
                      children: [
                        Image.file(_templateImage!,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.contain),
                        _buildDraggablePreview(),
                      ],
                    )
                  : _buildDraggablePreview(),
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
            // حجم الخط لليوزر والباس
            Row(
              children: [
                const Text('حجم خط اليوزر/الباس: ',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
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
            // حجم خط اسم الشبكة
            Row(
              children: [
                const Text('حجم خط اسم الشبكة: ',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _networkFontSize,
                    min: 6,
                    max: 20,
                    divisions: 14,
                    label: _networkFontSize.round().toString(),
                    onChanged: (v) => setState(() => _networkFontSize = v),
                  ),
                ),
                Text(_networkFontSize.round().toString(),
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

  Widget _buildDraggablePreview() {
    return Stack(
      children: [
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
                  style: TextStyle(color: _fontColor, fontSize: _fontSize)),
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
                  style: TextStyle(color: _fontColor, fontSize: _fontSize)),
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
                    style: TextStyle(
                        color: _fontColor, fontSize: _networkFontSize)),
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
                    style: TextStyle(
                        color: _fontColor, fontSize: _durationFontSize)),
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
                        TextStyle(color: _fontColor, fontSize: _notesFontSize)),
              ),
            ),
          ),
      ],
    );
  }
}
