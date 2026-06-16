import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

// ─────────────────────────────────────────────
// نماذج البطاقة
// ─────────────────────────────────────────────
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

class _GeneratedCard {
  final String user;
  final String pass;
  final String profile;
  final String network;
  final String duration;
  final String notes;

  const _GeneratedCard({
    required this.user,
    required this.pass,
    required this.profile,
    required this.network,
    required this.duration,
    required this.notes,
  });
}

// ─────────────────────────────────────────────
// الشاشة الرئيسية
// ─────────────────────────────────────────────
class CardsScreen extends StatefulWidget {
  final RouterService? routerService;
  const CardsScreen({super.key, required this.routerService});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen>
    with SingleTickerProviderStateMixin {
  final Random _random = Random.secure();
  final ImagePicker _picker = ImagePicker();

  // ── Controllers ──
  final _profileCtrl = TextEditingController(text: 'default');
  final _networkCtrl = TextEditingController(text: 'ST_Manager');
  final _durationCtrl = TextEditingController(text: '1 يوم');
  final _notesCtrl = TextEditingController();
  final _cardCountCtrl = TextEditingController(text: '10');
  final _userLenCtrl = TextEditingController(text: '6');
  final _passLenCtrl = TextEditingController(text: '6');

  // ── إعدادات التوليد ──
  String _charType = 'mixed';
  bool _showNotes = false;
  bool _isGenerating = false;

  // ── الصورة المخصصة ──
  File? _templateImage;
  bool _useCustomImage = false;

  // ── إعدادات الخط ──
  Color _fontColor = Colors.white;
  double _fontSize = 14;
  double _networkFontSize = 12;
  double _durationFontSize = 10;
  double _notesFontSize = 10;

  // ── البروفايلات ──
  final List<String> _profiles = [];

  // ── النماذج ──
  int _selectedTemplateIndex = 0;
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

  // ── مواضع الحقول (قابلة للسحب) ──
  double _userX = 0.05, _userY = 0.35;
  double _passX = 0.05, _passY = 0.56;
  double _netX = 0.05, _netY = 0.08;
  double _durX = 0.05, _durY = 0.77;
  double _notesX = 0.55, _notesY = 0.77;
  double _profileX = 0.65, _profileY = 0.08;

  // ── Preview ──
  String _previewUser = '';
  String _previewPass = '';

  @override
  void initState() {
    super.initState();
    _refreshPreview();
    _loadProfiles();
  }

  @override
  void dispose() {
    _profileCtrl.dispose();
    _networkCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    _cardCountCtrl.dispose();
    _userLenCtrl.dispose();
    _passLenCtrl.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    setState(() {
      _previewUser =
          _generateRandom(length: int.tryParse(_userLenCtrl.text) ?? 6);
      _previewPass =
          _generateRandom(length: int.tryParse(_passLenCtrl.text) ?? 6);
    });
  }

  double _clamp01(num v) => v.clamp(0.0, 1.0).toDouble();

  // ─────────────────────────────────────────────
  // جلب البروفايلات
  // ─────────────────────────────────────────────
  Future<void> _loadProfiles() async {
    if (widget.routerService == null) return;
    try {
      final res = await widget.routerService!.getHotspotProfiles();
      final names = res
          .map((e) => e['name']?.toString().trim() ?? '')
          .where((n) => n.isNotEmpty)
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

  // ─────────────────────────────────────────────
  // اختيار صورة
  // ─────────────────────────────────────────────
  Future<void> _pickImage() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    setState(() {
      _templateImage = File(img.path);
      _useCustomImage = true;
    });
  }

  void _selectTemplate(int index) => setState(() {
        _selectedTemplateIndex = index;
        _useCustomImage = false;
        _templateImage = null;
      });

  // ─────────────────────────────────────────────
  // توليد نص عشوائي
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  // ✅ التأكد من وجود البروفايل في الراوتر
  // ─────────────────────────────────────────────
  Future<void> _ensureHotspotProfileExists(String profile) async {
    if (widget.routerService == null || profile.isEmpty) return;
    try {
      await widget.routerService!.sendCommand(
        '/ip/hotspot/user/profile/add',
        params: {'name': profile, 'rate-limit': ''},
      );
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // ✅ بناء قائمة البطاقات مع التحقق من التكرار
  // ─────────────────────────────────────────────
  Future<List<_GeneratedCard>> _buildGeneratedCards() async {
    final count = (int.tryParse(_cardCountCtrl.text) ?? 10).clamp(1, 500);
    final userLen = (int.tryParse(_userLenCtrl.text) ?? 6).clamp(4, 20);
    final passLen = (int.tryParse(_passLenCtrl.text) ?? 6).clamp(4, 20);
    final profile = _profileCtrl.text.trim();

    // ✅ جلب اليوزرات الموجودة لتجنب التكرار
    final existingUsers = <String>{};
    if (widget.routerService != null) {
      try {
        final users = await widget.routerService!.getHotspotUsers();
        for (final u in users) {
          final name = u['name']?.toString().trim() ?? '';
          if (name.isNotEmpty) existingUsers.add(name.toLowerCase());
        }
      } catch (_) {}
    }

    final cards = <_GeneratedCard>[];
    int attempts = 0;

    while (cards.length < count && attempts < count * 10) {
      attempts++;
      final user = _generateRandom(length: userLen);
      if (existingUsers.contains(user.toLowerCase())) continue;
      existingUsers.add(user.toLowerCase()); // منع التكرار داخل الدفعة

      cards.add(_GeneratedCard(
        user: user,
        pass: _generateRandom(length: passLen),
        profile: profile,
        network: _networkCtrl.text.trim(),
        duration: _durationCtrl.text.trim(),
        notes: _showNotes ? _notesCtrl.text.trim() : '',
      ));
    }

    return cards;
  }

  // ─────────────────────────────────────────────
  // ✅ رفع اليوزرات للراوتر
  // ─────────────────────────────────────────────
  Future<void> _pushUsersToHotspot(List<_GeneratedCard> cards) async {
    if (widget.routerService == null) return;
    await _ensureHotspotProfileExists(cards.first.profile);

    for (final card in cards) {
      try {
        await widget.routerService!.sendCommand(
          '/ip/hotspot/user/add',
          params: {
            'name': card.user,
            'password': card.pass,
            'profile': card.profile,
            'comment': card.notes.isNotEmpty
                ? 'network:${card.network} | duration:${card.duration} | ${card.notes}'
                : 'network:${card.network} | duration:${card.duration}',
          },
        );
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────
  // ✅ بناء PDF احترافي مع مواضع السحب الصحيحة
  // ─────────────────────────────────────────────
  Future<void> _generatePdfAndShare() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final cards = await _buildGeneratedCards();
      if (cards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ لم يتم توليد أي بطاقات'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // رفع اليوزرات للراوتر
      if (widget.routerService != null) {
        await _pushUsersToHotspot(cards);
      }

      final pdf = pw.Document();
      final template = _currentTemplate;
      const pageFormat = PdfPageFormat.a4;

      // ✅ حجم بطاقة قياسي (85×54 mm - حجم بطاقة ائتمان)
      final cardW = 85.5 * PdfPageFormat.mm;
      final cardH = 54.0 * PdfPageFormat.mm;
      const marginH = 8.0;
      const marginV = 10.0;
      const spacingH = 4.0;
      const spacingV = 4.0;

      final usableW = pageFormat.width - (marginH * 2);
      final usableH = pageFormat.height - (marginV * 2);
      final cols = max(1, ((usableW + spacingH) / (cardW + spacingH)).floor());
      final rows = max(1, ((usableH + spacingV) / (cardH + spacingV)).floor());
      final cardsPerPage = cols * rows;

      final imageBytes =
          _templateImage != null ? _templateImage!.readAsBytesSync() : null;

      // ✅ تحميل خط يدعم العربية
      pw.Font? arabicFont;
      try {
        final fontData =
            await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
        arabicFont = pw.Font.ttf(fontData);
      } catch (_) {
        // الخط غير موجود - نكمل بدونه
      }

      for (int pageStart = 0;
          pageStart < cards.length;
          pageStart += cardsPerPage) {
        final children = <pw.Widget>[];

        for (int slot = 0; slot < cardsPerPage; slot++) {
          final idx = pageStart + slot;
          if (idx >= cards.length) break;

          final card = cards[idx];
          final col = slot % cols;
          final row = slot ~/ cols;

          final left = marginH + (col * (cardW + spacingH));
          final top = marginV + (row * (cardH + spacingV));

          children.add(
            pw.Positioned(
              left: left,
              top: top,
              child: _buildPdfCard(
                template: template,
                imageBytes: imageBytes,
                card: card,
                cardW: cardW,
                cardH: cardH,
                arabicFont: arabicFont,
              ),
            ),
          );
        }

        // ✅ إضافة خط قص بين البطاقات
        for (int col = 1; col < cols; col++) {
          final x = marginH + (col * (cardW + spacingH)) - (spacingH / 2);
          children.add(
            pw.Positioned(
              left: x,
              top: 0,
              child: pw.SizedBox(
                width: 0.3,
                height: pageFormat.height,
                child: pw.Container(color: PdfColor.fromInt(0xFFCCCCCC)),
              ),
            ),
          );
        }
        for (int row = 1; row < rows; row++) {
          final y = marginV + (row * (cardH + spacingV)) - (spacingV / 2);
          children.add(
            pw.Positioned(
              left: 0,
              top: y,
              child: pw.SizedBox(
                width: pageFormat.width,
                height: 0.3,
                child: pw.Container(color: PdfColor.fromInt(0xFFCCCCCC)),
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

      // ✅ صفحة قائمة اليوزرات للمراجعة
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'قائمة بيانات البطاقات',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(template.accent.value),
                ),
                textDirection: pw.TextDirection.rtl,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFCCCCCC),
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                // رأس الجدول
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(template.accent.value),
                  ),
                  children: ['#', 'USER', 'PASSWORD', 'PROFILE']
                      .map(
                        (h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                // صفوف البيانات
                ...cards.asMap().entries.map(
                      (e) => pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: e.key.isOdd
                              ? PdfColor.fromInt(0xFFF5F5F5)
                              : PdfColors.white,
                        ),
                        children: [
                          '${e.key + 1}',
                          e.value.user,
                          e.value.pass,
                          e.value.profile,
                        ]
                            .map(
                              (v) => pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(
                                  v,
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'المجموع: ${cards.length} بطاقة | الشبكة: ${cards.first.network} | البروفايل: ${cards.first.profile}',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 9,
                color: PdfColor.fromInt(0xFF666666),
              ),
              textDirection: pw.TextDirection.rtl,
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final timestamp =
          DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final file = File('${dir.path}/hotspot_cards_$timestamp.pdf');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'بطاقات هوتسبوت - ${cards.first.network}',
        text:
            '${cards.length} بطاقة | بروفايل: ${cards.first.profile} | المدة: ${cards.first.duration}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم توليد ${cards.length} بطاقة ورفعها للراوتر'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل التصدير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ─────────────────────────────────────────────
  // ✅ بناء بطاقة PDF مع المواضع الصحيحة من السحب
  // ─────────────────────────────────────────────
  pw.Widget _buildPdfCard({
    required _CardTemplate template,
    required Uint8List? imageBytes,
    required _GeneratedCard card,
    required double cardW,
    required double cardH,
    pw.Font? arabicFont,
  }) {
    final bg = PdfColor.fromInt(template.background.value);
    final bgSoft = PdfColor.fromInt(template.backgroundSoft.value);
    final accent = PdfColor.fromInt(template.accent.value);
    final accentSoft = PdfColor.fromInt(template.accentSoft.value);
    final border = PdfColor.fromInt(template.border.value);
    final textColor = PdfColor.fromInt(template.text.value);
    final mutedColor = PdfColor.fromInt(template.mutedText.value);

    pw.TextStyle labelStyle(double size) => pw.TextStyle(
          font: arabicFont,
          color: accent,
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
        );

    pw.TextStyle valueStyle(double size) => pw.TextStyle(
          color: textColor,
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
        );

    pw.Widget fieldBox(
        String label, String value, double labelSz, double valueSz,
        {bool compact = false}) {
      return pw.Container(
        padding: pw.EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6,
          vertical: compact ? 3 : 5,
        ),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0x1AFFFFFF),
          borderRadius: pw.BorderRadius.circular(6),
          border:
              pw.Border.all(color: PdfColor.fromInt(0x33FFFFFF), width: 0.5),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: labelStyle(labelSz)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: valueStyle(valueSz)),
          ],
        ),
      );
    }

    return pw.Container(
      width: cardW,
      height: cardH,
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: border, width: 0.7),
      ),
      child: pw.Stack(
        children: [
          // ── خلفية ──
          if (imageBytes != null)
            pw.Positioned.fill(
              child: pw.ClipRRect(
                horizontalRadius: 8,
                verticalRadius: 8,
                child:
                    pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.cover),
              ),
            )
          else ...[
            pw.Positioned.fill(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  color: bg,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
              ),
            ),
            // شريط أعلى
            pw.Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: pw.Container(height: 6, color: accent),
            ),
            // شريط يمين
            pw.Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: pw.Container(width: 5, color: accentSoft),
            ),
            // دائرة زخرفية
            pw.Positioned(
              right: -15,
              top: -15,
              child: pw.Container(
                width: 60,
                height: 60,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0x22000000),
                  shape: pw.BoxShape.circle,
                ),
              ),
            ),
          ],

          // ── overlay على الصورة ──
          if (imageBytes != null)
            pw.Positioned.fill(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(8),
                  color: PdfColor.fromInt(0x55000000),
                ),
              ),
            ),

          // ── اسم الشبكة ──
          pw.Positioned(
            left: _netX * cardW,
            top: _netY * cardH,
            child: pw.SizedBox(
              width: cardW * 0.5,
              child: fieldBox('اسم الشبكة', card.network, 6.5,
                  _networkFontSize.clamp(8, 14)),
            ),
          ),

          // ── البروفايل ──
          if (card.profile.isNotEmpty)
            pw.Positioned(
              left: _profileX * cardW,
              top: _profileY * cardH,
              child: pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: accentSoft,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(card.profile, style: valueStyle(8)),
              ),
            ),

          // ── اليوزر ──
          pw.Positioned(
            left: _userX * cardW,
            top: _userY * cardH,
            child: pw.SizedBox(
              width: cardW * 0.45,
              child: fieldBox('USER', card.user, 6.5, _fontSize.clamp(10, 16)),
            ),
          ),

          // ── الباسوورد ──
          pw.Positioned(
            left: _passX * cardW,
            top: _passY * cardH,
            child: pw.SizedBox(
              width: cardW * 0.45,
              child:
                  fieldBox('PASSWORD', card.pass, 6.5, _fontSize.clamp(10, 16)),
            ),
          ),

          // ── المدة ──
          pw.Positioned(
            left: _durX * cardW,
            top: _durY * cardH,
            child: pw.SizedBox(
              width: cardW * 0.28,
              child: fieldBox(
                  'المدة', card.duration, 6.5, _durationFontSize.clamp(8, 13),
                  compact: true),
            ),
          ),

          // ── الملاحظات ──
          if (card.notes.isNotEmpty)
            pw.Positioned(
              left: _notesX * cardW,
              top: _notesY * cardH,
              child: pw.SizedBox(
                width: cardW * 0.32,
                child: fieldBox(
                    'ملاحظات', card.notes, 6, _notesFontSize.clamp(7, 11),
                    compact: true),
              ),
            ),

          // ── footer ──
          pw.Positioned(
            left: 8,
            bottom: 5,
            child: pw.Text(
              'Hotspot Card • ${template.subtitle}',
              style: pw.TextStyle(color: mutedColor, fontSize: 6),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ✅ بناء حقل قابل للسحب في الـ Preview
  // ─────────────────────────────────────────────
  Widget _draggableField({
    required double x,
    required double y,
    required double parentW,
    required double parentH,
    required void Function(Offset delta) onMove,
    required Widget child,
  }) {
    return Positioned(
      left: (x * parentW).clamp(0, parentW - 60),
      top: (y * parentH).clamp(0, parentH - 30),
      child: GestureDetector(
        onPanUpdate: (d) => onMove(d.delta),
        child: child,
      ),
    );
  }

  Widget _fieldBlock({
    required String label,
    required String value,
    required Color accent,
    required Color border,
    required double labelSize,
    required double valueSize,
    bool compact = false,
  }) {
    final textColor = _fontColor;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border.withOpacity(0.7), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: accent,
                  fontSize: labelSize,
                  fontWeight: FontWeight.bold,
                  height: 1)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: textColor,
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                  height: 1)),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(double w, double h) {
    final t = _currentTemplate;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.background, t.backgroundSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withOpacity(0.9), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: t.accent.withOpacity(0.15),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // زخارف
          Positioned(
            right: -20,
            top: -18,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: t.accentSoft.withOpacity(0.28),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: 8,
              child: Container(color: t.accent)),
          Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(color: t.accentSoft.withOpacity(0.8))),

          // صورة مخصصة
          if (_useCustomImage && _templateImage != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_templateImage!, fit: BoxFit.cover),
              ),
            ),
          if (_useCustomImage && _templateImage != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withOpacity(0.28),
                ),
              ),
            ),

          // ── الحقول القابلة للسحب ──
          _draggableField(
            x: _netX,
            y: _netY,
            parentW: w,
            parentH: h,
            onMove: (d) => setState(() {
              _netX = _clamp01(_netX + d.dx / w);
              _netY = _clamp01(_netY + d.dy / h);
            }),
            child: SizedBox(
              width: w * 0.52,
              child: _fieldBlock(
                label: 'اسم الشبكة',
                value: _networkCtrl.text.trim().isEmpty
                    ? 'ST_Manager'
                    : _networkCtrl.text.trim(),
                accent: t.accent,
                border: t.border,
                labelSize: 9,
                valueSize: _networkFontSize,
              ),
            ),
          ),

          if (_profileCtrl.text.trim().isNotEmpty)
            _draggableField(
              x: _profileX,
              y: _profileY,
              parentW: w,
              parentH: h,
              onMove: (d) => setState(() {
                _profileX = _clamp01(_profileX + d.dx / w);
                _profileY = _clamp01(_profileY + d.dy / h);
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: t.accentSoft.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: t.accent.withOpacity(0.7), width: 1),
                ),
                child: Text(
                  _profileCtrl.text.trim(),
                  style: TextStyle(
                      color: _fontColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),

          _draggableField(
            x: _userX,
            y: _userY,
            parentW: w,
            parentH: h,
            onMove: (d) => setState(() {
              _userX = _clamp01(_userX + d.dx / w);
              _userY = _clamp01(_userY + d.dy / h);
            }),
            child: SizedBox(
              width: w * 0.44,
              child: _fieldBlock(
                label: 'USER',
                value: _previewUser,
                accent: t.accent,
                border: t.border,
                labelSize: 9,
                valueSize: _fontSize,
              ),
            ),
          ),

          _draggableField(
            x: _passX,
            y: _passY,
            parentW: w,
            parentH: h,
            onMove: (d) => setState(() {
              _passX = _clamp01(_passX + d.dx / w);
              _passY = _clamp01(_passY + d.dy / h);
            }),
            child: SizedBox(
              width: w * 0.44,
              child: _fieldBlock(
                label: 'PASSWORD',
                value: _previewPass,
                accent: t.accent,
                border: t.border,
                labelSize: 9,
                valueSize: _fontSize,
              ),
            ),
          ),

          _draggableField(
            x: _durX,
            y: _durY,
            parentW: w,
            parentH: h,
            onMove: (d) => setState(() {
              _durX = _clamp01(_durX + d.dx / w);
              _durY = _clamp01(_durY + d.dy / h);
            }),
            child: SizedBox(
              width: w * 0.26,
              child: _fieldBlock(
                label: 'المدة',
                value: _durationCtrl.text.trim().isEmpty
                    ? '1 يوم'
                    : _durationCtrl.text.trim(),
                accent: t.accent,
                border: t.border,
                labelSize: 9,
                valueSize: _durationFontSize,
                compact: true,
              ),
            ),
          ),

          if (_showNotes && _notesCtrl.text.trim().isNotEmpty)
            _draggableField(
              x: _notesX,
              y: _notesY,
              parentW: w,
              parentH: h,
              onMove: (d) => setState(() {
                _notesX = _clamp01(_notesX + d.dx / w);
                _notesY = _clamp01(_notesY + d.dy / h);
              }),
              child: SizedBox(
                width: w * 0.34,
                child: _fieldBlock(
                  label: 'ملاحظات',
                  value: _notesCtrl.text.trim(),
                  accent: t.accent,
                  border: t.border,
                  labelSize: 8,
                  valueSize: _notesFontSize,
                  compact: true,
                ),
              ),
            ),

          // footer
          Positioned(
            left: 10,
            bottom: 8,
            child: Text(
              t.subtitle,
              style: TextStyle(
                  color: t.mutedText, fontSize: 8, fontWeight: FontWeight.w600),
            ),
          ),

          // زر تحديث الـ preview
          Positioned(
            right: 10,
            bottom: 6,
            child: GestureDetector(
              onTap: _refreshPreview,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.refresh, color: Colors.white70, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // بناء الواجهة
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final previewW = MediaQuery.of(context).size.width - 32;
    const previewH = 220.0;
    final t = _currentTemplate;

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
            tooltip: 'رفع صورة خلفية',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── اختيار القالب ──
            const Text('اختر قالب البطاقة',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _templates.length + 1,
                itemBuilder: (_, i) {
                  if (i < _templates.length) {
                    final tmpl = _templates[i];
                    final sel = _selectedTemplateIndex == i;
                    return GestureDetector(
                      onTap: () => _selectTemplate(i),
                      child: Container(
                        width: 88,
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [tmpl.background, tmpl.backgroundSoft],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? AppTheme.gold
                                : tmpl.border.withOpacity(0.7),
                            width: sel ? 2.2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(tmpl.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: tmpl.text,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Text(tmpl.subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: tmpl.mutedText, fontSize: 8)),
                          ],
                        ),
                      ),
                    );
                  }
                  final sel = _useCustomImage;
                  return GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 88,
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkGrey,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? AppTheme.gold : Colors.grey,
                          width: sel ? 2.2 : 1,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate,
                              color: Colors.white54, size: 22),
                          SizedBox(height: 4),
                          Text('رفع صورة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 9)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // ── بريفيو ──
            Container(
              height: previewH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (_, c) => _buildPreviewCard(c.maxWidth, c.maxHeight),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _refreshPreview,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('تحديث المعاينة',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(height: 4),

            // ── إعدادات البطاقة ──
            _sectionTitle('إعدادات البطاقة'),
            const SizedBox(height: 8),

            _buildProfileInput(),
            const SizedBox(height: 10),

            TextField(
              controller: _networkCtrl,
              decoration: const InputDecoration(labelText: 'اسم الشبكة'),
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _durationCtrl,
              decoration: const InputDecoration(labelText: 'مدة الصلاحية'),
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إظهار ملاحظات على البطاقة',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              value: _showNotes,
              onChanged: (v) => setState(() => _showNotes = v),
              activeColor: AppTheme.gold,
            ),

            if (_showNotes) ...[
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'الملاحظات'),
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
            ],

            // ── إعدادات التوليد ──
            _sectionTitle('إعدادات التوليد'),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cardCountCtrl,
                    decoration: const InputDecoration(
                        labelText: 'عدد البطاقات', hintText: '10'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _userLenCtrl,
                    decoration: const InputDecoration(
                        labelText: 'طول اليوزر', hintText: '6'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    onChanged: (_) => _refreshPreview(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _passLenCtrl,
                    decoration: const InputDecoration(
                        labelText: 'طول الباسوورد', hintText: '6'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    onChanged: (_) => _refreshPreview(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _charType,
              dropdownColor: AppTheme.semiBlack,
              decoration: const InputDecoration(labelText: 'نوع الأحرف'),
              items: const [
                DropdownMenuItem(value: 'numbers', child: Text('أرقام فقط')),
                DropdownMenuItem(
                    value: 'letters', child: Text('أحرف إنجليزية فقط')),
                DropdownMenuItem(value: 'mixed', child: Text('أحرف وأرقام')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _charType = v);
                  _refreshPreview();
                }
              },
            ),
            const SizedBox(height: 12),

            // ── إعدادات الخط ──
            _sectionTitle('إعدادات الخط والألوان'),
            const SizedBox(height: 8),

            _sliderRow('حجم خط USER/PASS', _fontSize, 8, 28,
                (v) => setState(() => _fontSize = v)),
            _sliderRow('حجم خط اسم الشبكة', _networkFontSize, 8, 22,
                (v) => setState(() => _networkFontSize = v)),
            _sliderRow('حجم خط المدة', _durationFontSize, 7, 18,
                (v) => setState(() => _durationFontSize = v)),
            if (_showNotes)
              _sliderRow('حجم خط الملاحظات', _notesFontSize, 7, 16,
                  (v) => setState(() => _notesFontSize = v)),
            const SizedBox(height: 8),

            // لون الخط
            Row(
              children: [
                const Text('لون الخط: ',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(width: 8),
                ...([
                  Colors.white,
                  Colors.black,
                  Colors.amber,
                  Colors.cyan,
                  Colors.red,
                  Colors.green,
                ].map((c) => GestureDetector(
                      onTap: () => setState(() => _fontColor = c),
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _fontColor == c
                                ? AppTheme.gold
                                : Colors.white24,
                            width: _fontColor == c ? 2.5 : 1,
                          ),
                        ),
                        child: _fontColor == c
                            ? const Icon(Icons.check,
                                color: Colors.black54, size: 16)
                            : null,
                      ),
                    ))),
              ],
            ),
            const SizedBox(height: 24),

            // ── زر التوليد ──
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf),
              label: Text(
                _isGenerating
                    ? 'جاري التوليد...'
                    : 'توليد البطاقات وتصديرها PDF',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _isGenerating ? null : _generatePdfAndShare,
            ),
            const SizedBox(height: 12),

            // معلومات سريعة
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.accent.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline, color: t.accent, size: 14),
                    const SizedBox(width: 6),
                    Text('معلومات التصدير',
                        style: TextStyle(
                            color: t.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  _infoLine('عدد البطاقات',
                      '${int.tryParse(_cardCountCtrl.text) ?? 10}'),
                  _infoLine(
                      'البروفايل',
                      _profileCtrl.text.trim().isEmpty
                          ? 'default'
                          : _profileCtrl.text.trim()),
                  _infoLine(
                      'نوع الأحرف',
                      switch (_charType) {
                        'numbers' => 'أرقام فقط',
                        'letters' => 'أحرف فقط',
                        _ => 'أحرف وأرقام'
                      }),
                  _infoLine('يُضاف للراوتر',
                      widget.routerService != null ? 'نعم ✅' : 'لا ❌'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
              width: 3,
              height: 14,
              margin: const EdgeInsets.only(left: 6),
              color: AppTheme.gold),
          Text(title,
              style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).round(),
            activeColor: AppTheme.gold,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(value.round().toString(),
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProfileInput() {
    if (_profiles.isNotEmpty) {
      final current = _profiles.contains(_profileCtrl.text.trim())
          ? _profileCtrl.text.trim()
          : _profiles.first;
      if (!_profiles.contains(_profileCtrl.text.trim())) {
        _profileCtrl.text = current;
      }
      return DropdownButtonFormField<String>(
        value: current,
        isExpanded: true,
        dropdownColor: AppTheme.semiBlack,
        decoration: const InputDecoration(labelText: 'البروفايل'),
        items: _profiles
            .map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _profileCtrl.text = v);
        },
      );
    }
    return TextField(
      controller: _profileCtrl,
      decoration: const InputDecoration(
          labelText: 'البروفايل', hintText: 'مثلاً default'),
      style: const TextStyle(color: Colors.white),
      onChanged: (_) => setState(() {}),
    );
  }
}
