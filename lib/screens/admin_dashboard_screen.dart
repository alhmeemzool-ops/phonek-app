import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'admin_operations_monitor_screen.dart';
import 'admin_shop_applications_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  bool _authorized = false;
  String? _error;
  int _totalListings = 0;
  int _totalViews = 0;
  int _featured = 0;
  int _pending = 0;
  int _pendingShopApplications = 0;
  List<Map<String, dynamic>> _pendingListings = const [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw const AuthException('يجب تسجيل الدخول أولاً');
      if (user.email?.trim().toLowerCase() != 'alhmeemzool@gmail.com') {
        if (mounted) setState(() { _authorized = false; _loading = false; });
        return;
      }
      final rows = await client.from('listings').select('id, title, brand, price, city, image_urls, seller_id, status, created_at, view_count, is_featured').order('created_at', ascending: false);
      var views = 0; var featured = 0; final pending = <Map<String, dynamic>>[];
      for (final raw in (rows as List).whereType<Map<String, dynamic>>()) { views += (raw['view_count'] as num?)?.toInt() ?? 0; if (raw['is_featured'] == true) featured++; final status = raw['status'] as String?; if (status == 'pendingReview' || status == 'pending_review') pending.add(raw); }
      var shopPending = 0;
      try {
        final shopRows = await client.from('shop_applications').select('id').eq('verification_status', 'pending');
        shopPending = (shopRows as List).length;
      } catch (_) {}
      if (!mounted) return;
      setState(() { _authorized = true; _totalListings = rows.length; _totalViews = views; _featured = featured; _pending = pending.length; _pendingListings = pending; _pendingShopApplications = shopPending; _loading = false; });
    } on PostgrestException catch (error) { if (!mounted) return; setState(() { _error = 'تعذر تحميل لوحة الإدارة: ${error.message}'; _loading = false; }); }
    catch (error) { if (!mounted) return; setState(() { _error = error.toString(); _loading = false; }); }
  }

  Future<void> _moderate(Map<String, dynamic> listing, {required bool approve}) async {
    final id = listing['id'] as String?; if (id == null) return;
    final client = Supabase.instance.client; final user = client.auth.currentUser; if (user == null) return;
    String? reason;
    if (!approve) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('رفض الإعلان'),
          content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'سبب الرفض (اختياري)')),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('رفض'))],
        ),
      );
      if (!mounted || reason == null) return;
    }
    try {
      final updateData = <String, dynamic>{
        'status': approve ? 'active' : 'frozen',
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'reviewed_by': user.id,
      };
      if (!approve) updateData['rejection_reason'] = reason?.isEmpty == true ? null : reason;
      await client.from('listings').update(updateData).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'تم اعتماد الإعلان.' : 'تم رفض الإعلان.')));
      await _load();
    } on PostgrestException catch (error) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تنفيذ العملية: ${error.message}'))); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم الأدمن')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_authorized
              ? _message(Icons.lock_outline, 'ليس لديك صلاحية للوصول إلى لوحة الإدارة.')
              : _error != null
                  ? _errorView()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(children: [
                            Expanded(child: _statCard('الإعلانات', '$_totalListings', Icons.list_alt)),
                            const SizedBox(width: 10),
                            Expanded(child: _statCard('المشاهدات', '$_totalViews', Icons.remove_red_eye)),
                            const SizedBox(width: 10),
                            Expanded(child: _statCard('المميزة', '$_featured', Icons.star)),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _statCard('إعلانات تنتظر', '$_pending', Icons.pending_actions)),
                            const SizedBox(width: 10),
                            Expanded(child: _statCard('طلبات محلات', '$_pendingShopApplications', Icons.store_mall_directory_outlined)),
                          ]),
                          const SizedBox(height: 16),
                          Card(child: ListTile(
                            leading: const Icon(Icons.monitor_heart_outlined, color: AppColors.gold),
                            title: const Text('المراقبة التشغيلية', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('تسجيلات الدخول • الإعلانات الجديدة • المراسلات الجارية'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOperationsMonitorScreen())),
                          )),
                          const SizedBox(height: 10),
                          Card(child: ListTile(
                            leading: const Icon(Icons.storefront, color: AppColors.gold),
                            title: const Text('طلبات فتح المحلات', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('$_pendingShopApplications طلب بانتظار مراجعة التوثيق والتفاصيل.'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminShopApplicationsScreen())),
                          )),
                          const SizedBox(height: 12),
                          _statusCard(Icons.pending_actions, 'إعلانات بانتظار المراجعة', '$_pending إعلان يحتاج إلى مراجعة.'),
                          if (_pendingListings.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ..._pendingListings.map(_pendingCard),
                          ],
                          const SizedBox(height: 16),
                          _statusCard(Icons.flag_outlined, 'البلاغات', 'سيتم تفعيل البلاغات عند إضافة جدول البلاغات وربطه بالـRLS.'),
                        ],
                      ),
                    ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> listing) {
    final images = (listing['image_urls'] as List?)?.whereType<String>().toList() ?? const [];
    final title = listing['title'] as String? ?? 'إعلان بدون عنوان';
    final brand = listing['brand'] as String? ?? '';
    final city = listing['city'] as String? ?? '';
    final price = (listing['price'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: images.isEmpty
                  ? Container(width: 64, height: 64, color: AppColors.surface, child: const Icon(Icons.phone_android))
                  : Image.network(images.first, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: AppColors.surface, child: const Icon(Icons.broken_image))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (brand.isNotEmpty) Text(brand, style: const TextStyle(color: AppColors.textSecondary)),
              Text('$price ج.س${city.isEmpty ? '' : ' • $city'}', style: const TextStyle(color: AppColors.gold)),
            ])),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _moderate(listing, approve: false), icon: const Icon(Icons.close), label: const Text('رفض'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(onPressed: () => _moderate(listing, approve: true), icon: const Icon(Icons.check), label: const Text('اعتماد'))),
          ]),
        ]),
      ),
    );
  }

  Widget _message(IconData icon, String text) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 52, color: AppColors.textSecondary), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center)])));
  Widget _errorView() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off, size: 52, color: AppColors.textSecondary), const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))])));
  Widget _statusCard(IconData icon, String title, String subtitle) => Card(child: ListTile(leading: Icon(icon, color: AppColors.gold), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary))));
  Widget _statCard(String label, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [Icon(icon, color: AppColors.gold), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))])));
}
