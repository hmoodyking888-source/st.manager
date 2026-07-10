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

  String _mProfile = '';
  final _mNetworkCtrl = TextEditingController(text: 'سلطان نت');
  final _mNotesCtrl = TextEditingController();
  
  // حل مشكلة 7: إضافة متحكمات الحجم والمدة للتوليد المتعدد
  final _mValidityCtrl = TextEditingController(text: '1');
  String _mValidityUnit = 'يوم';
  final _mVolumeCtrl = TextEditingController(text: 'مفتوح');
  final _mPriceCtrl = TextEditingController();

  // حل مشكلة 5: تحديد نوع الأحرف للتوليد من الواجهة
  String _charType = 'mixed'; 
  bool _isGeneratingPdf = false;
  File? _templateImage;
  bool _useCustomImage = false;
  int _selectedTemplateIndex = 0;

  bool _showNetwork = true;
  bool _showDuration = true;
  bool _showNotes = true;

  // مواضع الحقول (X, Y)
  double _userX = 0.35, _userY = 0.20;
  double _passX = 0.35, _passY = 0.50;
  double _netX = 0.05, _netY = 0.05;
  double _durX = 0.05, _durY = 0.70;
  double _notesX = 0.40, _notesY = 0.80;

  // أحجام الخطوط / العناصر
  double _userSize = 18;
  double _passSize = 18;
  double _netSize = 14;
  double _durSize = 12;
  double _notesSize = 10;

  // ألوان الخطوط الافتراضية
  Color _userColor = Colors.black;
  Color _passColor = Colors.black;
  Color _netColor = Colors.blue.shade900;
  Color _durColor = Colors.white;
  Color _notesColor = Colors.white;

  // Preview
  String _previewUser = '123456';
  String _previewPass = '12345';

  // حل مشكلة 6: تحديث وزيادة مصفوفة القوالب لتصبح أكثر عصرية وفخامة
  final List<_CardTemplate> _templates = const [
    _CardTemplate(
      name: 'أسود وذهبي فخم',
      subtitle: 'هوية ملكية فاخرة',
      background: Color(0xFF111111),
      backgroundSoft: Color(0xFF1B1B1B),
      accent: Color(0xFFD4AF37),
      accentSoft: Color(0x66D4AF37),
      border: Color(0xFFD4AF37),
      text: Colors.white,
      mutedText: Color(0xFFBFBFBF),
    ),
    _CardTemplate(
      name: 'أزرق احترافي',
      subtitle: 'نمط شبكات متطور',
      background: Color(0xFFFFFFFF),
      backgroundSoft: Color(0xFFE3F2FD),
      accent: Color(0xFF0D47A1),
      accentSoft: Color(0x660D47A1),
      border: Color(0xFF1976D2),
      text: Colors.black,
      mutedText: Color(0xFF555555),
    ),
    _CardTemplate(
      name: 'سايبر نيون غامق',
      subtitle: 'لمسة تقنية حديثة',
      background: Color(0xFF0F172A),
      backgroundSoft: Color(0xFF1E293B),
      accent: Color(0xFF06B6D4),
      accentSoft: Color(0x6606B6D4),
      border: Color(0xFF0EA5E9),
      text: Colors.white,
      mutedText: Color(0xFF94A3B8),
    ),
    _CardTemplate(
      name: 'ياقوتي مميز',
      subtitle: 'أناقة حيوية',
      background: Color(0xFFFFF1F2),
      backgroundSoft: Color(0xFFFFE4E6),
      accent: Color(0xFFE11D48),
      accentSoft: Color(0x66E11D48),
      border: Color(0xFFFB7185),
      text: Colors.black,
      mutedText: Color(0xFF4C0519),
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

  bool _arabicFontLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfiles();
    _refreshPreview();
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
    _mNetworkCtrl.dispose();
    _mNotesCtrl.dispose();
    _mValidityCtrl.dispose();
    _mVolumeCtrl.dispose();
    _mPriceCtrl.dispose();
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
            _mProfile = _profiles.first; // حل مشكلة إسناد البروفايل للمتعدد
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
    return List.generate(length, () => chars[_random.nextInt(chars.length)])
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
      
      // حساب صلاحية بدء أول تسجيل دخول للكرت المفرد
      String? limitUptime;
      final valAmount = int.tryParse(_sValidityCtrl.text.trim()) ?? 0;
      if (valAmount > 0) {
        if (_sValidityUnit == 'يوم') {
          limitUptime = '${valAmount * 24}:00:00';
        } else {
          limitUptime = '${valAmount.toString().padLeft(2, '0')}:00:00';
        }
      }

      final Map<String, String> params = {  
        'name': _sUserCtrl.text.trim(),  
        'password': _sPassCtrl.text.trim(),  
        'profile': _sProfile,  
        'comment': comment,  
      };

      if (limitUptime != null) {
        params['limit-uptime'] = limitUptime;
      }

      await widget.routerService!.sendCommand(  
        '/ip/hotspot/user/add',  
        params: params,  
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

  Future<void> _deleteJustCreatedUser(String username) async {
    if (widget.routerService == null) return;
    try {
      final list = await widget.routerService!.sendCommand(
        '/ip/hotspot/user/print',
        params: {'?name': username},
      );
      if (list.isEmpty) return;
      final id = list.first['.id']?.toString() ?? '';
      if (id.isEmpty) return;
      await widget.routerService!.sendCommand(
        '/ip/hotspot/user/remove',
        params: {'numbers': id},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف الحساب "$username"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف الحساب: $e')),
        );
      }
    }
  }

  void _showSingleCardSuccessDialog() {
    final user = _sUserCtrl.text.trim();
    final pass = _sPassCtrl.text.trim();

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
                style: const TextStyle(  
                    color: Colors.amber,  
                    fontSize: 18,  
                    fontWeight: FontWeight.bold)),  
            Text('كلمة المرور: $pass',  
                style: const TextStyle(  
                    color: Colors.amber,  
                    fontSize: 18,  
                    fontWeight: FontWeight.bold)),  
            Text('الحجم: ${_sVolumeCtrl.text}',  
                style: const TextStyle(color: Colors.white70)),  
            Text('المدة: ${_sValidityCtrl.text} $_sValidityUnit',  
                style: const TextStyle(color: Colors.white70)),  
            const SizedBox(height: 16),  
            Row(  
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,  
              children: [  
                IconButton(  
                  onPressed: () {  
                    Share.share(  
                        'معلومات الدخول\nالمستخدم: $user\nكلمة المرور: $pass\nالمدة: ${_sValidityCtrl.text} $_sValidityUnit');  
                  },  
                  icon: const Icon(Icons.share, color: Colors.green, size: 30),  
                ),  
                IconButton(  
                  onPressed: () async {  
                    final confirm = await showDialog<bool>(  
                      context: ctx,  
                      builder: (_) => AlertDialog(  
                        backgroundColor: AppTheme.semiBlack,  
                        title: const Text('تأكيد الحذف',  
                            style: TextStyle(color: Colors.white)),  
                        content: Text(  
                          'هل تريد حذف الحساب "$user" الذي أُنشئ للتو؟',  
                          style: const TextStyle(color: Colors.white70),  
                        ),  
                        actions: [  
                          TextButton(  
                            onPressed: () => Navigator.pop(context, false),  
                            child: const Text('إلغاء',  
                                style: TextStyle(color: Colors.white54)),  
                          ),  
                          TextButton(  
                            onPressed: () => Navigator.pop(context, true),  
                            child: const Text('حذف',  
                                style: TextStyle(color: Colors.red)),  
                          ),  
                        ],  
                      ),  
                    );  
                    if (confirm == true) {  
                      await _deleteJustCreatedUser(user);  
                      if (ctx.mounted) Navigator.pop(ctx);  
                    }  
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
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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

          if (_showNetwork)  
            _draggableItem(  
              x: _netX,  
              y: _netY,  
              parentW: w,  
              parentH: h,  
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
            x: _userX,  
            y: _userY,  
            parentW: w,  
            parentH: h,  
            onMove: (d) => setState(() {  
              _userX = _clamp01(_userX + d.dx / w);  
              _userY = _clamp01(_userY + d.dy / h);  
            }),  
            child: Row(  
              children: [  
                Text('اسم المستخدم: ',  
                    style: TextStyle(  
                        color: _useCustomImage ? Colors.white70 : Colors.black54, fontSize: _userSize * 0.7)),  
                Text(_previewUser,  
                    style: TextStyle(  
                        color: _userColor,  
                        fontSize: _userSize,  
                        fontWeight: FontWeight.bold)),  
              ],  
            ),  
          ),  

          _draggableItem(  
            x: _passX,  
            y: _passY,  
            parentW: w,  
            parentH: h,  
            onMove: (d) => setState(() {  
              _passX = _clamp01(_passX + d.dx / w);  
              _passY = _clamp01(_passY + d.dy / h);  
            }),  
            child: Row(  
              children: [  
                Text('كلمة المرور: ',  
                    style: TextStyle(  
                        color: _useCustomImage ? Colors.white70 : Colors.black54, fontSize: _passSize * 0.7)),  
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
              x: _durX,  
              y: _durY,  
              parentW: w,  
              parentH: h,  
              onMove: (d) => setState(() {  
                _durX = _clamp01(_durX + d.dx / w);  
                _durY = _clamp01(_durY + d.dy / h);  
              }),  
              child: Text('${_mValidityCtrl.text} ${_mValidityUnit}',  
                  style: TextStyle(  
                      color: _durColor,  
                      fontSize: _durSize,  
                      fontWeight: FontWeight.bold)),  
            ),  

          if (_showNotes)  
            _draggableItem(  
              x: _notesX,  
              y: _notesY,  
              parentW: w,  
              parentH: h,  
              onMove: (d) => setState(() {  
                _notesX = _clamp01(_notesX + d.dx / w);  
                _notesY = _clamp01(_notesY + d.dy / h);  
              }),  
              child: Text(  
                  _mNotesCtrl.text.isEmpty ? 'ملاحظة' : _mNotesCtrl.text,  
                  style:  
                      TextStyle(color: _notesColor, fontSize: _notesSize)),  
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
            const SizedBox(width: 48), 

          Expanded(  
            flex: 3,  
            child: textCtrl != null  
                ? TextField(  
                    controller: textCtrl,  
                    style: const TextStyle(color: Colors.white, fontSize: 12),  
                    decoration: InputDecoration(  
                        labelText: label,  
                        isDense: true,  
                        contentPadding:  
                            const EdgeInsets.symmetric(vertical: 4)),  
                    onChanged: (_) => setState(() {}),  
                  )  
                : Text(label, style: const TextStyle(color: Colors.white)),  
          ),  
          const SizedBox(width: 8),  

          Expanded(  
            flex: 2,  
            child: Row(  
              children: [  
                const Icon(Icons.format_size, color: Colors.white54, size: 14),  
                Expanded(  
                  child: Slider(  
                    value: sizeValue,  
                    min: 8,  
                    max: 40,  
                    onChanged: onSizeChanged,  
                    activeColor: AppTheme.gold,  
                  ),  
                ),  
              ],  
            ),  
          ),  

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
              itemBuilder: (context, i) {
                if (i < _templates.length) {
                  final tmpl = _templates[i];
                  final sel = _selectedTemplateIndex == i && !_useCustomImage;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedTemplateIndex = i;
                      _useCustomImage = false;
                    }),
                    child: Container(
                      width: 90,
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
                    width: 90,
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
            decoration:  
                BoxDecoration(border: Border.all(color: Colors.white24, width: 1)),  
            child: LayoutBuilder(  
              builder: (_, c) =>  
                  _buildMultiPreviewCard(c.maxWidth, c.maxHeight),  
            ),  
          ),  
          Align(  
            alignment: Alignment.centerLeft,  
            child: TextButton.icon(  
              onPressed: _refreshPreview,  
              icon: const Icon(Icons.refresh, size: 16),  
              label: const Text('تحديث الأرقام المعاينة'),  
            ),  
          ),  

          // ── إعدادات التوليد السيرفر ──  
          Container(  
            padding: const EdgeInsets.all(12),  
            color: AppTheme.darkGrey,  
            child: Column(  
              children: [  
                // حل مشكلة 3: تغيير البروفايل إلى قائمة منسدلة ديناميكية
                Row(
                  children: [
                    const Expanded(
                        flex: 2,
                        child: Text('باقة هوتسبوت',
                            style: TextStyle(color: Colors.blue, fontSize: 14))),
                    Expanded(
                      flex: 3,
                      child: _isLoadingProfiles
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<String>(
                              value: _mProfile.isEmpty ? null : _mProfile,
                              dropdownColor: AppTheme.darkGrey,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                              items: _profiles
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _mProfile = v ?? '';
                              }),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // حل مشكلة 5: إضافة اختيار نوع الأحرف من الواجهة
                Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text('نوع الحروف', style: TextStyle(color: Colors.blue, fontSize: 14)),
                    ),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _charType,
                        dropdownColor: AppTheme.darkGrey,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                        items: const [
                          DropdownMenuItem(value: 'mixed', child: Text('مختلط (أحرف وأرقام)')),
                          DropdownMenuItem(value: 'numbers', child: Text('أرقام فقط')),
                          DropdownMenuItem(value: 'letters', child: Text('أحرف فقط')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _charType = v ?? 'mixed';
                          });
                          _refreshPreview();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // حل مشكلة 7: إضافة التحكم بالحجم والمدة والتكلفة في المتعدد
                Row(
                  children: [
                    const Expanded(
                        flex: 2,
                        child: Text('صلاحية الحساب', style: TextStyle(color: Colors.blue, fontSize: 14))),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _mValidityUnit,
                        dropdownColor: AppTheme.darkGrey,
                        style: const TextStyle(color: Colors.blue),
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 4)),
                        items: ['يوم', 'ساعة']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _mValidityUnit = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _mValidityCtrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 4)),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInputRow('حجم الكروت بت', _mVolumeCtrl, hint: 'مفتوح / ميغا / جيغا'),
                const SizedBox(height: 8),
                _buildInputRow('السعر الافتراضي', _mPriceCtrl, hint: 'اختياري'),
                const SizedBox(height: 12),

                Row(  
                  children: [  
                    Expanded(  
                        child: TextField(  
                            controller: _userLenCtrl,  
                            keyboardType: TextInputType.number,  
                            decoration: const InputDecoration(  
                                labelText: 'طول المستخدم'),  
                            style: const TextStyle(color: Colors.white))),  
                    const SizedBox(width: 8),  
                    Expanded(  
                        child: TextField(  
                            controller: _passLenCtrl,  
                            keyboardType: TextInputType.number,  
                            decoration:  
                                const InputDecoration(labelText: 'طول السر'),  
                            style: const TextStyle(color: Colors.white))),  
                    const SizedBox(width: 8),  
                    Expanded(  
                        child: TextField(  
                            controller: _cardCountCtrl,  
                            keyboardType: TextInputType.number,  
                            decoration:  
                                const InputDecoration(labelText: 'عدد الكروت'),  
                            style: const TextStyle(color: Colors.white))),  
                  ],  
                ),  
                const SizedBox(height: 8),  
                Row(  
                  children: [  
                    Expanded(  
                        child: TextField(  
                            controller: _pdfColsCtrl,  
                            keyboardType: TextInputType.number,  
                            decoration: const InputDecoration(  
                                labelText: 'الأعمدة بالصفحة'),  
                            style: const TextStyle(color: Colors.white))),  
                    const SizedBox(width: 8),  
                    Expanded(  
                        child: TextField(  
                            controller: _pdfRowsCtrl,  
                            keyboardType: TextInputType.number,  
                            decoration: const InputDecoration(  
                                labelText: 'الصفوف بالصفحة'),  
                            style: const TextStyle(color: Colors.white))),  
                  ],  
                ),  
              ],  
            ),  
          ),  
          const SizedBox(height: 16),  

          // ── تصميم العناصر ──  
          const Text('تخصيص العناصر (الحجم واللون)',  
              style:  
                  TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),  
          const SizedBox(height: 8),  

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
  bool _validateGenerationInputs() {
    final count = int.tryParse(_cardCountCtrl.text.trim());
    final userLen = int.tryParse(_userLenCtrl.text.trim());
    final passLen = int.tryParse(_passLenCtrl.text.trim());
    final cols = int.tryParse(_pdfColsCtrl.text.trim());
    final rows = int.tryParse(_pdfRowsCtrl.text.trim());

    String? error;  
    if (count == null || count < 1 || count > 1000) {  
      error = 'عدد الكروت يجب أن يكون رقماً بين 1 و1000';  
    } else if (userLen == null || userLen < 4 || userLen > 20) {  
      error = 'أرقام المستخدم يجب أن تكون بين 4 و20';  
    } else if (passLen == null || passLen < 4 || passLen > 20) {  
      error = 'أرقام كلمة السر يجب أن تكون بين 4 و20';  
    } else if (cols == null || cols < 1 || cols > 10) {  
      error = 'عدد الأعمدة يجب أن يكون بين 1 و10';  
    } else if (rows == null || rows < 1 || rows > 20) {  
      error = 'عدد الصفوف يجب أن يكون بين 1 و20';  
    }  

    if (error != null) {  
      ScaffoldMessenger.of(context).showSnackBar(  
        SnackBar(content: Text(error), backgroundColor: Colors.red),  
      );  
      return false;  
    }  
    return true;
  }

  List<_GeneratedCard> _generateUniqueCards({
    required int count,
    required int userLen,
    required int passLen,
    required String profile,
    required String network,
    required String duration,
    required String notes,
  }) {
    final usedUsers = <String>{};
    final cards = <_GeneratedCard>[];
    int attempts = 0;
    final maxAttempts = count * 50 + 500;

    while (cards.length < count && attempts < maxAttempts) {  
      attempts++;  
      final user = _generateRandom(length: userLen);  
      if (usedUsers.contains(user)) continue;  
      usedUsers.add(user);  
      cards.add(_GeneratedCard(  
        user: user,  
        pass: _generateRandom(length: passLen),  
        profile: profile,  
        network: network,  
        duration: duration,  
        notes: notes,  
      ));  
    }  

    return cards;
  }

  Future<void> _generatePdfAndShare() async {
    if (_isGeneratingPdf) return;
    if (!_validateGenerationInputs()) return;  

    setState(() => _isGeneratingPdf = true);  

    try {  
      final count = int.parse(_cardCountCtrl.text.trim());  
      final userLen = int.parse(_userLenCtrl.text.trim());  
      final passLen = int.parse(_passLenCtrl.text.trim());  
      final profile = _mProfile;  

      final durationLabel = '${_mValidityCtrl.text} ${_mValidityUnit}';

      final cards = _generateUniqueCards(  
        count: count,  
        userLen: userLen,  
        passLen: passLen,  
        profile: profile,  
        network: _mNetworkCtrl.text.trim(),  
        duration: durationLabel,  
        notes: _mNotesCtrl.text.trim(),  
      );  

      if (cards.length < count && mounted) {  
        ScaffoldMessenger.of(context).showSnackBar(  
          SnackBar(  
            content: Text(  
              'تم توليد ${cards.length} كرت فريد فقط من أصل $count المطلوبة',  
            ),  
            backgroundColor: Colors.orange,  
          ),  
        );  
      }  

      // حل مشكلة 4: بناء محددات الوقت لبدء الحساب عند أول تسجيل دخول تلقائياً
      String? limitUptime;
      final mValidVal = int.tryParse(_mValidityCtrl.text.trim()) ?? 0;
      if (mValidVal > 0) {
        if (_mValidityUnit == 'يوم') {
          limitUptime = '${mValidVal * 24}:00:00';
        } else {
          limitUptime = '${mValidVal.toString().padLeft(2, '0')}:00:00';
        }
      }

      // حل مشكلة 7: تحويل وحساب بايت الاستهلاك الأقصى للميكروتك
      String? limitBytesTotal;
      final volText = _mVolumeCtrl.text.trim().toLowerCase();
      if (volText != 'مفتوح' && volText.isNotEmpty) {
        final numMatch = RegExp(r'\d+').stringMatch(volText);
        if (numMatch != null) {
          final val = int.parse(numMatch);
          if (volText.contains('جيجا') || volText.contains('gb') || volText.contains('g')) {
            limitBytesTotal = (val * 1024 * 1024 * 1024).toString();
          } else if (volText.contains('ميجا') || volText.contains('mb') || volText.contains('m')) {
            limitBytesTotal = (val * 1024 * 1024).toString();
          }
        }
      }

      if (widget.routerService != null) {  
        const batchSize = 10;  
        for (int i = 0; i < cards.length; i += batchSize) {  
          final batch = cards.sublist(  
            i,  
            (i + batchSize).clamp(0, cards.length),  
          );  

          await Future.wait(batch.map((card) async {  
            try {  
              final Map<String, String> addParams = {
                'name': card.user,  
                'password': card.pass,  
                'profile': card.profile,  
                'comment': 'ST_Batch_Vol:${_mVolumeCtrl.text}_Price:${_mPriceCtrl.text}',  
              };

              if (limitUptime != null) addParams['limit-uptime'] = limitUptime;
              if (limitBytesTotal != null) addParams['limit-bytes-total'] = limitBytesTotal;

              await widget.routerService!.sendCommand(  
                '/ip/hotspot/user/add',  
                params: addParams,  
              );  
              return true;  
            } catch (_) {  
              return false;  
            }  
          }));  
        }  
      }  

      final pdf = pw.Document();  
      const pageFormat = PdfPageFormat.a4;  

      final cols = int.parse(_pdfColsCtrl.text.trim());  
      final rows = int.parse(_pdfRowsCtrl.text.trim());  
      final cardsPerPage = cols * rows;  

      const margin = 10.0;  
      final usableW = pageFormat.width - (margin * 2);  
      final usableH = pageFormat.height - (margin * 2);  
      final cardW = usableW / cols;  
      final cardH = usableH / rows;  

      final imageBytes =  
          _templateImage != null ? _templateImage!.readAsBytesSync() : null;  

      pw.Font? arabicFont;  
      _arabicFontLoadFailed = false;  
      try {  
        final fontData =  
            await rootBundle.load('assets/fonts/Cairo-Regular.ttf');  
        arabicFont = pw.Font.ttf(fontData);  
      } catch (_) {  
        _arabicFontLoadFailed = true;  
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

        for (int col = 1; col < cols; col++) {  
          children.add(pw.Positioned(  
              left: margin + (col * cardW),  
              top: 0,  
              child: pw.Container(  
                  width: 0.5, height: pageFormat.height, color: PdfColors.grey)));  
        }  
        for (int row = 1; row < rows; row++) {  
          children.add(pw.Positioned(  
              left: 0,  
              top: margin + (row * cardH),  
              child: pw.Container(  
                  width: pageFormat.width, height: 0.5, color: PdfColors.grey)));  
        }  

        pdf.addPage(pw.Page(  
            pageFormat: pageFormat,  
            margin: pw.EdgeInsets.zero,  
            build: (_) => pw.Stack(children: children)));  
      }  

      // حل مشكلة 2: تم حذف صفحة جدول "قائمة بيانات البطاقات" بالكامل بناءً على طلبك

      final bytes = await pdf.save();  
      final dir = await getTemporaryDirectory();  
      final file =  
          File('${dir.path}/cards_${DateTime.now().millisecondsSinceEpoch}.pdf');  
      await file.writeAsBytes(bytes, flush: true);  

      if (mounted) {  
        if (_arabicFontLoadFailed) {  
          ScaffoldMessenger.of(context).showSnackBar(  
            const SnackBar(  
              content: Text(  
                'تنبيه: تعذر تحميل الخط العربي؛ قد لا تظهر النصوص العربية بشكل صحيح داخل الـ PDF',  
              ),  
              backgroundColor: Colors.orange,  
            ),  
          );  
        }  
        Share.shareXFiles([XFile(file.path)], text: 'بطاقات الهوتسبوت المجهزة');  
      }  
    } catch (e) {  
      if (mounted) {  
        ScaffoldMessenger.of(context)  
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));  
      }  
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
            pw.Positioned.fill(  
                child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.cover)),  
          if (imageBytes == null)  
            pw.Positioned(  
              left: 0,  
              top: 0,  
              bottom: 0,  
              child: pw.Container(width: cardW * 0.3, color: toPdfCol(t.accent)),  
            ),  
          if (_showNetwork)  
            pw.Positioned(  
              left: _netX * cardW,  
              top: _netY * cardH,  
              child: pw.Text(card.network,  
                  style: pw.TextStyle(  
                      font: arabicFont,  
                      color: toPdfCol(_netColor),  
                      fontSize: _netSize * (cardW / 300)),  
                  textDirection: pw.TextDirection.rtl), // حل مشكلة 1: إجبار النص العربي على الاتجاه الصحيح  
            ),  
          pw.Positioned(  
            left: _userX * cardW,  
            top: _userY * cardH,  
            child: pw.Text('User: ${card.user}',  
                style: pw.TextStyle(  
                    color: toPdfCol(_userColor),  
                    fontSize: _userSize * (cardW / 300),  
                    fontWeight: pw.FontWeight.bold)),  
          ),  
          pw.Positioned(  
            left: _passX * cardW,  
            top: _passY * cardH,  
            child: pw.Text('Pass: ${card.pass}',  
                style: pw.TextStyle(  
                    color: toPdfCol(_passColor),  
                    fontSize: _passSize * (cardW / 300),  
                    fontWeight: pw.FontWeight.bold)),  
          ),  
          if (_showDuration)  
            pw.Positioned(  
              left: _durX * cardW,  
              top: _durY * cardH,  
              child: pw.Text(card.duration,  
                  style: pw.TextStyle(  
                      font: arabicFont,  
                      color: toPdfCol(_durColor),  
                      fontSize: _durSize * (cardW / 300)),  
                  textDirection: pw.TextDirection.rtl), // حل مشكلة 1  
            ),  
          if (_showNotes)  
            pw.Positioned(  
              left: _notesX * cardW,  
              top: _notesY * cardH,  
              child: pw.Text(card.notes,  
                  style: pw.TextStyle(  
                      font: arabicFont,  
                      color: toPdfCol(_notesColor),  
                      fontSize: _notesSize * (cardW / 300)),  
                  textDirection: pw.TextDirection.rtl), // حل مشكلة 1  
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
        physics: const NeverScrollableScrollPhysics(), 
        children: [
          _buildSingleCardTab(),
          _buildMultipleCardsTab(),
        ],
      ),
    );
  }
}
