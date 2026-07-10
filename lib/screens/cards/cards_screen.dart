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
import 'package:qr_flutter/qr_flutter.dart';
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
// الشاشة الرئيسية (تحتوي على التبويبات)
// ─────────────────────────────────────────────
class CardsScreen extends StatefulWidget {
  final RouterService? routerService;
  const CardsScreen({super.key, required this.routerService});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Random _random = Random.secure();
  final ImagePicker _picker = ImagePicker();

  // ── البروفايلات ──
  final List<String> _profiles = [];
  bool _isLoadingProfiles = false;

  // ==========================================
  // متغيرات التبويب الأول (بطاقة مفردة)
  // ==========================================
  final _sUserCtrl = TextEditingController();
  final _sPassCtrl = TextEditingController();
  final _sValidityCtrl = TextEditingController(text: '30');
  final _sVolumeCtrl = TextEditingController(text: 'مفتوح');
  final _sNotesCtrl = TextEditingController();
  final _sPriceCtrl = TextEditingController();
  String _sProfile = '';
  bool _sIsGenerating = false;
  String _sValidityUnit = 'يوم';

  // ==========================================
  // متغيرات التبويب الثاني (بطاقات متعددة)
  // ==========================================
  final _cardCountCtrl = TextEditingController(text: '10');
  final _userLenCtrl = TextEditingController(text: '6');
  final _passLenCtrl = TextEditingController(text: '6');
  final _pdfColsCtrl = TextEditingController(text: '3');
  final _pdfRowsCtrl = TextEditingController(text: '7');

  final _mProfileCtrl = TextEditingController();
  final _mNetworkCtrl = TextEditingController(text: 'سلطان نت');
  final _mDurationCtrl = TextEditingController(text: '1 يوم');
  final _mNotesCtrl = TextEditingController();

  String _charType = 'mixed';
  bool _isGeneratingPdf = false;
  File? _templateImage;
  bool _useCustomImage = false;
  int _selectedTemplateIndex = 0;

  // إعدادات وتفعيل العناصر
  bool _showNetwork = true;
  bool _showDuration = true;
  bool _showNotes = true;
  bool _showQR = true;

  // مواضع الحقول (X, Y)
  double _userX = 0.35, _userY = 0.20;
  double _passX = 0.35, _passY = 0.50;
  double _netX = 0.05, _netY = 0.05;
  double _durX = 0.05, _durY = 0.70;
  double _notesX = 0.40, _notesY = 0.80;
  double _qrX = 0.75, _qrY = 0.20;

  // أحجام الخطوط / العناصر
  double _userSize = 18;
  double _passSize = 18;
  double _netSize = 14;
  double _durSize = 12;
  double _notesSize = 10;
  double _qrSize = 60;

  // ألوان الخطوط الافتراضية
  Color _userColor = Colors.black;
  Color _passColor = Colors.black;
  Color _netColor = Colors.blue.shade900;
  Color _durColor = Colors.white;
  Color _notesColor = Colors.white;

  // Preview
  String _previewUser = '123456';
  String _previewPass = '12345';

  final List<_CardTemplate> _templates = const [
    _CardTemplate(
      name: 'أزرق كلاسيكي',
      subtitle: 'كما في النموذج',
      background: Color(0xFFFFFFFF),
      backgroundSoft: Color(0xFFE3F2FD),
      accent: Color(0xFF0D47A1),
      accentSoft: Color(0x660D47A1),
      border: Color(0xFF1976D2),
      text: Colors.black,
      mutedText: Color(0xFF555555),
    ),
    _CardTemplate(
      name: 'أسود وذهبي',
      subtitle: 'فخم',
      background: Color(0xFF111111),
      backgroundSoft: Color(0xFF1B1B1B),
      accent: Color(0xFFD4AF37),
      accentSoft: Color(0x66D4AF37),
      border: Color(0xFFD4AF37),
      text: Colors.white,
      mutedText: Color(0xFFBFBFBF),
    ),
  ];

