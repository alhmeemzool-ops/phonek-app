import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/app_state.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminShopApplicationsScreen extends StatefulWidget {
  const AdminShopApplicationsScreen({super.key});

  @override
  State<AdminShopApplicationsScreen> createState() => _AdminShopApplicationsScreenState();
}

class _AdminShopApplicationsScreenState extends State<AdminShopApplicationsScreen> {
  final client = Supabase.instance.client;
  bool loading = true;
  bool authorized = false;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final user = client.auth.currentUser;
      final adminResult = user == null ? false : await client.rpc('is_admin');
      final appStateAdmin = context.read<AppState>().isAdmin;
      if (adminResult != true && !appStateAdmin) {
        if (mounted) setState(() { authorized = false; loading = false; });
        return;
      }
      final data = await client.from('shop_verification_requests').select('*').order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        authorized = true;
        rows = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } on PostgrestException catch (e) {
      if (mounted) setState(() { error = e.message; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> review(Map<String, dynamic> row, bool approve) async {
    String? reason;
    if (!approve) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('رفض طلب المحل'),
          content: TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(labelText: 'سبب الرفض', hintText: 'اكتب السبب بوضوح')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('تأكيد الرفض')),
          ],
        ),
      );
      if (reason == null) return;
    }
    final admin = client.auth.currentUser;
    if (admin == null) return;
    try {
      final update = <String, dynamic>{
        'status': approve ? 'approved' : 'rejected',
        'reviewed_by': admin.id,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (!approve && reason!.isNotEmpty) update['rejection_reason'] = reason;
      await client.from('shop_verification_requests').update(update).eq('id', row['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'تم اعتماد الطلب بنجاح.' : 'تم رفض الطلب.')));
      await load();
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ القرار: ${e.message}')));
    }
  }

  Future<String?> signed(String? path) async {
    if (path == null || path.isEmpty || path == 'not_provided') return null;
    try {
      final exists = await client.rpc('storage_object_exists', params: {'p_bucket': 'verification-documents', 'p_name': path});
      if (exists != true) return null;
      return await client.storage.from('verification-documents').createSignedUrl(path, 300);
    } catch (_) {
      return null;
    }
  }

  void openDetails(Map<String, dynamic> row) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _RequestDetailsPage(row: row, signed: signed, onReview: review)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات فتح المحلات'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : !authorized
              ? const Center(child: Text('ليس لديك صلاحية للوصول إلى طلبات المحلات.'))
              : error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('تعذر تحميل الطلبات: $error'), TextButton(onPressed: load, child: const Text('إعادة المحاولة'))]))
                  : RefreshIndicator(
                      onRefresh: load,
                      child: rows.isEmpty
                          ? ListView(children: const [SizedBox(height: 180), Center(child: Text('لا توجد طلبات محلات.'))])
                          : ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: rows.length,
                              itemBuilder: (_, i) {
                                final row = rows[i];
                                final status = row['status']?.toString() ?? 'pending';
                                final pending = status == 'pending';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        onTap: () => openDetails(row),
                                        leading: const CircleAvatar(child: Icon(Icons.storefront)),
                                        title: Text(row['shop_name']?.toString() ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('${row['phone'] ?? 'بدون هاتف'} • ${row['city'] ?? 'بدون مدينة'}\n${_statusLabel(status)}'),
                                        isThreeLine: true,
                                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                      ),
                                      if (pending)
                                        Row(children: [
                                          Expanded(child: OutlinedButton.icon(onPressed: () => review(row, false), icon: const Icon(Icons.close), label: const Text('رفض'))),
                                          const SizedBox(width: 8),
                                          Expanded(child: FilledButton.icon(onPressed: () => review(row, true), icon: const Icon(Icons.check), label: const Text('اعتماد'))),
                                        ]),
                                    ]),
                                  ),
                                );
                              },
                            ),
                    ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'approved' => 'معتمد',
        'rejected' => 'مرفوض',
        _ => 'بانتظار المراجعة',
      };
}

class _RequestDetailsPage extends StatelessWidget {
  const _RequestDetailsPage({required this.row, required this.signed, required this.onReview});
  final Map<String, dynamic> row;
  final Future<String?> Function(String?) signed;
  final Future<void> Function(Map<String, dynamic>, bool) onReview;

  @override
  Widget build(BuildContext context) {
    final pending = row['status']?.toString() == 'pending';
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل طلب المحل')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(row['shop_name']?.toString() ?? 'طلب محل', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _section('بيانات المحل', [
          _field('اسم المحل', row['shop_name']), _field('الهاتف', row['phone']), _field('المدينة', row['city']),
          _field('العنوان', row['address']), _field('الحالة', _status(row['status'])), _field('تاريخ الطلب', _time(row['created_at'])),
        ]),
        const SizedBox(height: 14),
        _section('بيانات الحساب', [_field('معرّف المستخدم', row['user_id']), _field('المراجع', row['reviewed_by']), _field('سبب الرفض', row['rejection_reason'])]),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ملفات التحقق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _Media(title: 'صورة الهوية', path: row['identity_image_path']?.toString(), signed: signed, image: true),
          _Media(title: 'فيديو التحقق', path: row['identity_video_path']?.toString(), signed: signed),
        ]))),
        if (pending) ...[
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => onReview(row, false), icon: const Icon(Icons.close), label: const Text('رفض الطلب'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(onPressed: () => onReview(row, true), icon: const Icon(Icons.check), label: const Text('اعتماد الطلب'))),
          ]),
        ],
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Divider(), ...children])));
  Widget _field(String label, dynamic value) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 115, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Text(value?.toString().isNotEmpty == true ? value.toString() : 'غير متوفر'))]));
  String _status(dynamic value) => value == 'approved' ? 'معتمد' : value == 'rejected' ? 'مرفوض' : 'بانتظار المراجعة';
  String _time(dynamic value) => value?.toString().replaceFirst('T', ' ').split('.').first ?? 'غير متوفر';
}

class _Media extends StatelessWidget {
  const _Media({required this.title, required this.path, required this.signed, this.image = false});
  final String title;
  final String? path;
  final Future<String?> Function(String?) signed;
  final bool image;

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
        future: signed(path),
        builder: (_, snapshot) {
          final url = snapshot.data;
          final unavailable = path == null || path!.isEmpty || path == 'not_provided' || (snapshot.connectionState == ConnectionState.done && url == null);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(image ? Icons.image_outlined : Icons.video_file_outlined),
              title: Text(title),
              subtitle: Text(unavailable ? 'الملف غير متوفر' : 'ملف خاص — رابط صالح 5 دقائق'),
              onTap: url == null ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            ),
            if (image && url != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(url, height: 190, width: double.infinity, fit: BoxFit.cover))),
          ]);
        },
      );
}
