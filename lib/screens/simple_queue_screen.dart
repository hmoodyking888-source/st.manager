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
  List<Map<String, dynamic>> _queues = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadQueues();
  }

  Future<void> _loadQueues() async {
    if (widget.routerService == null) return;
    setState(() => _loading = true);
    try {
      final data = await widget.routerService!.getSimpleQueue();
      setState(() => _queues = data);
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _addOrEditQueue({int? index}) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final maxLimitCtrl = TextEditingController();

    if (index != null) {
      final q = _queues[index];
      nameCtrl.text = q['name']?.toString() ?? '';
      targetCtrl.text = q['target']?.toString() ?? '';
      maxLimitCtrl.text = q['max-limit']?.toString() ?? '';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:
            Text(index == null ? 'إضافة Simple Queue' : 'تعديل Simple Queue'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم')),
              TextField(
                  controller: targetCtrl,
                  decoration: const InputDecoration(
                      labelText: 'الهدف (IP أو Interface)')),
              TextField(
                  controller: maxLimitCtrl,
                  decoration:
                      const InputDecoration(labelText: 'السرعة (مثلاً 2M/2M)')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final params = {
                'name': nameCtrl.text.trim(),
                'target': targetCtrl.text.trim(),
                'max-limit': maxLimitCtrl.text.trim(),
              };
              if (index == null) {
                await widget.routerService
                    ?.sendCommand('/queue/simple/add', params: params);
              } else {
                params['numbers'] = _queues[index]['.id']?.toString() ?? '';
                await widget.routerService
                    ?.sendCommand('/queue/simple/set', params: params);
              }
              _loadQueues();
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _deleteQueue(int index) async {
    final id = _queues[index]['.id']?.toString() ?? '';
    await widget.routerService
        ?.sendCommand('/queue/simple/remove', params: {'numbers': id});
    _loadQueues();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Queue')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.gold,
        onPressed: () => _addOrEditQueue(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _queues.isEmpty
              ? const Center(
                  child: Text('لا توجد قواعد',
                      style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: _queues.length,
                  itemBuilder: (_, i) {
                    final q = _queues[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.queue, color: AppTheme.gold),
                        title: Text(q['name'] ?? '',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${q['target']} | ${q['max-limit']}',
                            style: const TextStyle(color: Colors.white54)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.white54),
                                onPressed: () => _addOrEditQueue(index: i)),
                            IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteQueue(i)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
