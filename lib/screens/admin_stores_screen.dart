import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/merchant_badges/badge_model.dart';
import '../features/merchant_badges/badge_widgets.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import 'shop_profile_screen.dart';

class AdminStoresScreen extends StatefulWidget {
  const AdminStoresScreen({super.key});
  @override State<AdminStoresScreen> createState() => _AdminStoresScreenState();
}

class _AdminStoresScreenState extends State<AdminStoresScreen> {
  bool _loading = true;
  String? _error;
  String? _selectedCity;
  List<Map<String, dynamic>> _stores = const [];
  final Map<String, int> _listingCounts = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final c = Supabase.instance.client;
      final profiles = await c.from('profiles').select('id,name,city,is_shop,is_verified_store,completed_sales,rating,phone,whatsapp,bio,avatar_url,reply_speed_label,shop_address,shop_location_url,shop_hours,payment_methods,created_at');
      final badges = await c.from('merchant_badge_state').select('profile_id,current_level,eligible_level,completed_sales,rating,identity_verified,license_verified,active_days').limit(5000);
      final byId = <String, Map<String, dynamic>>{
        for (final r in (badges as List).whereType<Map<String, dynamic>>()) r['profile_id'].toString(): r,
      };
      final listings = await c.from('listings').select('seller_id,status').limit(10000);
      _listingCounts.clear();
      for (final r in (listings as List).whereType<Map<String, dynamic>>()) {
        final id = r['seller_id']?.toString();
        if (id != null && id.isNotEmpty && r['status'] != 'deleted') {
          _listingCounts[id] = (_listingCounts[id] ?? 0) + 1;
        }
      }
      final stores = <Map<String, dynamic>>[];
      for (final raw in (profiles as List).whereType<Map<String, dynamic>>()) {
        final store = <String, dynamic>{...raw};
        final badge = byId[raw['id']?.toString()];
        if (badge != null) store.addAll(badge);
        stores.add(store);
      }
      stores.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      if (!mounted) return;
      setState(() { _stores = stores; _loading = false; });
    } on PostgrestException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered => _stores.where((s) => _selectedCity == null || s['city'] == _selectedCity).toList();

  @override
  Widget build(BuildContext context) {
    final cities = _stores.map((s) => s['city']?.toString()).whereType<String>().where((x) => x.isNotEmpty).toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المتاجر والشارات'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('تعذر تحميل المتاجر:\n$_error', textAlign: TextAlign.center), TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))])))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      Text('${_stores.length} متجر شغال', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      const Text('إدارة المتاجر النشطة وبياناتها ومستويات الشارات.', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _selectedCity,
                        decoration: const InputDecoration(labelText: 'المدينة'),
                        items: [const DropdownMenuItem<String>(value: null, child: Text('كل المدن')), ...cities.map((x) => DropdownMenuItem(value: x, child: Text(x)))],
                        onChanged: (v) => setState(() => _selectedCity = v),
                      ),
                      const SizedBox(height: 14),
                      ..._filtered.map(_card),
                    ],
                  ),
                ),
    );
  }

  Widget _card(Map<String, dynamic> s) {
    final id = s['id']?.toString() ?? '';
    final sales = (s['completed_sales'] as num?)?.toInt() ?? int.tryParse(s['completed_sales']?.toString() ?? '') ?? 0;
    final rating = (s['rating'] as num?)?.toDouble() ?? double.tryParse(s['rating']?.toString() ?? '') ?? 0;
    final created = DateTime.tryParse('${s['created_at']}');
    final fallbackActiveDays = created == null ? 0 : DateTime.now().difference(created).inDays.clamp(0, 100000);
    final activeDays = (s['active_days'] as num?)?.toInt() ?? fallbackActiveDays;
    final level = (s['current_level'] as num?)?.toInt() ?? levelForStatus(sales: sales, activeDays: activeDays, identityVerified: s['identity_verified'] == true || s['is_verified_store'] == true, licenseVerified: s['license_verified'] == true, rating: rating);
    final ads = _listingCounts[id] ?? 0;
    final seller = SellerInfo(id: id, name: s['name']?.toString() ?? 'متجر', phone: s['phone']?.toString() ?? '', whatsapp: s['whatsapp']?.toString(), bio: s['bio']?.toString(), avatarUrl: s['avatar_url']?.toString(), isShop: true, isVerifiedStore: s['is_verified_store'] == true, rating: rating, completedSales: sales, city: s['city']?.toString() ?? '', replySpeedLabel: s['reply_speed_label']?.toString() ?? 'يرد عادة خلال ساعات');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopProfileScreen(shopId: id, initialSeller: seller))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(children: [CircleAvatar(backgroundColor: AppColors.surfaceLight, child: Text((s['name']?.toString().trim().isNotEmpty == true) ? s['name'].toString().trim()[0] : 'م', style: const TextStyle(color: AppColors.gold))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s['name']?.toString() ?? 'متجر', style: const TextStyle(fontWeight: FontWeight.bold)), Text('${s['city'] ?? '—'} • $ads إعلان', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))])), if (level > 0) MerchantBadgeChip(level: level, compact: true)]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _metric('التقييم', rating > 0 ? '${rating.toStringAsFixed(1)} ★' : '—')), Expanded(child: _metric('الإعلانات', '$ads')), Expanded(child: _metric('المبيعات', '$sales')), Expanded(child: _metric('المستوى', level > 0 ? badgeForLevel(level).nameAr : 'غير مؤهل'))]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]);
}
