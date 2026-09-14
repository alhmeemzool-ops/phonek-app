import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/phone_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/phone_card.dart';
import '../merchant_badges/merchant_badge_art.dart';

/// إدارة كتالوج التاجر: تعديل، تجميد/إلغاء تجميد، وحذف.
/// الإعلان المجمد يبقى تحت إدارة التاجر لكنه لا يظهر في السوق للزوار.
class MerchantCatalogScreen extends StatefulWidget {
  const MerchantCatalogScreen({super.key, this.shopId});
  final String? shopId;

  @override
  State<MerchantCatalogScreen> createState() => _MerchantCatalogScreenState();
}

class _MerchantCatalogScreenState extends State<MerchantCatalogScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  String? get _userId => widget.shopId ?? Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      setState(() { _loading = false; _error = 'يجب تسجيل الدخول لإدارة الكتالوج'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await Supabase.instance.client
          .from('listings')
          .select('*, profiles!listings_seller_id_fkey(*)')
          .eq('seller_id', userId)
          .order('created_at', ascending: false);
      _rows = (rows as List).whereType<Map<String, dynamic>>().toList();
    } on PostgrestException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setFrozen(Map<String, dynamic> row, bool frozen) async {
    final id = row['id'] as String;
    final userId = _userId;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('listings').update({'status': frozen ? 'frozen' : 'active'}).eq('id', id).eq('seller_id', userId);
      await _load();
      if (mounted) _message(frozen ? 'تم تجميد الإعلان' : 'تم إلغاء تجميد الإعلان');
    } catch (e) {
      if (mounted) _message('تعذر تغيير حالة الإعلان: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الإعلان؟'),
        content: const Text('سيختفي الإعلان من الكتالوج والسوق. هذا الإجراء لا يمكن التراجع عنه من الواجهة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    final userId = _userId;
    if (userId == null) return;
    try {
      // Keep the existing soft-delete convention used by PhoneK.
      await Supabase.instance.client.from('listings').update({'status': 'expired'}).eq('id', row['id']).eq('seller_id', userId);
      await _load();
      if (mounted) _message('تم حذف الإعلان');
    } catch (e) {
      if (mounted) _message('تعذر حذف الإعلان: $e');
    }
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    final title = TextEditingController(text: '${row['title'] ?? ''}');
    final price = TextEditingController(text: '${row['price'] ?? ''}');
    final city = TextEditingController(text: '${row['city'] ?? ''}');
    final description = TextEditingController(text: '${row['description'] ?? ''}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل الإعلان'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر')),
          TextField(controller: city, decoration: const InputDecoration(labelText: 'المدينة')),
          TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'الوصف')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (saved != true) return;
    final userId = _userId;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('listings').update({
        'title': title.text.trim(),
        'price': int.tryParse(price.text.replaceAll(',', '')) ?? row['price'],
        'city': city.text.trim(),
        'description': description.text.trim(),
      }).eq('id', row['id']).eq('seller_id', userId);
      await _load();
      if (mounted) _message('تم تحديث الإعلان');
    } catch (e) {
      if (mounted) _message('تعذر تعديل الإعلان: $e');
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  PhoneListing? _listingFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] is Map<String, dynamic> ? row['profiles'] as Map<String, dynamic> : <String, dynamic>{};
    try {
      return PhoneListing(
        id: row['id'] as String,
        title: row['title'] as String? ?? '',
        brand: row['brand'] as String? ?? '',
        price: (row['price'] as num?)?.toInt() ?? 0,
        priceIsNegotiable: row['price_is_negotiable'] as bool? ?? true,
        priceOnCall: row['price_on_call'] as bool? ?? false,
        oldPrice: (row['old_price'] as num?)?.toInt(),
        storage: row['storage'] as String? ?? '',
        ram: row['ram'] as String? ?? '',
        batteryHealthPercent: (row['battery_health_percent'] as num?)?.toInt(),
        condition: _condition(row['condition'] as String?),
        damageNotes: row['damage_notes'] as String?,
        hasBox: row['has_box'] as bool? ?? false,
        hasCharger: row['has_charger'] as bool? ?? false,
        hasInvoice: row['has_invoice'] as bool? ?? false,
        hasEarphones: row['has_earphones'] as bool? ?? false,
        warranty: WarrantyType.none,
        city: row['city'] as String? ?? '',
        imageUrls: (row['image_urls'] as List?)?.whereType<String>().toList() ?? const [],
        seller: SellerInfo(id: row['seller_id'] as String? ?? '', name: profile['name'] as String? ?? 'متجر PhoneK', phone: profile['phone'] as String? ?? '', city: profile['city'] as String? ?? row['city'] as String? ?? '', isShop: profile['is_shop'] as bool? ?? true, isVerifiedStore: profile['is_verified_store'] as bool? ?? false),
        status: _status(row['status'] as String?),
        createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now(),
        viewCount: (row['view_count'] as num?)?.toInt() ?? 0,
        isFeatured: row['is_featured'] as bool? ?? false,
        description: row['description'] as String? ?? '',
      );
    } catch (_) { return null; }
  }

  DeviceCondition _condition(String? value) {
    switch (value) {
      case 'new': case 'newDevice': return DeviceCondition.newDevice;
      case 'minor_scratches': case 'minorScratches': return DeviceCondition.minorScratches;
      case 'cracked': return DeviceCondition.cracked;
      default: return DeviceCondition.excellent;
    }
  }

  ListingStatus _status(String? value) {
    switch (value) {
      case 'sold': return ListingStatus.sold;
      case 'frozen': return ListingStatus.frozen;
      case 'expired': return ListingStatus.expired;
      case 'pending_review': case 'pendingReview': return ListingStatus.pendingReview;
      default: return ListingStatus.active;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كتالوج المتجر'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تحميل الكتالوج\n$_error', textAlign: TextAlign.center)))
              : _rows.isEmpty
                  ? _empty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) => _item(_rows[index]),
                      ),
                    ),
    );
  }

  Widget _empty() => ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 150), Icon(Icons.storefront_outlined, size: 58, color: AppColors.textSecondary), SizedBox(height: 12), Center(child: Text('الكتالوج فارغ')), SizedBox(height: 5), Center(child: Text('أضف أول إعلان إلى متجرك.', style: TextStyle(color: AppColors.textSecondary)))]);

  Widget _item(Map<String, dynamic> row) {
    final frozen = row['status'] == 'frozen';
    final sold = row['status'] == 'sold';
    final listing = _listingFromRow(row);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          if (listing != null) SizedBox(height: 265, child: PhoneCard(listing: listing)),
          Row(children: [
            Expanded(child: Text(frozen ? 'مجمد — لا يظهر للزوار' : sold ? 'مباع' : 'ظاهر للزوار', style: TextStyle(fontWeight: FontWeight.w800, color: frozen ? Colors.orange.shade800 : null))),
            if (frozen) const Icon(Icons.pause_circle_filled_rounded, size: 18) else if (!sold) const Icon(Icons.visibility_outlined, size: 18),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: sold ? null : () => _edit(row), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('تعديل'))),
            const SizedBox(width: 6),
            Expanded(child: OutlinedButton.icon(onPressed: sold ? null : () => _setFrozen(row, !frozen), icon: Icon(frozen ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18), label: Text(frozen ? 'إلغاء التجميد' : 'تجميد'))),
            const SizedBox(width: 6),
            IconButton(onPressed: () => _delete(row), tooltip: 'حذف', icon: const Icon(Icons.delete_outline_rounded)),
          ]),
        ]),
      ),
    );
  }
}