  final List<Color> _availableColors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
    Colors.cyan,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sUserCtrl.dispose();
    _sPassCtrl.dispose();
    _sValidityCtrl.dispose();
    _sVolumeCtrl.dispose();
    _sNotesCtrl.dispose();
    _sPriceCtrl.dispose();
    _cardCountCtrl.dispose();
    _userLenCtrl.dispose();
    _passLenCtrl.dispose();
    _pdfColsCtrl.dispose();
    _pdfRowsCtrl.dispose();
    _mProfileCtrl.dispose();
    _mNetworkCtrl.dispose();
    _mDurationCtrl.dispose();
    _mNotesCtrl.dispose();
    super.dispose();
  }

  double _clamp01(num v) => v.clamp(0.0, 1.0).toDouble();
  _CardTemplate get _currentTemplate => _templates[_selectedTemplateIndex];

  // ─────────────────────────────────────────────
  // دوال عامة (الراوتر وتوليد العشوائي)
  // ─────────────────────────────────────────────
  Future<void> _loadProfiles() async {
    if (widget.routerService == null) return;
    setState(() => _isLoadingProfiles = true);
    try {
      final res = await widget.routerService!.getHotspotProfiles();
      final names = res
          .map((e) => e['name']?.toString().trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _profiles
            ..clear()
            ..addAll(names);
          if (_profiles.isNotEmpty) {
            _sProfile = _profiles.first;
            _mProfileCtrl.text = _profiles.first;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingProfiles = false);
    }
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

  void _refreshPreview() {
    setState(() {
      _previewUser =
          _generateRandom(length: int.tryParse(_userLenCtrl.text) ?? 6);
      _previewPass =
          _generateRandom(length: int.tryParse(_passLenCtrl.text) ?? 5);
    });
  }

  // ─────────────────────────────────────────────
  // تبويب 1: البطاقة المفردة
  // ─────────────────────────────────────────────
  Future<void> _generateSingleCard() async {
    if (widget.routerService == null) return;
    if (_sUserCtrl.text.trim().isEmpty || _sPassCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم المستخدم وكلمة المرور')),
      );
      return;
    }

    setState(() => _sIsGenerating = true);
    try {
      final comment =
          'Duration:${_sValidityCtrl.text}$_sValidityUnit | Vol:${_sVolumeCtrl.text} | Price:${_sPriceCtrl.text} | Note:${_sNotesCtrl.text}';
      await widget.routerService!.sendCommand(
        '/ip/hotspot/user/add',
        params: {
          'name': _sUserCtrl.text.trim(),
          'password': _sPassCtrl.text.trim(),
          'profile': _sProfile,
          'comment': comment,
        },
      );

      if (mounted) {
        _showSingleCardSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _sIsGenerating = false);
    }
  }

  void _showSingleCardSuccessDialog() {
    final user = _sUserCtrl.text.trim();
    final pass = _sPassCtrl.text.trim();
    final qrData = 'http://10.0.0.1/login?username=$user&password=$pass'; // عدل الـ IP حسب شبكتك

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.semiBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, color: Colors.blue),
            SizedBox(width: 8),
            Text('إنشاء البطاقة', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تم إنشاء الكرت بنجاح',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            Text('المستخدم: $user',
                style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('كلمة المرور: $pass',
                style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('الحجم: ${_sVolumeCtrl.text}', style: const TextStyle(color: Colors.white70)),
            Text('المدة: ${_sValidityCtrl.text} $_sValidityUnit', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 150.0,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {
                    Share.share('معلومات الدخول\nالمستخدم: $user\nكلمة المرور: $pass\nالمدة: ${_sValidityCtrl.text} $_sValidityUnit');
                  },
                  icon: const Icon(Icons.share, color: Colors.green, size: 30),
                ),
                IconButton(
                  onPressed: () {
                    // كود الحذف إذا لزم الأمر
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete, color: Colors.pink, size: 30),
                ),
              ],
            )
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
                _sUserCtrl.clear();
                _sPassCtrl.clear();
                Navigator.pop(ctx);
              },
              child: const Text('تم', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSingleCardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInputRow('اسم المستخدم', _sUserCtrl),
          const SizedBox(height: 12),
          _buildInputRow('كلمة المرور', _sPassCtrl),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                  flex: 2,
                  child: Text('الصلاحية',
                      style: TextStyle(color: Colors.blue, fontSize: 16))),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _sValidityUnit,
                  dropdownColor: AppTheme.darkGrey,
                  style: const TextStyle(color: Colors.blue),
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                  items: ['يوم', 'ساعة']
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _sValidityUnit = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _sValidityCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInputRow('الحجم', _sVolumeCtrl, hint: 'مفتوح / ميغا / جيغا'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                  flex: 2,
                  child: Text('ملف السرعة',
                      style: TextStyle(color: Colors.blue, fontSize: 16))),
              Expanded(
                flex: 3,
                child: _isLoadingProfiles
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<String>(
                        value: _sProfile.isEmpty ? null : _sProfile,
                        dropdownColor: AppTheme.darkGrey,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 8)),
                        items: _profiles
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _sProfile = v ?? ''),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInputRow('السعر', _sPriceCtrl, hint: 'اختياري'),
          const SizedBox(height: 12),
          _buildInputRow('ملاحظة أو رقم', _sNotesCtrl, hint: 'اختياري'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: _sIsGenerating ? null : _generateSingleCard,
              child: _sIsGenerating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('إضافة',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInputRow(String label, TextEditingController controller,
      {String? hint}) {
    return Row(
      children: [
        Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(color: Colors.blue, fontSize: 16))),
        Expanded(
          flex: 3,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // تبويب 2: البطاقات المتعددة (التصميم المتقدم)
  // ─────────────────────────────────────────────
  Future<void> _pickImage() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    setState(() {
      _templateImage = File(img.path);
      _useCustomImage = true;
    });
  }

  Widget _draggableItem({
    required double x,
    required double y,
    required double parentW,
    required double parentH,
    required void Function(Offset delta) onMove,
    required Widget child,
  }) {
    return Positioned(
      left: (x * parentW).clamp(0, parentW - 20),
      top: (y * parentH).clamp(0, parentH - 20),
      child: GestureDetector(
        onPanUpdate: (d) => onMove(d.delta),
        child: child,
      ),
    );
  }

  Widget _buildMultiPreviewCard(double w, double h) {
    final t = _currentTemplate;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: t.background,
        border: Border.all(color: t.border, width: 2),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // الخلفية
          if (_useCustomImage && _templateImage != null)
            Positioned.fill(
                child: Image.file(_templateImage!, fit: BoxFit.cover)),
          if (!_useCustomImage)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: w * 0.3,
              child: Container(color: t.accent),
            ),

          // العناصر القابلة للسحب
          if (_showNetwork)
            _draggableItem(
              x: _netX, y: _netY, parentW: w, parentH: h,
              onMove: (d) => setState(() {
                _netX = _clamp01(_netX + d.dx / w);
                _netY = _clamp01(_netY + d.dy / h);
              }),
              child: Text(_mNetworkCtrl.text,
                  style: TextStyle(
                      color: _netColor,
                      fontSize: _netSize,
                      fontWeight: FontWeight.bold)),
            ),

          _draggableItem(
            x: _userX, y: _userY, parentW: w, parentH: h,
            onMove: (d) => setState(() {
              _userX = _clamp01(_userX + d.dx / w);
              _userY = _clamp01(_userY + d.dy / h);
            }),
            child: Row(
              children: [
                Text('اسم المستخدم: ',
                    style: TextStyle(color: Colors.black54, fontSize: _userSize * 0.7)),
                Text(_previewUser,
                    style: TextStyle(
                        color: _userColor,
                        fontSize: _userSize,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          _draggableItem(
            x: _passX, y: _passY, parentW: w, parentH: h,
            onMove: (d) => setState(() {
              _passX = _clamp01(_passX + d.dx / w);
              _passY = _clamp01(_passY + d.dy / h);
            }),
            child: Row(
              children: [
                Text('كلمة المرور: ',
                    style: TextStyle(color: Colors.black54, fontSize: _passSize * 0.7)),
                Text(_previewPass,
                    style: TextStyle(
                        color: _passColor,
                        fontSize: _passSize,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          if (_showDuration)
            _draggableItem(
              x: _durX, y: _durY, parentW: w, parentH: h,
              onMove: (d) => setState(() {
                _durX = _clamp01(_durX + d.dx / w);
                _durY = _clamp01(_durY + d.dy / h);
              }),
              child: Text(_mDurationCtrl.text,
                  style: TextStyle(
                      color: _durColor,
                      fontSize: _durSize,
                      fontWeight: FontWeight.bold)),
            ),

          if (_showNotes)
            _draggableItem(
              x: _notesX, y: _notesY, parentW: w, parentH: h,
              onMove: (d) => setState(() {
                _notesX = _clamp01(_notesX + d.dx / w);
                _notesY = _clamp01(_notesY + d.dy / h);
              }),
              child: Text(_mNotesCtrl.text.isEmpty ? 'ملاحظة' : _mNotesCtrl.text,
                  style: TextStyle(
                      color: _notesColor, fontSize: _notesSize)),
            ),

          if (_showQR)
            _draggableItem(
              x: _qrX, y: _qrY, parentW: w, parentH: h,
              onMove: (d) => setState(() {
                _qrX = _clamp01(_qrX + d.dx / w);
                _qrY = _clamp01(_qrY + d.dy / h);
              }),
              child: Container(
                padding: const EdgeInsets.all(2),
                color: Colors.white,
                child: QrImageView(
                  data: 'dummy',
                  version: QrVersions.auto,
                  size: _qrSize,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettingRow({
    required String label,
    required bool showToggle,
    bool? toggleValue,
    Function(bool)? onToggle,
    TextEditingController? textCtrl,
    required double sizeValue,
    required Function(double) onSizeChanged,
    required Color colorValue,
    required Function(Color) onColorChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (showToggle)
            Checkbox(
              value: toggleValue,
              onChanged: (v) => onToggle?.call(v ?? false),
              activeColor: AppTheme.gold,
            )
          else
            const SizedBox(width: 48), // مساحة بديلة للتشيك بوكس
          
          Expanded(
            flex: 3,
            child: textCtrl != null
                ? TextField(
                    controller: textCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                        labelText: label,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 4)),
                    onChanged: (_) => setState(() {}),
                  )
                : Text(label, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          
          // حجم الخط
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(Icons.format_size, color: Colors.white54, size: 14),
                Expanded(
                  child: Slider(
                    value: sizeValue,
                    min: 8,
                    max: label == 'الباركود' ? 120 : 40,
                    onChanged: onSizeChanged,
                    activeColor: AppTheme.gold,
                  ),
                ),
              ],
            ),
          ),
          
          // اللون
          DropdownButton<Color>(
            value: colorValue,
            dropdownColor: AppTheme.semiBlack,
            icon: const SizedBox(),
            underline: const SizedBox(),
            items: _availableColors.map((c) {
              return DropdownMenuItem(
                value: c,
                child: Container(width: 24, height: 24, color: c),
              );
            }).toList(),
            onChanged: (c) {
              if (c != null) onColorChanged(c);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleCardsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── المعرض / النماذج ──
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _templates.length + 1,
              itemBuilder: (_, i) {
                if (i < _templates.length) {
                  final tmpl = _templates[i];
                  final sel = _selectedTemplateIndex == i && !_useCustomImage;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedTemplateIndex = i;
                      _useCustomImage = false;
                    }),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: tmpl.background,
                        border: Border.all(
                            color: sel ? AppTheme.gold : tmpl.border,
                            width: sel ? 3 : 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(tmpl.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: tmpl.text,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      border: Border.all(
                          color: _useCustomImage ? AppTheme.gold : Colors.grey,
                          width: _useCustomImage ? 3 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: Colors.white),
                        Text('من المعرض',
                            style: TextStyle(color: Colors.white, fontSize: 10))
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Preview ──
          Container(
            height: 200,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 1)),
            child: LayoutBuilder(
              builder: (_, c) => _buildMultiPreviewCard(c.maxWidth, c.maxHeight),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _refreshPreview,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('تحديث الأرقام'),
            ),
          ),

          // ── إعدادات التوليد ──
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.darkGrey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _buildInputRow('اختر باقة هوتسبوت', _mProfileCtrl)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: _userLenCtrl,
                            decoration: const InputDecoration(labelText: 'أرقام المستخدم'),
                            style: const TextStyle(color: Colors.white))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: _passLenCtrl,
                            decoration: const InputDecoration(labelText: 'أرقام السر'),
                            style: const TextStyle(color: Colors.white))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: _cardCountCtrl,
                            decoration: const InputDecoration(labelText: 'عدد الكروت'),
                            style: const TextStyle(color: Colors.white))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: _pdfColsCtrl,
                            decoration: const InputDecoration(labelText: 'عدد الأعمدة بالصفحة (PDF)'),
                            style: const TextStyle(color: Colors.white))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: _pdfRowsCtrl,
                            decoration: const InputDecoration(labelText: 'عدد الصفوف بالصفحة (PDF)'),
                            style: const TextStyle(color: Colors.white))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── تصميم العناصر ──
          const Text('تخصيص العناصر (الحجم واللون)',
              style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          _buildAdvancedSettingRow(
            label: 'الباركود',
            showToggle: true,
            toggleValue: _showQR,
            onToggle: (v) => setState(() => _showQR = v),
            sizeValue: _qrSize,
            onSizeChanged: (v) => setState(() => _qrSize = v),
            colorValue: Colors.black, // لون الباركود ثابت عادة
            onColorChanged: (_) {},
          ),
          
          _buildAdvancedSettingRow(
            label: 'اسم الشبكة',
            showToggle: true,
            toggleValue: _showNetwork,
            onToggle: (v) => setState(() => _showNetwork = v),
            textCtrl: _mNetworkCtrl,
            sizeValue: _netSize,
            onSizeChanged: (v) => setState(() => _netSize = v),
            colorValue: _netColor,
            onColorChanged: (c) => setState(() => _netColor = c),
          ),

          _buildAdvancedSettingRow(
            label: 'اسم المستخدم',
            showToggle: false,
            sizeValue: _userSize,
            onSizeChanged: (v) => setState(() => _userSize = v),
            colorValue: _userColor,
            onColorChanged: (c) => setState(() => _userColor = c),
          ),

          _buildAdvancedSettingRow(
            label: 'كلمة المرور',
            showToggle: false,
            sizeValue: _passSize,
            onSizeChanged: (v) => setState(() => _passSize = v),
            colorValue: _passColor,
            onColorChanged: (c) => setState(() => _passColor = c),
          ),

          _buildAdvancedSettingRow(
            label: 'مدة الكرت',
            showToggle: true,
            toggleValue: _showDuration,
            onToggle: (v) => setState(() => _showDuration = v),
            textCtrl: _mDurationCtrl,
            sizeValue: _durSize,
            onSizeChanged: (v) => setState(() => _durSize = v),
            colorValue: _durColor,
            onColorChanged: (c) => setState(() => _durColor = c),
          ),

          _buildAdvancedSettingRow(
            label: 'ملاحظات',
            showToggle: true,
            toggleValue: _showNotes,
            onToggle: (v) => setState(() => _showNotes = v),
            textCtrl: _mNotesCtrl,
            sizeValue: _notesSize,
            onSizeChanged: (v) => setState(() => _notesSize = v),
            colorValue: _notesColor,
            onColorChanged: (c) => setState(() => _notesColor = c),
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade400,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isGeneratingPdf ? null : _generatePdfAndShare,
            child: _isGeneratingPdf
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('حفظ وطباعة (PDF)',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // توليد وبناء PDF المتعدد
  // ─────────────────────────────────────────────
  Future<void> _generatePdfAndShare() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);

    try {
      final count = (int.tryParse(_cardCountCtrl.text) ?? 10).clamp(1, 1000);
      final userLen = (int.tryParse(_userLenCtrl.text) ?? 6).clamp(4, 20);
      final passLen = (int.tryParse(_passLenCtrl.text) ?? 5).clamp(4, 20);
      final profile = _mProfileCtrl.text.trim();

      final cards = <_GeneratedCard>[];
      for (int i = 0; i < count; i++) {
        cards.add(_GeneratedCard(
          user: _generateRandom(length: userLen),
          pass: _generateRandom(length: passLen),
          profile: profile,
          network: _mNetworkCtrl.text.trim(),
          duration: _mDurationCtrl.text.trim(),
          notes: _mNotesCtrl.text.trim(),
        ));
      }

      // إضافة للراوتر
      if (widget.routerService != null) {
        for (final card in cards) {
          try {
            await widget.routerService!.sendCommand(
              '/ip/hotspot/user/add',
              params: {
                'name': card.user,
                'password': card.pass,
                'profile': card.profile,
                'comment': 'ST_Manager_Batch',
              },
            );
          } catch (_) {}
        }
      }

      final pdf = pw.Document();
      const pageFormat = PdfPageFormat.a4;
      
      final cols = (int.tryParse(_pdfColsCtrl.text) ?? 3).clamp(1, 10);
      final rows = (int.tryParse(_pdfRowsCtrl.text) ?? 7).clamp(1, 20);
      final cardsPerPage = cols * rows;

      const margin = 10.0;
      final usableW = pageFormat.width - (margin * 2);
      final usableH = pageFormat.height - (margin * 2);
      final cardW = usableW / cols;
      final cardH = usableH / rows;

      final imageBytes =
          _templateImage != null ? _templateImage!.readAsBytesSync() : null;

      pw.Font? arabicFont;
      try {
        final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
        arabicFont = pw.Font.ttf(fontData);
      } catch (_) {}

      for (int pageStart = 0; pageStart < cards.length; pageStart += cardsPerPage) {
        final children = <pw.Widget>[];

        for (int slot = 0; slot < cardsPerPage; slot++) {
          final idx = pageStart + slot;
          if (idx >= cards.length) break;

          final card = cards[idx];
          final col = slot % cols;
          final row = slot ~/ cols;

          final left = margin + (col * cardW);
          final top = margin + (row * cardH);

          children.add(
            pw.Positioned(
              left: left,
              top: top,
              child: _buildPdfCardWidget(
                card: card,
                cardW: cardW,
                cardH: cardH,
                imageBytes: imageBytes,
                arabicFont: arabicFont,
              ),
            ),
          );
        }

        // خطوط القص
        for (int col = 1; col < cols; col++) {
          children.add(pw.Positioned(
              left: margin + (col * cardW),
              top: 0,
              child: pw.Container(width: 0.5, height: pageFormat.height, color: PdfColors.grey)));
        }
        for (int row = 1; row < rows; row++) {
          children.add(pw.Positioned(
              left: 0,
              top: margin + (row * cardH),
              child: pw.Container(width: pageFormat.width, height: 0.5, color: PdfColors.grey)));
        }

        pdf.addPage(pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Stack(children: children)));
      }

      // صفحة الجدول
      pdf.addPage(pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('قائمة بيانات البطاقات', style: pw.TextStyle(font: arabicFont), textDirection: pw.TextDirection.rtl)),
          pw.TableHelper.fromTextArray(
            context: null,
            headers: ['#', 'USER', 'PASSWORD', 'PROFILE'],
            data: cards.asMap().entries.map((e) => ['${e.key + 1}', e.value.user, e.value.pass, e.value.profile]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ));

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cards_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        Share.shareXFiles([XFile(file.path)], text: 'بطاقات الهوتسبوت');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  pw.Widget _buildPdfCardWidget({
    required _GeneratedCard card,
    required double cardW,
    required double cardH,
    required Uint8List? imageBytes,
    pw.Font? arabicFont,
  }) {
    final t = _currentTemplate;
    
    PdfColor toPdfCol(Color c) => PdfColor.fromInt(c.value);

    return pw.Container(
      width: cardW,
      height: cardH,
      decoration: pw.BoxDecoration(
        color: imageBytes == null ? toPdfCol(t.background) : null,
        border: pw.Border.all(color: toPdfCol(t.border), width: 1),
      ),
      child: pw.Stack(
        children: [
          if (imageBytes != null)
            pw.Positioned.fill(child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.cover)),
          if (imageBytes == null)
            pw.Positioned(left: 0, top: 0, bottom: 0, width: cardW * 0.3, child: pw.Container(color: toPdfCol(t.accent))),

          if (_showNetwork)
            pw.Positioned(
              left: _netX * cardW, top: _netY * cardH,
              child: pw.Text(card.network, style: pw.TextStyle(font: arabicFont, color: toPdfCol(_netColor), fontSize: _netSize * (cardW/300))),
            ),
            
          pw.Positioned(
            left: _userX * cardW, top: _userY * cardH,
            child: pw.Text('User: ${card.user}', style: pw.TextStyle(color: toPdfCol(_userColor), fontSize: _userSize * (cardW/300), fontWeight: pw.FontWeight.bold)),
          ),
          
          pw.Positioned(
            left: _passX * cardW, top: _passY * cardH,
            child: pw.Text('Pass: ${card.pass}', style: pw.TextStyle(color: toPdfCol(_passColor), fontSize: _passSize * (cardW/300), fontWeight: pw.FontWeight.bold)),
          ),

          if (_showDuration)
            pw.Positioned(
              left: _durX * cardW, top: _durY * cardH,
              child: pw.Text(card.duration, style: pw.TextStyle(font: arabicFont, color: toPdfCol(_durColor), fontSize: _durSize * (cardW/300))),
            ),
            
          if (_showNotes)
            pw.Positioned(
              left: _notesX * cardW, top: _notesY * cardH,
              child: pw.Text(card.notes, style: pw.TextStyle(font: arabicFont, color: toPdfCol(_notesColor), fontSize: _notesSize * (cardW/300))),
            ),

          if (_showQR)
            pw.Positioned(
              left: _qrX * cardW, top: _qrY * cardH,
              child: pw.Container(
                color: PdfColors.white,
                padding: const pw.EdgeInsets.all(2),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'http://10.0.0.1/login?username=${card.user}&password=${card.pass}',
                  width: _qrSize * (cardW/300),
                  height: _qrSize * (cardW/300),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بطاقات الهوتسبوت'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.gold,
          tabs: const [
            Tab(text: 'بطاقة مفردة'),
            Tab(text: 'بطاقات متعددة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // لمنع السحب بالخطأ أثناء سحب العناصر
        children: [
          _buildSingleCardTab(),
          _buildMultipleCardsTab(),
        ],
      ),
    );
  }
}

