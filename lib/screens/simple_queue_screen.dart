import 'package:flutter/material.dart';
import 'package:st_manager/services/router_service.dart';
import 'package:st_manager/theme/app_theme.dart';

class SimpleQueueScreen extends StatefulWidget {
  final RouterService? routerService;
  const SimpleQueueScreen({super.key, required this.routerService});

  @override
  State<SimpleQueueScreen> createState() => _SimpleQueueScreenState();
}

class _SimpleQueueScreenState extends State<SimpleQueueScreen> {
  int _currentIndex = 0; // 0 = Simple Queue, 1 = Queue Tree
  
  List<Map<String, dynamic>> _simpleQueues = [];
  List<Map<String, dynamic>> _treeQueues = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // دالة موحدة لتحميل البيانات بناءً على الشاشة المحددة
  Future<void> _loadData() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    
    try {
      if (_currentIndex == 0) {
        // تحميل Simple Queues
        final data = await widget.routerService!.getSimpleQueue();
        setState(() => _simpleQueues = data);
      } else {
        // تحميل Queue Tree
        // ملاحظة: تأكد من أن دالة sendCommand تعيد البيانات بالشكل الصحيح أو يمكنك إنشاء دالة getQueueTree() في RouterService
        final response = await widget.routerService!.sendCommand('/queue/tree/print');
        if (response != null) {
          setState(() => _treeQueues = List<Map<String, dynamic>>.from(response));
        }
      }
    } catch (_) {
      // يمكنك هنا إضافة معالجة للأخطاء (مثل إظهار SnackBar)
    }
    
    setState(() => _loading = false);
  }

  // ==========================================
  // عمليات Simple Queue
  // ==========================================
  void _addOrEditSimpleQueue({int? index}) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final maxLimitCtrl = TextEditingController();

    if (index != null) {
      final q = _simpleQueues[index];
      nameCtrl.text = q['name']?.toString() ?? '';
      targetCtrl.text = q['target']?.toString() ?? '';
      maxLimitCtrl.text = q['max-limit']?.toString() ?? '';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(index == null ? 'إضافة Simple Queue' : 'تعديل Simple Queue'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
              TextField(controller: targetCtrl, decoration: const InputDecoration(labelText: 'الهدف (IP أو Interface)')),
              TextField(controller: maxLimitCtrl, decoration: const InputDecoration(labelText: 'السرعة (مثلاً 2M/2M)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final params = {
                'name': nameCtrl.text.trim(),
                'target': targetCtrl.text.trim(),
                'max-limit': maxLimitCtrl.text.trim(),
              };
              if (index == null) {
                await widget.routerService?.sendCommand('/queue/simple/add', params: params);
              } else {
                params['numbers'] = _simpleQueues[index]['.id']?.toString() ?? '';
                await widget.routerService?.sendCommand('/queue/simple/set', params: params);
              }
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // عمليات Queue Tree
  // ==========================================
  void _addOrEditTreeQueue({int? index}) {
    final nameCtrl = TextEditingController();
    final parentCtrl = TextEditingController(text: 'global'); // افتراضي
    final maxLimitCtrl = TextEditingController();

    if (index != null) {
      final q = _treeQueues[index];
      nameCtrl.text = q['name']?.toString() ?? '';
      parentCtrl.text = q['parent']?.toString() ?? 'global';
      maxLimitCtrl.text = q['max-limit']?.toString() ?? '';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(index == null ? 'إضافة Queue Tree' : 'تعديل Queue Tree'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
              TextField(controller: parentCtrl, decoration: const InputDecoration(labelText: 'الأب (Parent)')),
              TextField(controller: maxLimitCtrl, decoration: const InputDecoration(labelText: 'السرعة (Max Limit)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final params = {
                'name': nameCtrl.text.trim(),
                'parent': parentCtrl.text.trim(),
                'max-limit': maxLimitCtrl.text.trim(),
              };
              if (index == null) {
                await widget.routerService?.sendCommand('/queue/tree/add', params: params);
              } else {
                params['numbers'] = _treeQueues[index]['.id']?.toString() ?? '';
                await widget.routerService?.sendCommand('/queue/tree/set', params: params);
              }
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // دالة تأكيد وحذف عامة (يمكن استخدامها للاثنين)
  void _confirmDelete(int index, bool isSimpleQueue) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد أنك تريد حذف هذه القاعدة؟\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              if (isSimpleQueue) {
                final id = _simpleQueues[index]['.id']?.toString() ?? '';
                await widget.routerService?.sendCommand('/queue/simple/remove', params: {'numbers': id});
              } else {
                final id = _treeQueues[index]['.id']?.toString() ?? '';
                await widget.routerService?.sendCommand('/queue/tree/remove', params: {'numbers': id});
              }
              _loadData();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // واجهة المستخدم الأساسية (UI Builders)
  // ==========================================
  
  Widget _buildSimpleQueueList() {
    if (_simpleQueues.isEmpty) {
      return const Center(child: Text('لا توجد قواعد Simple', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: _simpleQueues.length,
      itemBuilder: (_, i) {
        final q = _simpleQueues[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.queue, color: AppTheme.gold),
            title: Text(q['name'] ?? '', style: const TextStyle(color: Colors.white)),
            subtitle: Text('${q['target']} | ${q['max-limit']}', style: const TextStyle(color: Colors.white54)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white54),
                    onPressed: () => _addOrEditSimpleQueue(index: i)),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(i, true)), // true = Simple Queue
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQueueTreeList() {
    if (_treeQueues.isEmpty) {
      return const Center(child: Text('لا توجد قواعد Tree', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: _treeQueues.length,
      itemBuilder: (_, i) {
        final q = _treeQueues[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.account_tree, color: AppTheme.gold),
            title: Text(q['name'] ?? '', style: const TextStyle(color: Colors.white)),
            subtitle: Text('Parent: ${q['parent']} | Limit: ${q['max-limit']}', style: const TextStyle(color: Colors.white54)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white54),
                    onPressed: () => _addOrEditTreeQueue(index: i)),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(i, false)), // false = Queue Tree
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Simple Queues' : 'Queue Tree'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: () {
          if (_currentIndex == 0) {
            _addOrEditSimpleQueue();
          } else {
            _addOrEditTreeQueue();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : (_currentIndex == 0 ? _buildSimpleQueueList() : _buildQueueTreeList()),
          
      // شريط التنقل السفلي
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppTheme.gold,
        unselectedItemColor: Colors.white54,
        onTap: (index) {
          if (_currentIndex != index) {
            setState(() => _currentIndex = index);
            _loadData(); // تحميل البيانات الخاصة بالشاشة الجديدة عند التبديل
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.line_style),
            label: 'Simple Queues',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_tree_outlined),
            label: 'Queue Tree',
          ),
        ],
      ),
    );
  }
}
