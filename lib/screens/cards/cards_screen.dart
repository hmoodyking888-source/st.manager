import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class _CardTemplate {
  final String name;
  final String subtitle;
  final Color background;
  final Color backgroundSoft;
  final Color accent;
  final Color accentSoft;
  final Color border;
  final Color text;
  final Color mutedText;

  const _CardTemplate({
    required this.name,
    required this.subtitle,
    required this.background,
    required this.backgroundSoft,
    required this.accent,
    required this.accentSoft,
    required this.border,
    required this.text,
    required this.mutedText,
  });
}

class CardsScreen extends StatefulWidget {
  final RouterService? routerService;
  const CardsScreen({super.key, required this.routerService});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final Random _random = Random.secure();
  final ImagePicker _picker = ImagePicker();

  File? _templateImage;
  bool _useCustomImage = false;

  final _profileCtrl = TextEditingController(text: 'default');
  final _networkCtrl = TextEditingController(text: 'ST_Manager');
  final _durationCtrl = TextEditingController(text: '1 يوم');
  final _notesCtrl = TextEditingController();

  int _cardCount = 10;
  int _userLength = 6;
  int _passLength = 6;
  String _charType = 'mixed';
  Color _fontColor = Colors.white;
  double _fontSize = 14;
  double _networkFontSize = 12;
  double _durationFontSize = 10;
  double _notesFontSize = 10;
  bool _showNotes = false;

  final List<_CardTemplate> _templates = const [
    _CardTemplate(
      name: 'أسود وذهبي',
      subtitle: 'كلاسيكي وفخم',
      background: Color(0xFF111111),
      backgroundSoft: Color(0xFF1B1B1B),
      accent: Color(0xFFD4AF37),
      accentSoft: Color(0x66D4AF37),
      border: Color(0xFFD4AF37),
      text: Colors.white,
      mutedText: Color(0xFFBFBFBF),
    ),
    _CardTemplate(
      name: 'أخضر هادئ',
      subtitle: 'مريح للعين',
      background: Color(0xFF0F1A14),
      backgroundSoft: Color(0xFF173024),
      accent: Color(0xFF4CAF50),
      accentSoft: Color(0x664CAF50),
      border: Color(0xFF6CCF73),
      text: Colors.white,
      mutedText: Color(0xFFCDE8CF),
    ),
    _CardTemplate(
      name: 'أزرق شبكي',
      subtitle: 'تقني وواضح',
      background: Color(0xFF101A2E),
      backgroundSoft: Color(0xFF18264A),
      accent: Color(0xFF42A5F5),
      accentSoft: Color(0x6642A5F5),
      border: Color(0xFF8BCBFF),
      text: Colors.white,
      mutedText: Color(0xFFD4E6FA),
    ),
    _CardTemplate(
      name: 'بنفسجي فاخر',
      subtitle: 'أنيق وحديث',
      background: Color(0xFF1E1027),
      backgroundSoft: Color(0xFF34194B),
      accent: Color(0xFFBA68C8),
      accentSoft: Color(0x66BA68C8),
      border: Color(0xFFD49DE3),
      text: Colors.white,
      mutedText: Color(0xFFF0D8F6),
    ),
    _CardTemplate(
      name: 'فاتح ناعم',
      subtitle: 'مناسب للطباعة',
      background: Color(0xFFF5F7F2),
      backgroundSoft: Color(0xFFEAF1E7),
      accent: Color(0xFF2E7D32),
      accentSoft: Color(0x332E7D32),
      border: Color(0xFFBFD6C1),
      text: Color(0xFF1E2A1F),
      mutedText: Color(0xFF667166),
    ),
  ];

  int _selectedTemplateIndex = 0;
  final List<String> _profiles = [];

  double _userX = 0.12;
  double _userY = 0.35;
  double _passX = 0.12;
  double _passY = 0.56;
  double _netX = 0.12;
  double _netY = 0.12;
  double _durX = 0.12;
  double _durY = 0.77;
  double _notesX = 0.58;
  double _notesY = 0.77;
  double _profileX = 0.72;
  double _profileY = 0.12;

  String get _previewUser => _generateRandom(length: _userLength);
  String get _previewPass => _generateRandom(length: _passLength);

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _profileCtrl.dispose();
    _networkCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double _clamp01(num value) => value.clamp(0.0, 1.0).toDouble();

