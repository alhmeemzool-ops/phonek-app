import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final rows = await Supabase.instance.client
          .from('reports')
          .select('id,listing_id,reported_user_id,reason,details,status,admin_note,created_at')
          .order('created_at', ascending: false)
          .limit(500);
      if (mounted) setState(() => _reports = (rows as List).whereType<Map<String, dynamic>>().toList());
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تحميل البلاغات: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(Map<String, dynamic> report) async {
    var status = report['status']?.toString() ?? 'open';
    final note = TextEditingController(text: report['admin_note']?.toString() ?? '');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('مراجعة البلاغ'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(labelText: 'الحالة'),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('مفتوح')),
              DropdownMenuItem(value: 'reviewing', child: Text('قيد المراجعة')),
              DropdownMenuItem(value: 'resolved', child: Text('تمت المعالجة')),
              DropdownMenuItem(value: 'dismissed', child: Text('مغلق بلا إجراء')),
            ],
            onChanged: (value) => setDialogState(() => status = value ?? status),
          ),
          const SizedBox(height: 10),
          TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظة الإدارة')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {'status': status, 'note': note.text.trim()}), child: const Text('حفظ')),
        ],
      )),
    );
    note.dispose();
    if (result == null) return;
    try {
      await Supabase.instance.client.from('reports').update({
        'status': result['status'],
        'admin_note': result['note'],
        'reviewed_by': Supabase.instance.client.auth.currentUser?.id,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', report['id']);
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث البلاغ: $error')));
    }
  }

  String _reason(String value) => {
        'scam': 'احتيال أو دفع مشبوه',
        'wrong_info': 'معلومات غير صحيحة',
        'prohibited': 'محتوى مخالف',
        'harassment': 'إساءة أو مضايقة',
        'other': 'سبب آخر',
      }[value] ?? value;

  String _status(String value) => {'open': 'مفتوح', 'reviewing': 'قيد المراجعة', 'resolved': 'تمت المعالجة', 'dismissed': 'مغلق بلا إجراء'}[value] ?? value;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('البلاغات'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : _reports.isEmpty
                    ? const Center(child: Text('لا توجد بلاغات حالياً'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: _reports.length,
                          itemBuilder: (_, index) {
                            final report = _reports[index];
                            final status = report['status']?.toString() ?? 'open';
                            return Card(
                              child: ListTile(
                                leading: Icon(status == 'open' ? Icons.flag : Icons.flag_outlined, color: status == 'open' ? AppColors.danger : AppColors.gold),
                                title: Text(_reason(report['reason']?.toString() ?? 'other'), style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('الإعلان: ${report['listing_id'] ?? '—'}\nالحالة: ${_status(status)}\n${report['details'] ?? ''}'),
                                isThreeLine: true,
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: () => _update(report),
                              ),
                            );
                          },
                        ),
                      ),
      );
}
