import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class AdminShopVerificationsScreen extends StatefulWidget {
  const AdminShopVerificationsScreen({super.key});

  @override
  State<AdminShopVerificationsScreen> createState() => _AdminShopVerificationsScreenState();
}

class _AdminShopVerificationsScreenState extends State<AdminShopVerificationsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final rows = await _client
          .from('shop_verification_requests')
          .select('id, user_id, shop_name, phone, city, address, identity_image_path, identity_video_path, status, created_at')
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _requests = (rows as List).whereType<Map<String, dynamic>>().toList(growable: false);
        _loading = false;
        _error = null;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.code == '42501' ? 'هذه الصفحة متاحة للأدمن المصرّح له فقط.' : error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل طلبات التوثيق.';
      });
    }
  }

  Future<String?> _signedUrl(String path) async {
    try {
      return await _client.storage.from('verification-documents').createSignedUrl(path, 300);
    } catch (_) {
      return null;
    }
  }

  Future<void> _review(Map<String, dynamic> request, {required bool approve}) async {
    String? reason;
    if (!approve) {
      reason = await _rejectionReason();
      if (reason == null) return;
    }
    final admin = _client.auth.currentUser;
    if (admin == null) return;
    try {
      await _client.from('shop_verification_requests').update({
        'status': approve ? 'approved' : 'rejected',
        'rejection_reason': reason,
        'reviewed_by': admin.id,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', request['id']);
      await _client.from('profiles').update({
        'is_shop': approve,
        'shop_verification_status': approve ? 'approved' : 'rejected',
      }).eq('id', request['user_id']);
      await _client.from('shop_verification_audit').insert({
        'request_id': request['id'],
        'admin_id': admin.id,
        'action': approve ? 'approved' : 'rejected',
        'reason': reason,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'تم اعتماد حساب المحل' : 'تم رفض الطلب')),
      );
      await _loadRequests();
    } on PostgrestException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ المراجعة: ${error.message}')));
    }
  }

  Future<String?> _rejectionReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('سبب رفض الطلب'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'اكتب سببًا واضحًا ليتمكن صاحب المحل من التصحيح'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('رفض الطلب')),
        ],
      ),
    );
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }

  Future<void> _showDetails(Map<String, dynamic> request) async {
    final imageUrl = await _signedUrl(request['identity_image_path'].toString());
    final videoUrl = await _signedUrl(request['identity_video_path'].toString());
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(request['shop_name']?.toString() ?? 'طلب محل', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('الهاتف: ${request['phone'] ?? ''}'),
              Text('الموقع: ${request['city'] ?? ''} - ${request['address'] ?? ''}'),
              const SizedBox(height: 16),
              if (imageUrl != null) SelectableText('رابط صورة الإثبات المؤقت:\n$imageUrl', style: const TextStyle(fontSize: 12)),
              if (videoUrl != null) ...[
                const SizedBox(height: 10),
                SelectableText('رابط فيديو الإثبات المؤقت:\n$videoUrl', style: const TextStyle(fontSize: 12)),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(sheetContext); _review(request, approve: false); }, child: const Text('رفض'))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(sheetContext); _review(request, approve: true); }, child: const Text('اعتماد'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات توثيق المحلات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary))))
              : _requests.isEmpty
                  ? const Center(child: Text('لا توجد طلبات توثيق معلّقة'))
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final request = _requests[index];
                          return Card(
                            child: ListTile(
                              onTap: () => _showDetails(request),
                              leading: const CircleAvatar(child: Icon(Icons.storefront)),
                              title: Text(request['shop_name']?.toString() ?? 'محل'),
                              subtitle: Text('${request['city'] ?? ''} • ${request['address'] ?? ''}\nبانتظار المراجعة'),
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
