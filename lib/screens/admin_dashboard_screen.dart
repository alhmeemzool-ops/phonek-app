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
      final rows = await client.from('listings').select('id, title, brand, price, city, image_urls, seller_id, status, created_at, view_count, is_featured, description, condition, storage, color, ram, warranty, phone_model');
      var views = 0; var featured = 0; final pending = <Map<String, dynamic>>[];
      for (final raw in (rows as List).whereType<Map<String, dynamic>>()) {
        views += (raw['view_count'] as num?)?.toInt() ?? 0;
        if (raw['is_featured'] == true) featured++;
        final status = raw['status'] as String?;
        if (status == 'pendingReview' || status == 'pending_review') pending.add(raw);
      }
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
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'تم اعتماد الإعلان.' : 'تم رفض الإعلان.')));
      await _load();
    } on PostgrestException catch (error) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تنفيذ العملية: ${error.message}'))); }
  }

  void _openPendingListings() {
    if (_pendingListings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد إعلانات منتظرة للمراجعة حالياً.')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('الإعلانات المنتظرة للمراجعة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._pendingListings.map(_pendingCard),
          ],
        ),
      ),
    );
  }

  void _openListingDetails(Map<String, dynamic> listing) {
    final images = (listing['image_urls'] as List?)?.whereType<String>().toList() ?? const [];
    final title = listing['title'] as String? ?? 'إعلان بدون عنوان';
    final brand = listing['brand'] as String? ?? '';
    final city = listing['city'] as String? ?? '';
    final description = listing['description'] as String? ?? '';
    final condition = listing['condition'] as String? ?? '';
    final storage = listing['storage']?.toString() ?? '';
    final ram = listing['ram']?.toString() ?? '';
    final color = listing['color']?.toString() ?? '';
    final warranty = listing['warranty']?.toString() ?? '';
    final model = listing['phone_model']?.toString() ?? '';
    final price = (listing['price'] as num?)?.toInt() ?? 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              const Expanded(child: Text('تفاصيل الإعلان', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            if (images.isNotEmpty) ...[
              SizedBox(height: 230, child: PageView.builder(itemCount: images.length, itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(images[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 50))))))),
              const SizedBox(height: 14),
            ],
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (brand.isNotEmpty) _detailRow('العلامة', brand),
            if (model.isNotEmpty) _detailRow('الموديل', model),
            _detailRow('السعر', '$price ج.س'),
            if (city.isNotEmpty) _detailRow('المدينة', city),
            if (condition.isNotEmpty) _detailRow('الحالة', condition),
            if (storage.isNotEmpty) _detailRow('التخزين', storage),
            if (ram.isNotEmpty) _detailRow('الرام', ram),
            if (color.isNotEmpty) _detailRow('اللون', color),
            if (warranty.isNotEmpty) _detailRow('الضمان', warranty),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('الوصف', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(description),
            ],
            const SizedBox(height: 18),
            const Text('بعد مراجعة التفاصيل والصور يمكنك اتخاذ القرار:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _moderate(listing, approve: false), icon: const Icon(Icons.close), label: const Text('رفض'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(onPressed: () => _moderate(listing, approve: true), icon: const Icon(Icons.check), label: const Text('اعتماد'))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)))]));

  Widget _pendingCard(Map<String, dynamic> listing) {
    final images = (listing['image_urls'] as List?)?.whereType<String>().toList() ?? const [];
    final title = listing['title'] as String? ?? 'إعلان بدون عنوان';
    final brand = listing['brand'] as String? ?? '';
    final city = listing['city'] as String? ?? '';
    final price = (listing['price'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openListingDetails(listing),
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
              const Icon(Icons.chevron_left, color: AppColors.gold),
            ]),
            const SizedBox(height: 6),
            const Text('اضغط على الإعلان لعرض التفاصيل والصور قبل القرار', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _openListingDetails(listing), icon: const Icon(Icons.visibility_outlined), label: const Text('التفاصيل'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: () => _moderate(listing, approve: false), icon: const Icon(Icons.close), label: const Text('رفض'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(onPressed: () => _moderate(listing, approve: true), icon: const Icon(Icons.check), label: const Text('اعتماد'))),
            ]),
          ]),
        ),
      ),
    );
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
                          const SizedBox(height: 10),
                          Card(child: ListTile(
                            leading: const Icon(Icons.pending_actions, color: AppColors.gold),
                            title: const Text('الإعلانات المنتظرة للمراجعة', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('$_pending إعلان يحتاج إلى مراجعة واعتماد.'),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: _openPendingListings,
                          )),
                          const SizedBox(height: 12),
                          if (_pendingListings.isNotEmpty) ..._pendingListings.map(_pendingCard),
                          const SizedBox(height: 16),
                          _statusCard(Icons.flag_outlined, 'البلاغات', 'سيتم تفعيل البلاغات عند إضافة جدول البلاغات وربطه بالـRLS.'),
                        ],
                      ),
                    ),
    );
  }

  Widget _message(IconData icon, String text) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 52, color: AppColors.textSecondary), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center)])));
  Widget _errorView() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off, size: 52, color: AppColors.textSecondary), const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))])));
  Widget _statusCard(IconData icon, String title, String subtitle) => Card(child: ListTile(leading: Icon(icon, color: AppColors.gold), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary))));
  Widget _statCard(String label, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [Icon(icon, color: AppColors.gold), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))])));
}
