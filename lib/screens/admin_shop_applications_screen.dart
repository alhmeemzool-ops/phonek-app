import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      if (adminResult != true) {
        if (mounted) setState(() { authorized = false; loading = false; });
        return;
      }
      final data = await client.from('shop_verification_requests').select('*').order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          authorized = true;
          rows = List<Map<String, dynamic>>.from(data);
          loading = false;
        });
      }
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
          title: const Text('سبب الرفض'),
          content: TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(hintText: 'اكتب سبب الرفض (اختياري)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('رفض')),
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
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'تم اعتماد الطلب.' : 'تم رفض الطلب.')));
      }
      await load();
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ القرار: ${e.message}')));
    }
  }

  Future<String?> signed(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await client.storage.from('verification-documents').createSignedUrl(path, 300);
    } catch (_) {
      return null;
    }
  }

  void openDetails(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Details(row: row, signed: signed, onReview: review),
    );
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
                              padding: const EdgeInsets.all(16),
                              itemCount: rows.length,
                              itemBuilder: (_, i) {
                                final row = rows[i];
                                final status = row['status']?.toString() ?? 'pending';
                                return Card(
                                  child: ListTile(
                                    onTap: () => openDetails(row),
                                    leading: const CircleAvatar(child: Icon(Icons.storefront)),
                                    title: Text(row['shop_name']?.toString() ?? 'بدون اسم'),
                                    subtitle: Text('${row['city'] ?? ''}\n$status'),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.chevron_left),
                                  ),
                                );
                              },
                            ),
                    ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.row, required this.signed, required this.onReview});
  final Map<String, dynamic> row;
  final Future<String?> Function(String?) signed;
  final Future<void> Function(Map<String, dynamic>, bool) onReview;

  @override
  Widget build(BuildContext context) {
    final pending = row['status']?.toString() == 'pending';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(row['shop_name']?.toString() ?? 'طلب المحل', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            ...[
              'user_id', 'phone', 'city', 'address', 'latitude', 'longitude',
              'status', 'rejection_reason',
            ].map((key) => _field(key, row[key])),
            const Divider(height: 28),
            const Text('مواد التوثيق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _Media(title: 'صورة الهوية', path: row['identity_image_path']?.toString(), signed: signed, image: true),
            _Media(title: 'فيديو التحقق', path: row['identity_video_path']?.toString(), signed: signed),
            if (pending) ...[
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => onReview(row, false), icon: const Icon(Icons.close), label: const Text('رفض'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton.icon(onPressed: () => onReview(row, true), icon: const Icon(Icons.check), label: const Text('اعتماد'))),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _field(String key, dynamic value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('$key: ${value ?? '-'}'),
      );
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
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListTile(
              leading: Icon(image ? Icons.image_outlined : Icons.video_file_outlined),
              title: Text(title),
              subtitle: Text(path == null ? 'غير مرفوع' : (url == null ? 'تعذر إنشاء رابط مؤقت' : 'ملف خاص — رابط صالح 5 دقائق')),
              onTap: url == null ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            ),
            if (image && url != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(url, height: 180, width: double.infinity, fit: BoxFit.cover))),
          ]);
        },
      );
}
