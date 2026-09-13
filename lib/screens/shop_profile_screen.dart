import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_state.dart';
import '../models/phone_model.dart';
import '../theme/app_theme.dart';
import '../widgets/phone_card.dart';
import '../features/merchant_badges/badge_model.dart';
import '../features/merchant_badges/badge_widgets.dart';
import 'phone_details_screen.dart';
import 'chat_screen.dart';

class ShopProfileScreen extends StatefulWidget {
  const ShopProfileScreen({super.key, required this.shopId, this.initialSeller});
  final String shopId;
  final SellerInfo? initialSeller;
  @override State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _profile = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final row = await Supabase.instance.client.from('public_shop_profiles').select('*').eq('id', widget.shopId).maybeSingle();
      if (row == null) throw StateError('المتجر غير موجود');
      if (!mounted) return;
      setState(() { _profile = row; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.gold)));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('المتجر')), body: Center(child: Text('تعذر تحميل المتجر:\n$_error', textAlign: TextAlign.center)));
    final state = context.watch<AppState>();
    final listings = state.listings.where((p) => p.seller.id == widget.shopId && p.status == ListingStatus.active).toList();
    final seller = listings.isNotEmpty ? listings.first.seller : widget.initialSeller;
    final sales = seller?.completedSales ?? (_profile['completed_sales'] as num?)?.toInt() ?? 0;
    final rating = seller?.rating ?? (_profile['rating'] as num?)?.toDouble() ?? 0;
    final level = levelForSales(sales);
    final name = _profile['name']?.toString() ?? seller?.name ?? 'المتجر';
    final bio = _profile['bio']?.toString() ?? seller?.bio ?? '';
    final address = _profile['shop_address']?.toString() ?? '';
    final location = _profile['shop_location_url']?.toString() ?? '';
    final payments = (_profile['payment_methods'] as List?)?.whereType<String>().toList() ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(14), children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [
              CircleAvatar(radius: 30, backgroundColor: AppColors.surfaceLight, child: const Icon(Icons.storefront, color: AppColors.gold, size: 30)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Row(children: [if (level > 0) MerchantBadgeChip(level: level, compact: true), const SizedBox(width: 8), Text(level > 0 ? badgeForLevel(level).nameAr : 'تاجر')])])),
            ]),
            if (bio.trim().isNotEmpty) ...[const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: Text(bio, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)))],
            const SizedBox(height: 14),
            Row(children: [Expanded(child: _metric('التقييم', rating > 0 ? '${rating.toStringAsFixed(1)} ★' : '—')), Expanded(child: _metric('المبيعات', '$sales')), Expanded(child: _metric('الإعلانات', '${listings.length}'))]),
          ]))),
          const SizedBox(height: 10),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('تفاصيل المتجر', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _info(Icons.location_on_outlined, 'الموقع', address.isEmpty ? (seller?.city ?? 'غير محدد') : address),
            _info(Icons.schedule, 'ساعات العمل', _hours(_profile['shop_hours'])),
            if (payments.isNotEmpty) _info(Icons.payments_outlined, 'طرق الدفع', payments.join(' • ')),
            if (location.trim().isNotEmpty) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.map_outlined, color: AppColors.gold), title: const Text('فتح موقع المتجر'), onTap: () => _open(location)),
          ]))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: seller == null ? null : () => _call(seller.phone), icon: const Icon(Icons.call), label: const Text('اتصال'))),
            const SizedBox(width: 7),
            Expanded(child: OutlinedButton.icon(onPressed: seller == null ? null : () => _whatsapp(seller.whatsapp), icon: const Icon(Icons.chat), label: const Text('واتساب'))),
            const SizedBox(width: 7),
            Expanded(child: OutlinedButton.icon(onPressed: seller == null ? null : () => _chat(context, seller, listings), icon: const Icon(Icons.forum), label: const Text('دردشة'))),
          ]),
          const SizedBox(height: 18),
          const Text('إعلانات المتجر', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (listings.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('لا توجد إعلانات نشطة حالياً'))),
          ...listings.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: SizedBox(height: 330, child: PhoneCard(listing: p, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhoneDetailsScreen(listing: p))))))),
        ]),
      ),
    );
  }

  Widget _metric(String label, String value) => Column(children: [Text(value, style: const TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))]);
  Widget _info(IconData icon, String title, String value) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: AppColors.gold), title: Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)), subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)));
  String _hours(dynamic value) { if (value is Map) return value.entries.map((e) => '${e.key}: ${e.value}').join(' • '); if (value is List) return value.join(' • '); return value?.toString().trim().isNotEmpty == true ? value.toString() : 'غير محددة'; }
  Future<void> _open(String value) async { final uri = Uri.tryParse(value); if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }
  Future<void> _call(String phone) async { if (phone.trim().isEmpty) return; final uri = Uri(scheme: 'tel', path: phone.trim()); if (await canLaunchUrl(uri)) await launchUrl(uri); }
  Future<void> _whatsapp(String? phone) async { final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), ''); if (digits.isEmpty) return; final uri = Uri.parse('https://wa.me/$digits'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }
  void _chat(BuildContext context, SellerInfo seller, List<PhoneListing> listings) { if (listings.isEmpty) return; if (context.read<AppState>().currentUser?.id == seller.id) return; Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(listing: listings.first))); }
}
