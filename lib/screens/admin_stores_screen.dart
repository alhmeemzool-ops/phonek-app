import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/merchant_badges/badge_model.dart';
import '../features/merchant_badges/badge_widgets.dart';
import '../theme/app_theme.dart';

class AdminStoresScreen extends StatefulWidget {
  const AdminStoresScreen({super.key});

  @override
  State<AdminStoresScreen> createState() => _AdminStoresScreenState();
}

class _AdminStoresScreenState extends State<AdminStoresScreen> {
  bool _loading = true;
  String? _error;
  String? _selectedCity;
  List<Map<String, dynamic>> _stores = const [];
  final Map<String, int> _listingCounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;
      final profiles = await client.from('profiles').select('id, name, city, is_shop, is_verified_store, completed_sales, rating').eq('is_shop', true).order('name');
      final badgeStates = await client.from('merchant_badge_state').select('profile_id, identity_verified, license_verified, current_level').limit(5000);
      final statesByProfile = <String, Map<String, dynamic>>{for (final row in (badgeStates as List).whereType<Map<String, dynamic>>()) row['profile_id'].toString(): row};
      final listings = await client.from('listings').select('seller_id, status').limit(5000);
      _listingCounts
        ..clear()
        ..addEntries((listings as List).whereType<Map<String, dynamic>>().map((row) => MapEntry(row['seller_id']?.toString() ?? '', 1)))
        ..updateAll((key, value) => 0);
      for (final row in (listings as List).whereType<Map<String, dynamic>>()) {
        final id = row['seller_id']?.toString();
        if (id == null || id.isEmpty || row['status'] == 'deleted') continue;
        _listingCounts[id] = (_listingCounts[id] ?? 0) + 1;
      }
      if (!mounted) return;
      setState(() { _stores = (profiles as List).whereType<Map<String, dynamic>>().map((store) => {...store, ...?statesByProfile[store['id']?.toString()]}).toList(); _loading = false; });
    } on PostgrestException catch (error) {
      if (mounted) setState(() { _error = error.message; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filteredStores => _stores.where((store) => _selectedCity == null || store['city'] == _selectedCity).toList();

  @override
  Widget build(BuildContext context) {
    final cities = _stores.map((store) => store['city']?.toString()).whereType<String>().where((city) => city.isNotEmpty).toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المتاجر'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off, size: 48), const SizedBox(height: 12), Text('تعذر تحميل المتاجر\n$_error', textAlign: TextAlign.center), TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))])))
              : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
                  Text('${_stores.length} متجر مفعّل', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('التقييمات والإعلانات تُقرأ من البيانات الحية، ولا تُحسب من أرقام ثابتة.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(value: _selectedCity, decoration: const InputDecoration(labelText: 'فلتر الولاية / المدينة', prefixIcon: Icon(Icons.location_on_outlined)), items: [const DropdownMenuItem<String>(value: null, child: Text('كل الولايات والمدن')), ...cities.map((city) => DropdownMenuItem(value: city, child: Text(city)))], onChanged: (value) => setState(() => _selectedCity = value)),
                  const SizedBox(height: 14),
                  ..._filteredStores.map(_storeCard),
                  if (_filteredStores.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('لا توجد متاجر بهذا الفلتر'))),
                ])),
    );
  }

  Widget _storeCard(Map<String, dynamic> store) {
    final id = store['id']?.toString() ?? '';
    final sales = (store['completed_sales'] as num?)?.toInt() ?? 0;
    final rating = (store['rating'] as num?)?.toDouble() ?? 0;
    final level = levelForStatus(sales: sales, identityVerified: store['is_identity_verified'] == true || store['is_verified_store'] == true, licenseVerified: store['is_license_verified'] == true, rating: rating);
    final ads = _listingCounts[id] ?? 0;
    return Card(margin: const EdgeInsets.only(bottom: 12), child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _showStoreDetails(store, level, ads), child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      Row(children: [CircleAvatar(backgroundColor: AppColors.surfaceLight, child: Text((store['name']?.toString().trim().isNotEmpty == true ? store['name'].toString().trim()[0] : 'م'), style: const TextStyle(color: AppColors.gold))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store['name']?.toString() ?? 'متجر بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold)), Text('${store['city'] ?? '—'} • $ads إعلان', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))])), if (level > 0) MerchantBadgeChip(level: level, compact: true)]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _metric('التقييم الحقيقي', rating > 0 ? '${rating.toStringAsFixed(1)} ★' : '—')), Expanded(child: _metric('الإعلانات', '$ads')), Expanded(child: _metric('المبيعات', '$sales')), Expanded(child: _metric('المستوى', level == 0 ? 'غير مؤهل' : 'LVL $level'))]),
    ]))));
  }

  Widget _metric(String label, String value) => Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold)), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))]);

  void _showStoreDetails(Map<String, dynamic> store, int level, int ads) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: AppColors.surface, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(store['name']?.toString() ?? 'تفاصيل المتجر', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
      Text('${store['city'] ?? '—'} • ${store['is_verified_store'] == true ? 'متجر موثّق' : 'متجر مفعّل'}', style: const TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 18),
      Row(children: [Expanded(child: _metric('الإعلانات', '$ads')), Expanded(child: _metric('المبيعات', '${store['completed_sales'] ?? 0}')), Expanded(child: _metric('المستوى', level > 0 ? 'LVL $level' : '—'))]),
      const SizedBox(height: 18),
      const Text('الشارات المكتسبة', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final badge in merchantBadges.take(level)) MerchantBadgeChip(level: badge.level, compact: true)]),
    ]))));
  }
}