  Future<void> _loadProfiles() async {
    if (widget.routerService == null) return;

    try {
      final res = await widget.routerService!.getHotspotProfiles();
      final names = res
          .map((e) => e['name']?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _profiles
          ..clear()
          ..addAll(names);

        if (_profiles.isNotEmpty &&
            !_profiles.contains(_profileCtrl.text.trim())) {
          _profileCtrl.text = _profiles.first;
        }
      });
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    if (!mounted) return;
    setState(() {
      _templateImage = File(image.path);
      _useCustomImage = true;
    });
  }

  void _selectTemplate(int index) {
    setState(() {
      _selectedTemplateIndex = index;
      _useCustomImage = false;
      _templateImage = null;
    });
  }

  String _generateRandom({required int length}) {
    if (length <= 0) return '';

    const numbers = '0123456789';
    const letters = 'abcdefghijklmnopqrstuvwxyz';

    final chars = switch (_charType) {
      'numbers' => numbers,
      'letters' => letters,
      _ => '$numbers$letters',
    };

    return List.generate(length, (_) => chars[_random.nextInt(chars.length)])
        .join();
  }

  _CardTemplate get _currentTemplate => _templates[_selectedTemplateIndex];

  Future<void> _generatePdf() async {
    try {
      final pdf = pw.Document();
      final template = _currentTemplate;
      final pageFormat = PdfPageFormat.a4.landscape;
      final cardW = 85 * PdfPageFormat.mm;
      final cardH = 55 * PdfPageFormat.mm;
      const margin = 10.0;
      const spacing = 5.0;

      final usableW = pageFormat.width - (margin * 2);
      final usableH = pageFormat.height - (margin * 2);

      final cols = max(1, ((usableW + spacing) / (cardW + spacing)).floor());
      final rows = max(1, ((usableH + spacing) / (cardH + spacing)).floor());
      final cardsPerPage = cols * rows;

      final totalCards = _cardCount < 1 ? 1 : _cardCount;
      final imageBytes =
          _templateImage != null ? _templateImage!.readAsBytesSync() : null;

      for (int pageStart = 0;
          pageStart < totalCards;
          pageStart += cardsPerPage) {
        final children = <pw.Widget>[];

        for (int slot = 0; slot < cardsPerPage; slot++) {
          final index = pageStart + slot;
          if (index >= totalCards) break;

          final user = _generateRandom(length: _userLength);
          final pass = _generateRandom(length: _passLength);

          final col = slot % cols;
          final row = slot ~/ cols;

          final left = margin + (col * (cardW + spacing));
          final top = margin + (row * (cardH + spacing));

          children.add(
            pw.Positioned(
              left: left,
              top: top,
              child: _buildPdfCard(
                template: template,
                imageBytes: imageBytes,
                user: user,
                pass: pass,
                profile: _profileCtrl.text.trim(),
                network: _networkCtrl.text.trim(),
                duration: _durationCtrl.text.trim(),
                notes: _showNotes ? _notesCtrl.text.trim() : '',
                cardW: cardW,
                cardH: cardH,
              ),
            ),
          );
        }

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Stack(children: children),
          ),
        );
      }

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        format: pageFormat,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تصدير PDF: $e')),
      );
    }
  }

  pw.Widget _buildPdfField({
    required String label,
    required String value,
    required PdfColor textColor,
    required PdfColor accentColor,
    required double labelSize,
    required double valueSize,
    bool compact = false,
  }) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 4 : 5,
      ),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0x22FFFFFF),
        borderRadius: pw.BorderRadius.circular(7),
        border: pw.Border.all(
          color: PdfColor.fromInt(0x22FFFFFF),
          width: 0.6,
        ),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: accentColor,
              fontSize: labelSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              color: textColor,
              fontSize: valueSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfCard({
    required _CardTemplate template,
    required Uint8List? imageBytes,
    required String user,
    required String pass,
    required String profile,
    required String network,
    required String duration,
    required String notes,
    required double cardW,
    required double cardH,
  }) {
    final bg = PdfColor.fromInt(template.background.value);
    final bgSoft = PdfColor.fromInt(template.backgroundSoft.value);
    final accent = PdfColor.fromInt(template.accent.value);
    final accentSoft = PdfColor.fromInt(template.accentSoft.value);
    final border = PdfColor.fromInt(template.border.value);
    final text = PdfColor.fromInt(template.text.value);

    return pw.Container(
      width: cardW,
      height: cardH,
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: border, width: 0.8),
      ),
      child: pw.Stack(
        children: [
          if (imageBytes != null)
            pw.Positioned.fill(
              child: pw.ClipRRect(
                horizontalRadius: 10,
                verticalRadius: 10,
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  fit: pw.BoxFit.cover,
                ),
              ),
            )
          else
            pw.Positioned.fill(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  color: bg,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
              ),
            ),
          if (imageBytes == null) ...[
            pw.Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: pw.SizedBox(
                width: 7,
                child: pw.Container(color: accent),
              ),
            ),
            pw.Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: pw.SizedBox(
                height: 7,
                child: pw.Container(color: bgSoft),
              ),
            ),
          ],
          if (imageBytes != null)
            pw.Positioned.fill(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(10),
                  color: PdfColor.fromInt(0x4D000000),
                ),
              ),
            ),
          pw.Positioned(
            left: 8,
            top: 8,
            child: _buildPdfField(
              label: 'اسم الشبكة',
              value: network,
              textColor: text,
              accentColor: accent,
              labelSize: 7.5,
              valueSize: 11,
            ),
          ),
          if (profile.isNotEmpty)
            pw.Positioned(
              left: cardW * 0.68,
              top: cardH * 0.14,
              child: pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: accentSoft,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  profile,
                  style: pw.TextStyle(
                    color: text,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          pw.Positioned(
            left: cardW * 0.12,
            top: cardH * 0.35,
            child: _buildPdfField(
              label: 'USER',
              value: user,
              textColor: text,
              accentColor: accent,
              labelSize: 7,
              valueSize: 13,
            ),
          ),
          pw.Positioned(
            left: cardW * 0.12,
            top: cardH * 0.56,
            child: _buildPdfField(
              label: 'PASSWORD',
              value: pass,
              textColor: text,
              accentColor: accent,
              labelSize: 7,
              valueSize: 13,
            ),
          ),
          pw.Positioned(
            left: cardW * 0.12,
            top: cardH * 0.77,
            child: _buildPdfField(
              label: 'المدة',
              value: duration,
              textColor: text,
              accentColor: accent,
              labelSize: 7.5,
              valueSize: 10.5,
              compact: true,
            ),
          ),
          if (notes.isNotEmpty)
            pw.Positioned(
              left: cardW * 0.58,
              top: cardH * 0.77,
              child: _buildPdfField(
                label: 'ملاحظات',
                value: notes,
                textColor: text,
                accentColor: accent,
                labelSize: 7.5,
                valueSize: 9.5,
                compact: true,
              ),
            ),
          pw.Positioned(
            left: 8,
            bottom: 6,
            child: pw.Text(
              'Hotspot Access Card',
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFFBFBFBF),
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          if (imageBytes != null)
            pw.Positioned(
              right: 8,
              bottom: 6,
              child: pw.Text(
                'صورة من المعرض',
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0xFFFFFFFF),
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldBlock({
    required String label,
    required String value,
    required Color textColor,
    required Color accentColor,
    required Color borderColor,
    required double labelSize,
    required double valueSize,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withOpacity(0.75), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: labelSize,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: valueSize,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableField({
    required double x,
    required double y,
    required void Function(Offset delta) onMove,
    required Widget child,
    required double width,
    required double height,
  }) {
    return Positioned(
      left: x * width,
      top: y * height,
      child: GestureDetector(
        onPanUpdate: (details) => onMove(details.delta),
        child: child,
      ),
    );
  }

  Widget _buildPreviewCard(double width, double height) {
    final template = _currentTemplate;
    final textColor = _fontColor;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [template.background, template.backgroundSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: template.border.withOpacity(0.9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: template.accent.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -20,
            top: -18,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: template.accentSoft.withOpacity(0.28),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -18,
            bottom: -16,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: template.accentSoft.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: 10,
            child: Container(color: template.accent),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 8,
            child: Container(color: template.accentSoft.withOpacity(0.85)),
          ),
          if (_useCustomImage && _templateImage != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  _templateImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (_useCustomImage && _templateImage != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.black.withOpacity(0.28),
                ),
              ),
            ),
          _buildDraggableField(
            x: _netX,
            y: _netY,
            width: width,
            height: height,
            onMove: (delta) {
              setState(() {
                _netX = _clamp01(_netX + (delta.dx / width));
                _netY = _clamp01(_netY + (delta.dy / height));
              });
            },
            child: SizedBox(
              width: width * 0.55,
              child: _buildFieldBlock(
                label: 'اسم الشبكة',
                value: _networkCtrl.text.trim(),
                textColor: textColor,
                accentColor: template.accent,
                borderColor: template.border,
                labelSize: 10,
                valueSize: _networkFontSize,
                compact: false,
              ),
            ),
          ),
          if (_profileCtrl.text.trim().isNotEmpty)
            _buildDraggableField(
              x: _profileX,
              y: _profileY,
              width: width,
              height: height,
              onMove: (delta) {
                setState(() {
                  _profileX = _clamp01(_profileX + (delta.dx / width));
                  _profileY = _clamp01(_profileY + (delta.dy / height));
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: template.accentSoft.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: template.accent.withOpacity(0.7),
                    width: 1,
                  ),
                ),
                child: Text(
                  _profileCtrl.text.trim(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          _buildDraggableField(
            x: _userX,
            y: _userY,
            width: width,
            height: height,
            onMove: (delta) {
              setState(() {
                _userX = _clamp01(_userX + (delta.dx / width));
                _userY = _clamp01(_userY + (delta.dy / height));
              });
            },
            child: SizedBox(
              width: width * 0.44,
              child: _buildFieldBlock(
                label: 'USER',
                value: _previewUser,
                textColor: textColor,
                accentColor: template.accent,
                borderColor: template.border,
                labelSize: 9,
                valueSize: _fontSize,
                compact: false,
              ),
            ),
          ),
          _buildDraggableField(
            x: _passX,
            y: _passY,
            width: width,
            height: height,
            onMove: (delta) {
              setState(() {
                _passX = _clamp01(_passX + (delta.dx / width));
                _passY = _clamp01(_passY + (delta.dy / height));
              });
            },
            child: SizedBox(
              width: width * 0.44,
              child: _buildFieldBlock(
                label: 'PASSWORD',
                value: _previewPass,
                textColor: textColor,
                accentColor: template.accent,
                borderColor: template.border,
                labelSize: 9,
                valueSize: _fontSize,
                compact: false,
              ),
            ),
          ),
          _buildDraggableField(
            x: _durX,
            y: _durY,
            width: width,
            height: height,
            onMove: (delta) {
              setState(() {
                _durX = _clamp01(_durX + (delta.dx / width));
                _durY = _clamp01(_durY + (delta.dy / height));
              });
            },
            child: SizedBox(
              width: width * 0.24,
              child: _buildFieldBlock(
                label: 'المدة',
                value: _durationCtrl.text.trim(),
                textColor: textColor,
                accentColor: template.accent,
                borderColor: template.border,
                labelSize: 9,
                valueSize: _durationFontSize,
                compact: true,
              ),
            ),
          ),
          if (_showNotes)
            _buildDraggableField(
              x: _notesX,
              y: _notesY,
              width: width,
              height: height,
              onMove: (delta) {
                setState(() {
                  _notesX = _clamp01(_notesX + (delta.dx / width));
                  _notesY = _clamp01(_notesY + (delta.dy / height));
                });
              },
              child: SizedBox(
                width: width * 0.34,
                child: _buildFieldBlock(
                  label: 'ملاحظات',
                  value: _notesCtrl.text.trim(),
                  textColor: textColor,
                  accentColor: template.accent,
                  borderColor: template.border,
                  labelSize: 8,
                  valueSize: _notesFontSize,
                  compact: true,
                ),
              ),
            ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Text(
              template.subtitle,
              style: TextStyle(
                color: template.mutedText,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_useCustomImage && _templateImage != null)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'صورة من المعرض',
                  style: TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateChip(_CardTemplate template, int index) {
    final selected = _selectedTemplateIndex == index;

    return GestureDetector(
      onTap: () => _selectTemplate(index),
      child: Container(
        width: 95,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [template.background, template.backgroundSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.gold : template.border.withOpacity(0.7),
            width: selected ? 2.2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              template.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: template.text,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              template.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: template.mutedText,
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInput() {
    if (_profiles.isNotEmpty) {
      final current = _profiles.contains(_profileCtrl.text.trim())
          ? _profileCtrl.text.trim()
          : _profiles.first;

      if (_profileCtrl.text.trim().isEmpty) {
        _profileCtrl.text = current;
      }

      return DropdownButtonFormField<String>(
        value: current,
        isExpanded: true,
        dropdownColor: AppTheme.semiBlack,
        decoration: const InputDecoration(labelText: 'البروفايل'),
        items: _profiles
            .map(
              (p) => DropdownMenuItem<String>(
                value: p,
                child: Text(p),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() => _profileCtrl.text = v);
        },
      );
    }

    return TextField(
      controller: _profileCtrl,
      decoration: const InputDecoration(
        labelText: 'البروفايل',
        hintText: 'مثلاً default',
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewWidth = MediaQuery.of(context).size.width - 32;
    const previewHeight = 260.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('توليد بطاقات الهوتسبوت'),
        actions: [
          IconButton(
            onPressed: _loadProfiles,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البروفايلات',
          ),
          IconButton(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library),
            tooltip: 'رفع صورة من المعرض',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر قالب البطاقة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _templates.length + 1,
                itemBuilder: (_, i) {
                  if (i < _templates.length) {
                    return _buildTemplateChip(_templates[i], i);
                  }

                  final selected = _useCustomImage;
                  return GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 95,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppTheme.gold : Colors.grey,
                          width: selected ? 2.2 : 1,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              color: Colors.white54, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'رفع صورة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: previewHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24),
              ),
              child: Stack(
                children: [
                  if (_useCustomImage && _templateImage != null)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          _templateImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildPreviewCard(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileInput(),
            const SizedBox(height: 12),
            TextField(
              controller: _networkCtrl,
              decoration: const InputDecoration(labelText: 'اسم الشبكة'),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationCtrl,
              decoration: const InputDecoration(labelText: 'المدة'),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text(
                'إظهار الملاحظات',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'يمكنك إضافة ملاحظات اختيارية على البطاقة',
                style: TextStyle(color: Colors.white54),
              ),
              value: _showNotes,
              onChanged: (value) => setState(() => _showNotes = value),
              activeColor: AppTheme.gold,
            ),
            if (_showNotes) ...[
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration:
                        const InputDecoration(labelText: 'عدد البطاقات'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _cardCount = int.tryParse(v) ?? 10,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'طول اليوزر'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _userLength = int.tryParse(v) ?? 6,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration:
                        const InputDecoration(labelText: 'طول الباسوورد'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _passLength = int.tryParse(v) ?? 6,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _charType,
              dropdownColor: AppTheme.semiBlack,
              decoration: const InputDecoration(labelText: 'نوع الأحرف'),
              items: const [
                DropdownMenuItem(value: 'numbers', child: Text('أرقام فقط')),
                DropdownMenuItem(value: 'letters', child: Text('أحرف فقط')),
                DropdownMenuItem(value: 'mixed', child: Text('أحرف وأرقام')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _charType = v);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'حجم خط النص الأساسي: ',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
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
                Text(
                  _fontSize.round().toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            Row(
              children: [
                const Text(
                  'حجم خط اسم الشبكة: ',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: _networkFontSize,
                    min: 8,
                    max: 22,
                    divisions: 14,
                    label: _networkFontSize.round().toString(),
                    onChanged: (v) => setState(() => _networkFontSize = v),
                  ),
                ),
                Text(
                  _networkFontSize.round().toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            Row(
              children: [
                const Text(
                  'حجم خط المدة: ',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: _durationFontSize,
                    min: 7,
                    max: 18,
                    divisions: 11,
                    label: _durationFontSize.round().toString(),
                    onChanged: (v) => setState(() => _durationFontSize = v),
                  ),
                ),
                Text(
                  _durationFontSize.round().toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Colors.white,
                Colors.black,
                Colors.red,
                Colors.blue,
                Colors.green
              ]
                  .map(
                    (c) => GestureDetector(
                      onTap: () => setState(() => _fontColor = c),
                      child: CircleAvatar(
                        backgroundColor: c,
                        radius: 15,
                        child: _fontColor == c
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    ),
                  )
                  .toList(),
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
