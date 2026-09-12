import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminShopApplicationsScreen extends StatefulWidget {
  const AdminShopApplicationsScreen({super.key});
  @override
  State<AdminShopApplicationsScreen> createState() => _AdminShopApplicationsScreenState();
}

class _AdminShopApplicationsScreenState extends State<AdminShopApplicationsScreen> {
  final client = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await client.from('shop_applications').select('*').order('created_at', ascending: false);
      if (mounted) setState(() => rows = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل الطلبات: $e')));
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> review(Map<String, dynamic> row, bool approve) async {
    String? reason;
    if (!approve) {
      final c = TextEditingController();
      reason = await showDialog<String>(context: context, builder: (_) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(controller: c, maxLines: 4, decoration: const InputDecoration(hintText: 'اكتب سبب الرفض')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('رفض'))],
      ));
      if (reason == null) return;
    }
    final admin = client.auth.currentUser;
    if (admin == null) return;
    try {
      final update = <String, dynamic>{'verification_status': approve ? 'approved' : 'rejected', 'reviewed_by': admin.id, 'reviewed_at': DateTime.now().toUtc().toIso8601String()};
      if (!approve) update['rejection_reason'] = reason;
      await client.from('shop_applications').update(update).eq('id', row['id']);
      await load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ القرار: $e'))); }
  }

  Future<String?> signed(String? path) async {
    if (path == null || path.isEmpty) return null;
    try { return await client.storage.from('shop-application-media').createSignedUrl(path, 300); } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('طلبات فتح المحلات'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: rows.length,
        itemBuilder: (_, i) { final r = rows[i]; final status = r['verification_status']?.toString() ?? 'pending'; return Card(child: ListTile(
          onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _Details(row: r, signed: signed)),
          leading: const CircleAvatar(child: Icon(Icons.storefront)), title: Text(r['shop_name']?.toString() ?? 'بدون اسم'),
          subtitle: Text('${r['city'] ?? ''}\n$status'), isThreeLine: true,
          trailing: status == 'pending' ? PopupMenuButton<String>(onSelected: (v) => review(r, v == 'approve'), itemBuilder: (_) => const [PopupMenuItem(value: 'approve', child: Text('اعتماد')), PopupMenuItem(value: 'reject', child: Text('رفض'))]) : const Icon(Icons.chevron_left),
        )); },
      ),
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.row, required this.signed});
  final Map<String, dynamic> row; final Future<String?> Function(String?) signed;
  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(row['shop_name']?.toString() ?? 'طلب المحل', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    ...['phone','city','address','latitude','longitude','location_accuracy_m','verification_status','liveness_status','identity_match_status','kyc_result','rejection_reason'].map((k) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('$k: ${row[k] ?? '-'}'))),
    const Divider(height: 28), const Text('مواد التوثيق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    _Media(title: 'صورة الوجه', path: row['face_photo_path']?.toString(), signed: signed),
    _Media(title: 'فيديو الحيوية', path: row['liveness_video_path']?.toString(), signed: signed),
    _Media(title: 'صورة الهوية', path: row['identity_photo_path']?.toString(), signed: signed),
  ]))));
}

class _Media extends StatelessWidget {
  const _Media({required this.title, required this.path, required this.signed});
  final String title; final String? path; final Future<String?> Function(String?) signed;
  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(future: signed(path), builder: (_, s) => ListTile(leading: const Icon(Icons.verified_user), title: Text(title), subtitle: Text(path == null ? 'غير مرفوع' : (s.data == null ? 'جاري تجهيز رابط آمن...' : 'ملف خاص — رابط مؤقت'))));
}
